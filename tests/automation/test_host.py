import json,plistlib,tempfile,struct
from datetime import datetime
from pathlib import Path
import unittest
from tools.visirupt_pipeline.core import load_recipe
try:
    from tools.visirupt_pipeline.host import inspect_signed_app,build_host,validate_signing_team
except ImportError:inspect_signed_app=None
class HostTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(inspect_signed_app,'signed host verification missing')
        self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.root=Path(self.t.name).resolve()
    def app(self):
        p=self.root/'Host.app';p.mkdir()
        (p/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.games.cyberpunk.assetreceiver','CFBundleExecutable':'Host','CFBundleSupportedPlatforms':['XROS']}))
        from fixtures import macho
        (p/'Host').write_bytes(macho([struct.pack('<6I',0x32,24,11,0x1a0000,0x1b0000,0)],kind=2))
        (p/'embedded.mobileprovision').write_bytes(b'profile fixture')
        return p
    def runner(self,entitlements=None,profile_entitlements=None,signature_fail=False):
        entitlements=entitlements or {'application-identifier':'ABCDEFGHIJ.local.games.cyberpunk.assetreceiver','com.apple.developer.team-identifier':'ABCDEFGHIJ','com.apple.developer.kernel.extended-virtual-addressing':True,'com.apple.developer.kernel.increased-memory-limit':True}
        profile_entitlements=entitlements.copy() if profile_entitlements is None else profile_entitlements
        def run(argv,cwd,log,timeout):
            log.parent.mkdir(parents=True,exist_ok=True)
            if '--verify' in argv and signature_fail:raise ValueError('TOOL_FAILED')
            if '--entitlements' in argv:log.write_bytes(plistlib.dumps(entitlements))
            elif argv[:2]==['security','cms']:log.write_bytes(plistlib.dumps({'Entitlements':profile_entitlements,'TeamIdentifier':['ABCDEFGHIJ'],'ExpirationDate':datetime(2030,1,1)}))
            else:log.write_text('signature verified')
            return {'returncode':0,'log':str(log)}
        return run
    def test_signed_identity_and_memory_entitlements_require_profile_acceptance(self):
        result=inspect_signed_app(self.app(),load_recipe(),runner=self.runner())
        self.assertEqual('ABCDEFGHIJ.local.games.cyberpunk.assetreceiver',result['application_identifier'])
        self.assertTrue(result['signature_verified']);self.assertTrue(result['provisioning_verified'])
    def test_missing_or_mismatched_profile_entitlement_rejected(self):
        profile={'application-identifier':'ABCDEFGHIJ.local.games.cyberpunk.assetreceiver','com.apple.developer.team-identifier':'ABCDEFGHIJ','com.apple.developer.kernel.extended-virtual-addressing':True}
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):inspect_signed_app(self.app(),load_recipe(),runner=self.runner(profile_entitlements=profile))
    def test_wrong_bundle_identifier_is_rejected(self):
        app=self.app();info=plistlib.loads((app/'Info.plist').read_bytes());info['CFBundleIdentifier']='wrong';(app/'Info.plist').write_bytes(plistlib.dumps(info))
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):inspect_signed_app(app,load_recipe(),runner=self.runner())
    def test_signature_failure_never_reports_verified_app(self):
        with self.assertRaisesRegex(ValueError,'TOOL_FAILED'):inspect_signed_app(self.app(),load_recipe(),runner=self.runner(signature_fail=True))
    def test_missing_or_injectable_team_fails_before_any_workspace_write(self):
        for team in ('','bad;team','-some-option'):
            with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):validate_signing_team(team)
        self.assertEqual([],list(self.root.iterdir()))
    def test_wrong_executable_platform_and_escaped_name_are_rejected(self):
        app=self.app();binary=bytearray((app/'Host').read_bytes());struct.pack_into('<I',binary,40,12);(app/'Host').write_bytes(binary)
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):inspect_signed_app(app,load_recipe(),runner=self.runner())
        info=plistlib.loads((app/'Info.plist').read_bytes());info['CFBundleExecutable']='../outside';(app/'Info.plist').write_bytes(plistlib.dumps(info))
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):inspect_signed_app(app,load_recipe(),runner=self.runner())
    def test_absent_profile_cannot_be_accepted(self):
        app=self.app();(app/'embedded.mobileprovision').unlink()
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):inspect_signed_app(app,load_recipe(),runner=self.runner())
    def test_embed_signing_touches_only_private_framework_copies(self):
        from tools.visirupt_pipeline.host import private_host_project
        source=self.root/'source'
        for relative in ('cyberpunk-avp/compat','scratch/cyberpunk-consolidated-host','scratch/cyberpunk-staged-startup'):
            (source/relative).mkdir(parents=True)
        framework=self.root/'Prepared.framework';framework.mkdir();binary=framework/'Prepared';binary.write_bytes(b'immutable source')
        def signer(argv,cwd,log,timeout):
            target=Path(argv[-1]);(target/'signature-marker').write_text('local ad-hoc signature')
            return {'returncode':0,'log':str(log)}
        cwd=private_host_project(source,self.root/'private',{'Prepared':binary},runner=signer)
        self.assertTrue((cwd/'Frameworks/Prepared.framework/signature-marker').exists())
        self.assertFalse((framework/'signature-marker').exists())
        self.assertEqual(b'immutable source',binary.read_bytes())
