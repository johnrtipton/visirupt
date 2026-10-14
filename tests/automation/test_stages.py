"""Failures caught: stale/corrupt completion, escaped artifacts and concurrent mutation."""
import json
import multiprocessing
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
try:
    from tools.visirupt_pipeline.stages import run_stage, validate_receipt, stage_fingerprint
    from tools.visirupt_pipeline.workspace import atomic_json, workspace_lock
except ImportError:
    run_stage = None

class StageTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(run_stage, 'stage runner is not implemented')
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.w=Path(self.temp.name)/'workspace'
    def action(self,root):
        (root/'result').write_bytes(b'correct');return [root/'result']
    def test_unchanged_stage_is_reused_without_running_action(self):
        a=run_stage(self.w,'inspect','one',self.action)
        b=run_stage(self.w,'inspect','one',lambda _: self.fail('reran verified output'))
        self.assertEqual(a,b)
    def test_corrupt_output_invalidates_stage_and_dependents(self):
        original=run_stage(self.w,'inspect','one',self.action)
        child=run_stage(self.w,'adapters','child',self.action)
        path=self.w/original['outputs'][0]['path'];path.write_bytes(b'corrupt')
        self.assertFalse(validate_receipt(self.w,original))
        self.assertFalse(validate_receipt(self.w,child))
        new=run_stage(self.w,'inspect','one',self.action)
        self.assertTrue(validate_receipt(self.w,new))
        self.assertEqual('invalid',json.loads((self.w/'receipts/adapters.json').read_text())['state'])
    def test_version_change_invalidates_child_without_deleting_old_outputs(self):
        old=run_stage(self.w,'inspect',stage_fingerprint({'recipe':1}),self.action)
        child=run_stage(self.w,'adapters','one',self.action)
        new=run_stage(self.w,'inspect',stage_fingerprint({'recipe':2}),self.action)
        self.assertNotEqual(old['fingerprint'],new['fingerprint'])
        self.assertTrue((self.w/old['outputs'][0]['path']).exists())
        self.assertFalse(validate_receipt(self.w,child))
    def test_child_failure_retains_partial_but_has_no_complete_receipt(self):
        def interrupted(root):
            (root/'partial').write_bytes(b'partial')
            subprocess.run([sys.executable,'-c','raise SystemExit(3)'],check=True)
        with self.assertRaises(subprocess.CalledProcessError):
            run_stage(self.w,'inspect','one',interrupted)
        receipt=json.loads((self.w/'receipts/inspect.json').read_text())
        self.assertEqual('failed',receipt['state'])
        self.assertFalse(validate_receipt(self.w,receipt))
        self.assertTrue(list((self.w/'stages/inspect').glob('*/partial')))
    def test_bad_receipt_schema_or_empty_completion_is_not_reused(self):
        a=run_stage(self.w,'inspect','one',self.action)
        a['schema_version']=99
        self.assertFalse(validate_receipt(self.w,a))
        a['schema_version']=1;a['outputs']=[]
        self.assertFalse(validate_receipt(self.w,a))
    def test_output_outside_owned_stage_is_rejected(self):
        outside=Path(self.temp.name)/'original';outside.write_bytes(b'original')
        with self.assertRaisesRegex(ValueError,'INVALID_RECEIPT'):
            run_stage(self.w,'inspect','one',lambda _: [outside])
        self.assertEqual(b'original',outside.read_bytes())
    def test_symlink_artifact_is_rejected(self):
        def symlink(root):
            (root/'real').write_bytes(b'data');(root/'link').symlink_to(root/'real')
            return [root/'link']
        with self.assertRaisesRegex(ValueError,'INVALID_RECEIPT'):
            run_stage(self.w,'inspect','one',symlink)
    def test_workspace_lock_excludes_another_owner(self):
        with workspace_lock(self.w):
            with self.assertRaisesRegex(ValueError,'WORKSPACE_BUSY'):
                with workspace_lock(self.w):pass
    def test_private_atomic_json_permissions_and_existing_symlink(self):
        p=self.w/'private.json';atomic_json(p,{'ok':1})
        self.assertEqual(0o600,stat.S_IMODE(p.stat().st_mode))
        p.unlink();outside=Path(self.temp.name)/'original';outside.write_text('original')
        p.symlink_to(outside)
        with self.assertRaisesRegex(ValueError,'WORKSPACE_OVERLAP'):
            atomic_json(p,{'ok':2})
        self.assertEqual('original',outside.read_text())
    def test_fingerprint_key_order_is_stable_but_input_change_matters(self):
        self.assertEqual(stage_fingerprint({'a':1,'b':2}),stage_fingerprint({'b':2,'a':1}))
        self.assertNotEqual(stage_fingerprint({'source':'a'}),stage_fingerprint({'source':'b'}))
