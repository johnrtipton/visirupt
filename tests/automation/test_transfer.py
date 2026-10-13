import json,tempfile,uuid
from pathlib import Path
import unittest
try:
    from tools.visirupt_pipeline.transfer import device_writer_lock,verify_native_completion,source_file,owner_id
except ImportError:device_writer_lock=None
class TransferTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(device_writer_lock,'exclusive transfer control missing')
        self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.root=Path(self.t.name).resolve()
    def test_two_workspaces_cannot_write_one_device_container(self):
        device='synthetic-'+uuid.uuid4().hex
        with device_writer_lock(device,'local.games.cyberpunk.assetreceiver',self.root/'one'):
            with self.assertRaisesRegex(ValueError,'DEVICE_BUSY'):
                with device_writer_lock(device,'local.games.cyberpunk.assetreceiver',self.root/'two'):pass
    def test_native_completion_requires_exact_file_set_hash_and_verified_full_size(self):
        manifest={'files':[{'relative_path':'Data/a','bytes':4,'sha256':'a'*64}]}
        correct={'files':{'Data/a':{'offset':4,'verified':True,'source_sha256':'a'*64}}}
        self.assertEqual(1,verify_native_completion(correct,manifest)['files'])
        for value in ({'offset':4,'verified':False,'source_sha256':'a'*64},{'offset':3,'verified':True,'source_sha256':'a'*64},{'offset':4,'verified':True,'source_sha256':'b'*64}):
            with self.assertRaisesRegex(ValueError,'INCOMPLETE_TRANSFER'):verify_native_completion({'files':{'Data/a':value}},manifest)
        with self.assertRaisesRegex(ValueError,'INCOMPLETE_TRANSFER'):verify_native_completion({'files':{}},manifest)
    def test_local_override_stays_with_manifest_and_original_stays_in_source(self):
        contents=self.root/'Contents';(contents/'Data').mkdir(parents=True);(contents/'Data/a').write_bytes(b'original')
        private=self.root/'private';private.mkdir();m=private/'manifest.json';m.write_text('{}');(private/'override').write_bytes(b'prepared')
        path=source_file(contents,{'relative_path':'Data/a','source_relative_path':'Data/a','prepared_relative_path':'override'},m)
        self.assertEqual(b'prepared',path.read_bytes());self.assertEqual(b'original',(contents/'Data/a').read_bytes())
        with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):source_file(contents,{'relative_path':'Data/a','prepared_relative_path':'../outside'},m)
    def test_owner_is_private_stable_and_never_inferred_from_another_workspace(self):
        a=owner_id(self.root/'one');self.assertEqual(a,owner_id(self.root/'one'))
        self.assertNotEqual(a,owner_id(self.root/'two'))
        self.assertEqual(0o600,(self.root/'one/transfer-owner.json').stat().st_mode&0o777)
    def test_background_server_requires_auth_and_honors_only_listed_ranges(self):
        import importlib.util,threading,urllib.request,urllib.error
        from types import SimpleNamespace
        root=Path(__file__).resolve().parents[2]
        spec=importlib.util.spec_from_file_location('legacy_bg',root/'cyberpunk-avp/resumable/background_transfer.py');bg=importlib.util.module_from_spec(spec);spec.loader.exec_module(bg)
        self.assertTrue(hasattr(bg,'make_server'),'server needs testable explicit binding')
        data=self.root/'Data';data.mkdir();(data/'a').write_bytes(b'0123456789')
        manifest=self.root/'manifest.json';manifest.write_text(json.dumps({'files':[{'relative_path':'Data/a','bytes':10,'sha256':'a'*64}]}))
        request_id=str(uuid.uuid4());plan=self.root/'plan.json';plan.write_text(json.dumps({'owner_id':str(uuid.uuid4()),'jobs':[{'request_id':request_id,'asset_path':'Data/a','offset':2,'bytes':4,'sha256':'a'*64,'token':'secret-test-token'}]}))
        args=SimpleNamespace(plan=plan,manifest=manifest,asset_root=self.root,interface='127.0.0.1',port=0)
        server=bg.make_server(args);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            url=f'http://127.0.0.1:{server.server_port}/asset/{request_id}'
            with self.assertRaises(urllib.error.HTTPError) as rejected:urllib.request.urlopen(url,timeout=5)
            rejected.exception.close()
            req=urllib.request.Request(url,headers={'Authorization':'Bearer secret-test-token','Range':'bytes=1-'})
            with urllib.request.urlopen(req,timeout=5) as response:self.assertEqual(b'345',response.read());self.assertEqual(206,response.status)
            with self.assertRaises(urllib.error.HTTPError) as rejected:urllib.request.urlopen(urllib.request.Request(url,headers={'Authorization':'Bearer secret-test-token','Range':'bytes=4-'}),timeout=5)
            rejected.exception.close()
        finally:server.shutdown();server.server_close();thread.join()
    def test_same_workspace_cannot_use_aliases_to_run_two_transport_clients(self):
        with device_writer_lock('first-device-alias-'+uuid.uuid4().hex,'bundle',self.root/'shared'):
            with self.assertRaisesRegex(ValueError,'DEVICE_BUSY'):
                with device_writer_lock('second-device-alias-'+uuid.uuid4().hex,'bundle',self.root/'shared'):pass

    def test_native_verified_size_must_be_an_integer_not_float_or_bool(self):
        manifest={'files':[{'relative_path':'Data/a','bytes':1,'sha256':'a'*64}]}
        for value in (True,1.0):
            with self.assertRaisesRegex(ValueError,'INCOMPLETE_TRANSFER'):
                verify_native_completion({'files':{'Data/a':{'verified':True,'offset':value,'source_sha256':'a'*64}}},manifest)
    def test_first_receiver_deployment_is_not_inferred_from_transfer(self):
        from tools.visirupt_pipeline.transfer_control import transfer_assets
        from tools.visirupt_pipeline.core import load_recipe
        with self.assertRaisesRegex(ValueError,'--team'):
            transfer_assets(self.root/'workspace',load_recipe(),'device','foreground',True,game_root=self.root/'game')
        self.assertFalse((self.root/'workspace').exists())
