import hashlib,struct,tempfile
from pathlib import Path
import unittest
from fixtures import game_image
from tools.visirupt_pipeline.core import load_recipe
from tools.visirupt_pipeline.macho import parse_macho,semantic_inventory
try:
    from tools.visirupt_pipeline.game import prepare_game
    from tools.visirupt_pipeline.verify import verify_game
except ImportError:prepare_game=None
class GameTests(unittest.TestCase):
    def setUp(self):self.assertIsNotNone(prepare_game,'game preparation missing')
    def prepared(self,data=None):
        data=data or game_image();recipe=load_recipe();recipe['inputs']['CyberpunkModule']['sha256']=hashlib.sha256(data).hexdigest()
        recipe['game']['sections']=2;recipe['game']['initializers']=2
        td=tempfile.TemporaryDirectory();self.addCleanup(td.cleanup);root=Path(td.name);src=root/'original';src.write_bytes(data);out=root/'new/CyberpunkModule.framework/CyberpunkModule'
        r=prepare_game(src,out,recipe)
        return data,out.read_bytes(),recipe,src,out,r
    def test_executable_conversion_retains_segment_indices_and_initializer_bytes(self):
        before,after,recipe,*_=self.prepared();a=parse_macho(before);b=parse_macho(after)
        self.assertEqual(6,b['kind']);self.assertEqual(0,b['flags']&0x200000)
        self.assertEqual([s['name'] for s in a['segments']],[s['name'] for s in b['segments']])
        self.assertEqual(0,b['segments'][0]['vmsize'])
        self.assertFalse(any(c['cmd'] in (14,0x80000028) for c in b['commands']))
        self.assertEqual(before[4176:4184],after[4176:4184])
        self.assertTrue(verify_game(before,after,recipe)['initializers_preserved'])
    def test_only_capacity_words_change_in_original_code(self):
        before,after,*_=self.prepared();expected=bytearray(before[4096:4176])
        struct.pack_into('<I',expected,8,0xd2c00049);struct.pack_into('<I',expected,76,0xd2c00049)
        self.assertEqual(bytes(expected),after[4096:4176])
    def test_memorytrace_and_desktop_providers_remap_without_addend_changes(self):
        before,after,*_=self.prepared();inv=semantic_inventory(after)
        providers={r['symbol']:r['provider'] for r in inv['imports']}
        self.assertEqual('@rpath/MemoryTrace.framework/MemoryTrace',providers['_mmap'])
        self.assertEqual('@rpath/HostAdapters.framework/HostAdapters',providers['_desktop'])
        self.assertEqual(23,len(inv['dependencies']))
    def test_wrong_or_already_patched_instruction_is_rejected(self):
        for word in (0,0xd2c00049):
            changed=bytearray(game_image());struct.pack_into('<I',changed,4104,word)
            with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):self.prepared(bytes(changed))
    def test_no_room_header_padding_and_referenced_cocoa_are_rejected(self):
        changed=bytearray(game_image());changed[parse_macho(bytes(changed))['header_end']]=1
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):self.prepared(bytes(changed))
        changed=bytearray(game_image());base=parse_macho(bytes(changed))['fixups'][0];struct.pack_into('<I',changed,base+32,4|(1<<9))
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):self.prepared(bytes(changed))
    def test_postconversion_initializer_or_code_corruption_fails_verifier(self):
        before,after,recipe,*_=self.prepared()
        for offset in (4176,4096):
            changed=bytearray(after);changed[offset]^=1
            with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):verify_game(before,bytes(changed),recipe)
