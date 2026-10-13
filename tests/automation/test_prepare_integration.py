"""Explicit opt-in local build. No proprietary fixtures or device execution in CI."""
import json,os
from pathlib import Path
import subprocess,sys,unittest
ROOT=Path(__file__).resolve().parents[2]
class PrepareIntegrationTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get('VISIRUPT_TEST_GAME'),'private game input not supplied')
    def test_fresh_prepare_and_independent_verify_then_cache_resume(self):
        workspace=Path(os.environ['VISIRUPT_TEST_WORKSPACE'])
        common=['--workspace',str(workspace),'--json']
        command=[sys.executable,str(ROOT/'tools/visirupt.py'),'prepare',*common,'--game',os.environ['VISIRUPT_TEST_GAME'],'--curl-archive',os.environ['VISIRUPT_TEST_CURL']]
        first=subprocess.run(command,cwd=ROOT,text=True,capture_output=True,timeout=1200)
        self.assertEqual(0,first.returncode,first.stderr)
        receipt=json.loads(first.stdout);self.assertEqual('complete',receipt['state'])
        result=subprocess.run([sys.executable,str(ROOT/'tools/visirupt.py'),'verify',*common],cwd=ROOT,text=True,capture_output=True,timeout=120)
        self.assertEqual(0,result.returncode,result.stderr)
        self.assertEqual(10,json.loads(result.stdout)['verified_frameworks'])
        second=subprocess.run(command,cwd=ROOT,text=True,capture_output=True,timeout=1200)
        self.assertEqual(0,second.returncode,second.stderr)
        self.assertEqual(receipt['run_id'],json.loads(second.stdout)['run_id'])
