import json,tempfile,unittest
from pathlib import Path
try:
    from tools.visirupt_pipeline.reports import public_report,stage_status,write_report
except ImportError:public_report=None
from tools.visirupt_pipeline.core import RECIPE_ID
class ReportTests(unittest.TestCase):
    def setUp(self):self.assertIsNotNone(public_report,'allowlisted reports missing')
    def test_reconstructs_only_typed_allowlisted_values(self):
        private={'recipe':{'id':RECIPE_ID,'version':1,'token':'secret'},'source_revision':'a'*40,'token':'secret','raw_log':'secret','device':'secret','url':'https://secret/', 'tools':{'sdk':'27.0','python':'3.14.6','bad':'secret'},'hardware':'M2 Vision Pro','counts':{'files':110,'bytes':158461863365,'path':'secret'},'human_tests':{'gameplay':'passed','audio':'pending','free_text':'secret'},'stages':{'host':{'state':'complete','token':'secret'},'unknown':{'state':'secret'}}}
        result=public_report(private);self.assertNotIn('secret',json.dumps(result));self.assertEqual('pending',result['human_tests']['gameplay']);self.assertEqual(110,result['counts']['files']);self.assertEqual('27.0',result['tools']['sdk'])
    def test_bad_versions_counts_revisions_and_freeform_observations_are_omitted(self):
        result=public_report({'recipe':{'id':RECIPE_ID,'version':1},'source_revision':'/private/secret','tools':{'sdk':'27.0 secret'},'counts':{'files':True,'bytes':-1},'human_tests':{'audio':'secret'},'hardware':'secret'})
        self.assertNotIn('secret',json.dumps(result));self.assertEqual({},result['tools']);self.assertEqual({},result['counts'])
    def test_missing_or_invalid_recipe_fails_without_log_fallback(self):
        for data in ({},{'recipe':{'id':'secret','version':1}},{'recipe':{'id':RECIPE_ID,'version':True}}):
            with self.assertRaisesRegex(ValueError,'INVALID_RECEIPT'):public_report(data)
    def test_human_gameplay_pass_requires_explicit_install_and_launch_pass(self):
        data={'recipe':{'id':RECIPE_ID,'version':1},'stages':{'install':{'state':'complete'},'launch':{'state':'complete'}},'human_tests':{'gameplay':'passed'}}
        self.assertEqual('passed',public_report(data)['human_tests']['gameplay'])
        data['stages']['launch']['state']='failed';self.assertEqual('pending',public_report(data)['human_tests']['gameplay'])
    def test_status_rehashes_corrupt_artifacts(self):
        from tools.visirupt_pipeline.stages import run_stage
        with tempfile.TemporaryDirectory() as t:
            root=Path(t).resolve()
            def action(stage):p=stage/'x';p.write_text('valid');return [p]
            receipt=run_stage(root,'inspect','test',action);self.assertEqual('complete',stage_status(root)['inspect']['state'])
            (root/receipt['outputs'][0]['path']).write_text('bad');self.assertEqual('invalid',stage_status(root)['inspect']['state'])
    def test_report_refuses_replacement_and_paths_with_symlinks(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t).resolve();output=root/'draft.json';data={'recipe':{'id':RECIPE_ID,'version':1}}
            write_report(data,output);self.assertEqual(0o600,output.stat().st_mode&0o777)
            with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):write_report(data,output)
            link=root/'link';link.symlink_to(root,target_is_directory=True)
            with self.assertRaises(ValueError):write_report(data,link/'new.json')
