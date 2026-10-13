"""Exercise actual Make processes with an argv/environment capturing uv fixture."""
import json,os,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
class WrapperTests(unittest.TestCase):
    def test_all_wrappers_preserve_environment_values_without_shell_evaluation(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t);fixture=root/'uv';capture=root/'capture.json'
            fixture.write_text('#!/usr/bin/env python3\nimport os,sys,json\nopen(os.environ["CAPTURE"],"w").write(json.dumps({"argv":sys.argv[1:],"env":{k:os.environ.get(k) for k in ("WORKSPACE","GAME","DEVICE","TEAM","TRANSPORT","INTERFACE","CURL_ARCHIVE","REPORT_OUTPUT")}}))\n');fixture.chmod(0o700)
            env=dict(os.environ,PATH=str(root)+os.pathsep+os.environ['PATH'],CAPTURE=str(capture),GAME='/owned Game/$(touch SHOULD_NOT_EXIST)',WORKSPACE='/private/with spaces',DEVICE='fixture',TEAM='ABCDEFGHIJ',TRANSPORT='foreground',INTERFACE='192.168.1.2',CURL_ARCHIVE='/private/curl source.tar.xz',REPORT_OUTPUT='/private/new report.json')
            for command in ('doctor','plan','prepare','verify','build','transfer','install','launch','status','report'):
                result=subprocess.run(['make',command],cwd=ROOT,env=env,capture_output=True,text=True)
                self.assertEqual(0,result.returncode,result.stderr)
                data=json.loads(capture.read_text());self.assertEqual(['run','--no-project','python','tools/visirupt.py',command],data['argv']);self.assertEqual(env['GAME'],data['env']['GAME']);self.assertEqual(env['INTERFACE'],data['env']['INTERFACE'])
            self.assertFalse((ROOT/'SHOULD_NOT_EXIST').exists())
    def test_ci_has_read_only_permissions_no_private_upload_and_source_tests(self):
        path=ROOT/'.github/workflows/automation.yml';self.assertTrue(path.exists(),'automation CI missing')
        source=path.read_text();self.assertIn('contents: read',source);self.assertIn('automation-test',source);self.assertNotIn('upload-artifact',source);self.assertNotIn('pull_request_target',source);self.assertNotIn('VISIRUPT_TEST_GAME:',source)
