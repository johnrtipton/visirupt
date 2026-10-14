import hashlib,json,struct,tempfile
from pathlib import Path
import unittest
from fixtures import provider_image
from tools.visirupt_pipeline.core import load_recipe
from tools.visirupt_pipeline.macho import parse_macho,semantic_inventory
try:
    from tools.visirupt_pipeline.providers import prepare_provider
    from tools.visirupt_pipeline.verify import verify_provider
except ImportError:prepare_provider=None
class ProviderTests(unittest.TestCase):
    def setUp(self):self.assertIsNotNone(prepare_provider,'provider preparation missing')
    def prepared(self,name,data=None):
        data=data or provider_image(name)
        recipe=load_recipe();recipe['inputs'][name]['sha256']=hashlib.sha256(data).hexdigest()
        td=tempfile.TemporaryDirectory();self.addCleanup(td.cleanup);root=Path(td.name)
        src=root/'original';src.write_bytes(data);out=root/'prepared'/f'{name}.framework'/name
        result=prepare_provider(name,src,out,recipe)
        return data,out.read_bytes(),result,src,out,recipe
    def test_bink_preserves_payload_and_remaps_only_surviving_providers(self):
        before,after,r,src,out,recipe=self.prepared('Bink')
        inv=semantic_inventory(after)
        self.assertEqual(11,inv['platform'][0])
        self.assertEqual(['_audio','_system','_audio','_system'],[x['symbol'] for x in inv['imports']])
        self.assertEqual([1,3,1,3],[x['ordinal'] for x in inv['imports']])
        self.assertEqual(b'CODE'*4,after[1024:1040])
        self.assertEqual(0,parse_macho(after)['symtab'][2]%8)
        self.assertEqual(before,src.read_bytes())
        self.assertTrue(verify_provider('Bink',before,after,recipe)['sections_preserved'])
    def test_appstore_routes_exact_five_symbols_to_host(self):
        before,after,*_=self.prepared('AppStoreServices')
        inv=semantic_inventory(after)
        self.assertEqual({7},{x['ordinal'] for x in inv['imports']})
        self.assertEqual({'@rpath/HostAdapters.framework/HostAdapters'},{x['provider'] for x in inv['imports']})
    def test_galaxy_routes_four_security_symbols_without_code_changes(self):
        before,after,*_=self.prepared('GalaxyServices')
        inv=semantic_inventory(after)
        self.assertEqual({6},{x['ordinal'] for x in inv['imports']})
        self.assertEqual({'@rpath/NativeSecurity.framework/NativeSecurity'},{x['provider'] for x in inv['imports']})
        self.assertEqual(before[1024:1040],after[1024:1040])
    def test_reference_to_pruned_umbrella_is_rejected_without_output(self):
        data=bytearray(provider_image('Bink'));symoff=parse_macho(bytes(data))['symtab'][0]
        struct.pack_into('<H',data,symoff+6,1<<8)
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):self.prepared('Bink',bytes(data))
    def test_wrong_hash_is_rejected_before_output_creation(self):
        with tempfile.TemporaryDirectory() as td:
            src=Path(td)/'original';src.write_bytes(provider_image('Bink'));out=Path(td)/'new/Bink'
            with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):prepare_provider('Bink',src,out,load_recipe())
            self.assertFalse(out.parent.exists())
    def test_corrupted_section_or_binding_cannot_pass_independent_verifier(self):
        before,after,r,src,out,recipe=self.prepared('GalaxyServices')
        changed=bytearray(after);changed[1024]^=1
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):verify_provider('GalaxyServices',before,bytes(changed),recipe)
        changed=bytearray(after);loc=parse_macho(after)['symtab'][0];struct.pack_into('<H',changed,loc+6,2<<8)
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):verify_provider('GalaxyServices',before,bytes(changed),recipe)

    def test_malformed_supported_snapshot_has_no_output_side_effect(self):
        data=bytearray(provider_image('Bink'));struct.pack_into('<I',data,36,0)
        recipe=load_recipe();recipe['inputs']['Bink']['sha256']=hashlib.sha256(data).hexdigest()
        with tempfile.TemporaryDirectory() as td:
            src=Path(td)/'original';src.write_bytes(data);out=Path(td)/'output/Bink'
            with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):prepare_provider('Bink',src,out,recipe)
            self.assertFalse(out.parent.exists())
