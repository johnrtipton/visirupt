import json,tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
from tools.visirupt_pipeline.core import load_recipe
try:
    from tools.visirupt_pipeline.device import require_update_ownership,install_host,inspect_device
except ImportError:require_update_ownership=None
DEVICE='00000000-0000-0000-0000-000000000001'
BUNDLE='local.games.cyberpunk.assetreceiver'
class DeviceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(require_update_ownership,'container ownership gate missing')
        self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.root=Path(self.t.name).resolve();self.calls=[]
    def identity(self):return {'bundle_identifier':BUNDLE,'application_identifier':'ABCDEFGHIJ.'+BUNDLE,'team_identifier':'ABCDEFGHIJ','signature_verified':True,'provisioning_verified':True}
    def test_unknown_or_different_owner_is_rejected_even_when_bundle_matches(self):
        candidate=self.identity()
        for installed in ({'exists':True,'bundle_identifier':BUNDLE},{'exists':True,**candidate,'team_identifier':'ZZZZZZZZZZ'},{'exists':True,**candidate,'application_identifier':'ZZZZZZZZZZ.'+BUNDLE}):
            with self.assertRaisesRegex(ValueError,'CONTAINER_OWNERSHIP_UNKNOWN'):require_update_ownership(installed,candidate)
        require_update_ownership({'exists':False},candidate)
        require_update_ownership({'exists':True,**candidate},candidate)
    def runner(self,apps,install_outcome='success'):
        def run(argv,cwd,log,timeout):
            self.calls.append(argv)
            output=Path(argv[argv.index('--json-output')+1]);output.parent.mkdir(parents=True,exist_ok=True)
            if argv[1:5]==['devicectl','device','info','apps']:
                result={'apps':apps,'deviceIdentifier':DEVICE}
            elif 'install' in argv:
                result={'deviceIdentifier':DEVICE,'installedApplications':[{'bundleID':BUNDLE,'installationURL':'file:///private/new/Host.app'}]}
            else:result={'deviceIdentifier':DEVICE,'processIdentifier':123}
            output.write_text(json.dumps({'info':{'outcome':install_outcome if 'install' in argv else 'success'},'result':result}))
            return {'returncode':0,'log':str(log)}
        return run
    def test_existing_unknown_owner_stops_before_install_and_never_uninstalls(self):
        app=self.root/'candidate.app';app.mkdir()
        apps=[{'bundleIdentifier':BUNDLE,'url':'file:///private/existing/Host.app','builtByDeveloper':True,'containerAccessible':True,'dataContainerPath':'/private/data'}]
        with patch('tools.visirupt_pipeline.device.inspect_signed_app',return_value=self.identity()),patch('tools.visirupt_pipeline.device.verify_embedded'):
            with self.assertRaisesRegex(ValueError,'CONTAINER_OWNERSHIP_UNKNOWN'):install_host(self.root,DEVICE,app,runner=self.runner(apps),recipe=load_recipe(),allow_first=True)
        self.assertFalse(any('install' in argv or 'uninstall' in argv for argv in self.calls))
    def test_missing_apps_or_multiple_target_matches_fail_closed(self):
        for apps in (None,[{'bundleIdentifier':BUNDLE},{'bundleIdentifier':BUNDLE}]):
            with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):inspect_device(DEVICE,BUNDLE,workspace=self.root,runner=self.runner(apps))
    def test_own_installation_proof_requires_unchanged_system_bundle_url(self):
        app={'bundleIdentifier':BUNDLE,'url':'file:///private/known/Host.app','builtByDeveloper':True,'containerAccessible':True,'dataContainerPath':'/private/data'}
        proof=self.root/'installed-device.json';proof.write_text(json.dumps({'device':DEVICE,'bundle_url':app['url'],'identity':self.identity(),'kind':'host'}))
        result=inspect_device(DEVICE,BUNDLE,workspace=self.root,runner=self.runner([app]))
        self.assertEqual('ABCDEFGHIJ',result['team_identifier'])
        changed=dict(app,url='file:///private/new/Host.app')
        result=inspect_device(DEVICE,BUNDLE,workspace=self.root,runner=self.runner([changed]))
        self.assertNotIn('team_identifier',result)
    def test_failed_install_receipt_never_marks_installation_complete(self):
        app=self.root/'candidate.app';app.mkdir()
        with patch('tools.visirupt_pipeline.device.inspect_signed_app',return_value=self.identity()),patch('tools.visirupt_pipeline.device.verify_embedded'):
            with self.assertRaisesRegex(ValueError,'TOOL_FAILED'):install_host(self.root,DEVICE,app,runner=self.runner([],'failed'),recipe=load_recipe(),allow_first=True)
        self.assertFalse((self.root/'installed-device.json').exists())
    def test_fresh_install_records_only_confirmed_own_app_and_preserves_container_on_update(self):
        app=self.root/'candidate.app';app.mkdir();apps=[]
        def run(argv,cwd,log,timeout):
            self.calls.append(argv);output=Path(argv[argv.index('--json-output')+1]);output.parent.mkdir(parents=True,exist_ok=True)
            if 'install' in argv:
                apps[:]=[{'bundleIdentifier':BUNDLE,'url':'file:///private/new/Host.app','builtByDeveloper':True,'containerAccessible':True,'dataContainerPath':'/private/data'}]
                result={'deviceIdentifier':DEVICE,'installedApplications':[{'bundleID':BUNDLE,'installationURL':apps[0]['url']}]}
            else:result={'deviceIdentifier':DEVICE,'apps':apps}
            output.write_text(json.dumps({'info':{'outcome':'success'},'result':result}));return {'returncode':0,'log':str(log)}
        with patch('tools.visirupt_pipeline.device.inspect_signed_app',return_value=self.identity()),patch('tools.visirupt_pipeline.device.verify_embedded'):
            result=install_host(self.root,DEVICE,app,runner=run,recipe=load_recipe(),allow_first=True)
        self.assertTrue(result['installation_verified'])
        proof=json.loads((self.root/'installed-device.json').read_text());self.assertEqual('/private/data',proof['data_container'])
    def test_candidate_identity_changed_before_install_is_rejected(self):
        app=self.root/'candidate.app';app.mkdir()
        second=dict(self.identity(),team_identifier='ZZZZZZZZZZ')
        with patch('tools.visirupt_pipeline.device.inspect_signed_app',side_effect=[self.identity(),second]),patch('tools.visirupt_pipeline.device.verify_embedded'):
            with self.assertRaisesRegex(ValueError,'SOURCE_CHANGED'):install_host(self.root,DEVICE,app,runner=self.runner([]),recipe=load_recipe(),allow_first=True)
        self.assertFalse(any('install' in argv for argv in self.calls))
    def test_stale_installation_proof_cannot_launch_another_app(self):
        from tools.visirupt_pipeline.device import launch_owned
        app={'bundleIdentifier':BUNDLE,'url':'file:///private/other/Host.app','builtByDeveloper':True,'containerAccessible':True,'dataContainerPath':'/private/data'}
        (self.root/'installed-device.json').write_text(json.dumps({'device':DEVICE,'bundle_url':'file:///private/old/Host.app','identity':self.identity(),'kind':'host'}))
        with self.assertRaisesRegex(ValueError,'CONTAINER_OWNERSHIP_UNKNOWN'):launch_owned(self.root,DEVICE,'host',runner=self.runner([app]))
        self.assertFalse(any('launch' in argv for argv in self.calls))
    def test_install_rechecks_device_under_writer_lock(self):
        app=self.root/'candidate.app';app.mkdir()
        with patch('tools.visirupt_pipeline.device.inspect_signed_app',return_value=self.identity()),patch('tools.visirupt_pipeline.device.verify_embedded'),patch('tools.visirupt_pipeline.device.inspect_device',side_effect=[{'exists':False,'device':DEVICE},{'exists':True,'device':DEVICE,'bundle_identifier':BUNDLE}]):
            with self.assertRaisesRegex(ValueError,'CONTAINER_OWNERSHIP_UNKNOWN'):install_host(self.root,DEVICE,app,runner=self.runner([]),recipe=load_recipe(),allow_first=True)
        self.assertFalse(any('install' in argv for argv in self.calls))
    def test_launch_has_separate_receipt_and_no_restart_or_uninstall(self):
        from tools.visirupt_pipeline.device import launch_owned
        app={'bundleIdentifier':BUNDLE,'url':'file:///private/known/Host.app','builtByDeveloper':True,'containerAccessible':True,'dataContainerPath':'/private/data'}
        (self.root/'installed-device.json').write_text(json.dumps({'device':DEVICE,'bundle_url':app['url'],'identity':self.identity(),'kind':'host'}))
        base=self.runner([app])
        def run(argv,cwd,log,timeout):
            if 'launch' not in argv:return base(argv,cwd,log,timeout)
            self.calls.append(argv);Path(argv[argv.index('--json-output')+1]).write_text(json.dumps({'info':{'outcome':'success'},'result':{'deviceIdentifier':DEVICE,'process':{'processIdentifier':123}}}))
        result=launch_owned(self.root,DEVICE,'host',runner=run)
        self.assertTrue(result['launch_verified']);self.assertFalse(result['gameplay_confirmed'])
        self.assertFalse(any('terminate' in str(argv) or 'uninstall' in argv for argv in self.calls))
    def test_incomplete_install_receipt_does_not_write_provenance(self):
        app=self.root/'candidate.app';app.mkdir()
        base=self.runner([])
        def run(argv,cwd,log,timeout):
            if 'install' not in argv:return base(argv,cwd,log,timeout)
            self.calls.append(argv);Path(argv[argv.index('--json-output')+1]).write_text(json.dumps({'info':{'outcome':'success'},'result':{'deviceIdentifier':'different','installedApplications':[]}}))
        with patch('tools.visirupt_pipeline.device.inspect_signed_app',return_value=self.identity()),patch('tools.visirupt_pipeline.device.verify_embedded'):
            with self.assertRaisesRegex(ValueError,'TOOL_FAILED'):install_host(self.root,DEVICE,app,runner=run,recipe=load_recipe(),allow_first=True)
        self.assertFalse((self.root/'installed-device.json').exists())
    def test_owned_host_update_requires_explicit_receiver_round_trip(self):
        from tools.visirupt_pipeline import device
        self.assertTrue(hasattr(device,'prepare_install_receiver'),'explicit host update verifier missing')
        current={'exists':True,'device':DEVICE,'kind':'host',**self.identity()}
        with patch.object(device,'inspect_device',return_value=current),patch.object(device,'deploy_receiver_app') as deploy,patch.object(device,'launch_receiver_app') as launch,patch.object(device,'installed_app',return_value={'device':DEVICE,'kind':'receiver'}):
            with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):device.prepare_install_receiver(self.root,load_recipe(),DEVICE,self.root/'manifest.json')
            deploy.assert_not_called();launch.assert_not_called()
            device.prepare_install_receiver(self.root,load_recipe(),DEVICE,self.root/'manifest.json',deploy_receiver=True,launch_receiver=True,team='ABCDEFGHIJ')
            deploy.assert_called_once();launch.assert_called_once()
    def test_receiver_round_trip_flags_never_replace_unknown_owner(self):
        from tools.visirupt_pipeline import device
        self.assertTrue(hasattr(device,'prepare_install_receiver'),'explicit host update verifier missing')
        with patch.object(device,'inspect_device',return_value={'exists':True,'device':DEVICE}),patch.object(device,'deploy_receiver_app') as deploy:
            with self.assertRaisesRegex(ValueError,'CONTAINER_OWNERSHIP_UNKNOWN'):device.prepare_install_receiver(self.root,load_recipe(),DEVICE,self.root/'manifest.json',deploy_receiver=True,launch_receiver=True,team='ABCDEFGHIJ')
            deploy.assert_not_called()
    def test_owned_host_verifier_round_trip_then_host_update_preserves_container(self):
        from tools.visirupt_pipeline import device
        from tools.visirupt_pipeline.stages import run_stage,DEPENDENCIES
        from types import SimpleNamespace
        candidate=self.root/'candidate.app';candidate.mkdir()
        manifest_data={'files':[{'relative_path':'archive/mac/a.archive','sha256':'a'*64,'bytes':4}]}
        for name in DEPENDENCIES:
            if name in ('install','launch'):break
            def action(root,name=name):
                p=root/('asset-manifest.json' if name=='assets' else 'identity.json' if name=='host' else 'x.json')
                p.write_text(json.dumps(manifest_data if name=='assets' else {'app_path':'candidate.app'} if name=='host' else {}));return [p]
            run_stage(self.root,name,'fixture-'+name,action)
        apps=[{'bundleIdentifier':BUNDLE,'url':'file:///private/original/Host.app','builtByDeveloper':True,'containerAccessible':True,'dataContainerPath':'/private/retained-data'}]
        (self.root/'installed-device.json').write_text(json.dumps({'device':DEVICE,'bundle_url':apps[0]['url'],'data_container':apps[0]['dataContainerPath'],'identity':self.identity(),'kind':'host'}))
        installs=[];order=[]
        def run(argv,cwd,log,timeout):
            self.calls.append(argv);output=Path(argv[argv.index('--json-output')+1]);output.parent.mkdir(parents=True,exist_ok=True)
            if 'install' in argv:
                installs.append(argv);order.append('install');apps[0]['url']='file:///private/revision'+str(len(installs))+'/Host.app'
                result={'deviceIdentifier':DEVICE,'installedApplications':[{'bundleID':BUNDLE,'installationURL':apps[0]['url']}]}
            elif 'launch' in argv:order.append('launch');result={'deviceIdentifier':DEVICE,'process':{'processIdentifier':123}}
            else:result={'deviceIdentifier':DEVICE,'apps':apps}
            output.write_text(json.dumps({'info':{'outcome':'success'},'result':result}))
        def deploy(workspace,recipe,target,manifest,team):
            device.install_host(workspace,target,candidate,recipe=recipe,runner=run,kind='receiver',allow_first=True)
        class Client:
            def __init__(self,*args):pass
            def status(self):
                order.append('native-verify');return {'files':{'archive/mac/a.archive':{'offset':4,'source_sha256':'a'*64,'verified':True}}}
            def release(self):order.append('release')
        original_inspect=device.inspect_device
        with patch.object(device,'run_tool',run),patch.object(device,'inspect_signed_app',return_value=self.identity()),patch.object(device,'verify_embedded'),patch.object(device,'inspect_device',side_effect=lambda target,bundle,**kw:original_inspect(target,bundle,workspace=kw['workspace'],runner=run)),patch.object(device,'deploy_receiver_app',side_effect=deploy),patch.object(device,'launch_receiver_app',side_effect=lambda workspace,target:device.launch_owned(workspace,target,'receiver',run)),patch('tools.visirupt_pipeline.transfer_control.legacy',return_value=SimpleNamespace(TransferClient=Client)):
            result=device.install_prepared_host(self.root,load_recipe(),DEVICE,deploy_receiver=True,launch_receiver=True,team='ABCDEFGHIJ')
        self.assertEqual('complete',result['state']);self.assertEqual(['install','launch','native-verify','release','install'],order)
        proof=json.loads((self.root/'installed-device.json').read_text());self.assertEqual('host',proof['kind']);self.assertEqual('/private/retained-data',proof['data_container'])
        self.assertFalse(any('uninstall' in argv or 'terminate' in str(argv) for argv in self.calls))
