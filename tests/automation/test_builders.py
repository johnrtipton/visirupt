import hashlib,io,os
from pathlib import Path
import stat,sys,tarfile,tempfile
import unittest
try:
    from tools.visirupt_pipeline.runner import run_tool
    from tools.visirupt_pipeline.builders import extract_archive, verify_native_framework
except ImportError:run_tool=None
class BuilderTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(run_tool,'controlled builder runner missing')
        self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.root=Path(self.t.name).resolve()
    def test_arguments_with_metacharacters_are_not_shell_evaluated(self):
        value='name with spaces; touch should-not-exist'
        result=run_tool([sys.executable,'-c','import sys; print(sys.argv[1])',value],self.root,self.root/'private.log',10)
        self.assertEqual(0,result['returncode']);self.assertEqual(value+'\n',(self.root/'private.log').read_text())
        self.assertFalse((self.root/'should-not-exist').exists())
        self.assertEqual(0o600,stat.S_IMODE((self.root/'private.log').stat().st_mode))
    def test_failed_or_timed_out_process_never_reports_completion(self):
        for argv,timeout in (([sys.executable,'-c','raise SystemExit(3)'],10),([sys.executable,'-c','import time; time.sleep(20)'],0.1)):
            with self.assertRaisesRegex(ValueError,'TOOL_FAILED'):run_tool(argv,self.root,self.root/'log',timeout)
    def archive(self,name,kind=tarfile.REGTYPE):
        path=self.root/'source.tar'
        with tarfile.open(path,'w') as tar:
            member=tarfile.TarInfo(name);member.type=kind;member.linkname='/private/danger'
            if kind==tarfile.REGTYPE:member.size=4;tar.addfile(member,io.BytesIO(b'data'))
            else:tar.addfile(member)
        return path,hashlib.sha256(path.read_bytes()).hexdigest()
    def test_pinned_archive_extracts_only_owned_regular_files(self):
        path,digest=self.archive('curl-8.14.1/include/source.h')
        result=extract_archive(path,self.root/'output',digest,'curl-8.14.1')
        self.assertEqual(b'data',(result/'include/source.h').read_bytes())
    def test_archive_traversal_absolute_symlink_hardlink_and_device_rejected(self):
        for name,kind in (('../outside',tarfile.REGTYPE),('/absolute',tarfile.REGTYPE),('curl-8.14.1/link',tarfile.SYMTYPE),('curl-8.14.1/link',tarfile.LNKTYPE),('curl-8.14.1/device',tarfile.CHRTYPE)):
            path,digest=self.archive(name,kind)
            with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):extract_archive(path,self.root/'output',digest,'curl-8.14.1')
            self.assertFalse((self.root/'output').exists())
    def test_wrong_archive_hash_fails_before_directory_creation(self):
        path,_=self.archive('curl-8.14.1/source.c')
        with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):extract_archive(path,self.root/'output','0'*64,'curl-8.14.1')
        self.assertFalse((self.root/'output').exists())
    def test_log_symlink_cannot_overwrite_original(self):
        source=self.root/'original';source.write_text('retain');(self.root/'link').symlink_to(source)
        with self.assertRaisesRegex(ValueError,'WORKSPACE_OVERLAP'):run_tool([sys.executable,'-c','print(1)'],self.root,self.root/'link',10)
        self.assertEqual('retain',source.read_text())
    def test_native_target_and_missing_exports_are_independently_rejected(self):
        from fixtures import provider_image
        from tools.visirupt_pipeline.core import load_recipe
        from tools.visirupt_pipeline.providers import convert_provider
        data=provider_image('Bink');recipe=load_recipe();recipe['inputs']['Bink']['sha256']=hashlib.sha256(data).hexdigest()
        p=self.root/'Bink';p.write_bytes(data)
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):verify_native_framework(p,'Bink')
        p.write_bytes(convert_provider('Bink',data,recipe))
        with self.assertRaisesRegex(ValueError,'missing source exports'):verify_native_framework(p,'Bink',{'_missing'})
    def test_native_target_with_unexpected_runtime_dependency_is_rejected(self):
        from fixtures import provider_image
        from tools.visirupt_pipeline.core import load_recipe
        from tools.visirupt_pipeline.providers import convert_provider
        data=provider_image('Bink');recipe=load_recipe();recipe['inputs']['Bink']['sha256']=hashlib.sha256(data).hexdigest()
        output=convert_provider('Bink',data,recipe)
        output=output.replace(b'/usr/lib/libSystem.B.dylib\0',b'/opt/libsecret.dylib\0'+b'\0'*6)
        p=self.root/'Bink';p.write_bytes(output)
        with self.assertRaisesRegex(ValueError,'unexpected runtime dependency'):verify_native_framework(p,'Bink')
