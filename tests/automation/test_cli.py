"""Failures caught: writeful dry commands, ambiguous selectors, unsafe private roots."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
CLI=ROOT/'tools/visirupt.py'
class CliTests(unittest.TestCase):
    def run_cli(self,*args):
        return subprocess.run([sys.executable,str(CLI),*map(str,args)],cwd=ROOT,text=True,capture_output=True)
    def test_doctor_returns_structured_result_without_workspace_write(self):
        with tempfile.TemporaryDirectory() as td:
            workspace=Path(td)/'private workspace'
            r=self.run_cli('doctor','--workspace',workspace,'--json')
            self.assertEqual(0,r.returncode,r.stderr)
            self.assertIn('tools',json.loads(r.stdout))
            self.assertFalse(workspace.exists())
    def test_plan_has_no_device_action_or_write(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'new'
            r=self.run_cli('plan','--workspace',p,'--json')
            self.assertEqual(0,r.returncode,r.stderr)
            plan=json.loads(r.stdout)
            self.assertEqual([],plan['device_actions'])
            self.assertEqual('game',plan['stages'][-1])
            self.assertFalse(p.exists())
    def test_workspace_inside_original_is_rejected_before_creation(self):
        with tempfile.TemporaryDirectory() as td:
            game=Path(td)/'owned game';game.mkdir()
            r=self.run_cli('prepare','--workspace',game/'outputs','--game',game)
            self.assertEqual(2,r.returncode)
            self.assertIn('WORKSPACE_OVERLAP',r.stderr)
            self.assertEqual([],list(game.iterdir()))
    def test_workspace_containing_original_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            game=Path(td)/'game';game.mkdir()
            r=self.run_cli('prepare','--workspace',td,'--game',game)
            self.assertIn('WORKSPACE_OVERLAP',r.stderr)
    def test_workspace_in_checkout_is_rejected(self):
        r=self.run_cli('prepare','--workspace',ROOT/'scratch'/'forbidden','--game','/not/a/game')
        self.assertIn('WORKSPACE_OVERLAP',r.stderr)
    def test_workspace_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);(root/'link').symlink_to(root,target_is_directory=True)
            r=self.run_cli('prepare','--workspace',root/'link'/'output','--game',root/'game')
            self.assertIn('WORKSPACE_OVERLAP',r.stderr)
    def test_unknown_recipe_cannot_be_loaded(self):
        r=self.run_cli('plan','--recipe','../../private')
        self.assertEqual(2,r.returncode)
        self.assertIn('UNSUPPORTED_INPUT',r.stderr)
    def test_status_does_not_create_missing_workspace(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'missing'
            r=self.run_cli('status','--workspace',p,'--json')
            self.assertEqual(0,r.returncode,r.stderr)
            self.assertEqual('pending',json.loads(r.stdout)['state'])
            self.assertFalse(p.exists())
    def test_device_command_requires_explicit_device(self):
        r=self.run_cli('launch','--workspace','/private/not-created')
        self.assertEqual(2,r.returncode)
        self.assertIn('--device',r.stderr)
