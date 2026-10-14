import struct
import unittest
from fixtures import chained,legacy
try:
    from tools.visirupt_pipeline.macho import parse_macho
    from tools.visirupt_pipeline.bindings import inventory_imports,decode_leb
except ImportError: inventory_imports=None
class BindingTests(unittest.TestCase):
    def setUp(self):self.assertIsNotNone(inventory_imports,'logical import parser missing')
    def test_chained_formats_retain_provider_weak_flag_and_signed_addend(self):
        for fmt in (1,2,3):
            data=chained(fmt=fmt);rows=inventory_imports(data,parse_macho(data))
            self.assertEqual(1,len(rows))
            r=rows[0]
            self.assertEqual(('/two','_test',True), (r['provider'],r['symbol'],r['weak']))
            self.assertEqual(0 if fmt==1 else -7,r['addend'])
    def test_negative_special_ordinal_is_preserved(self):
        data=chained(ordinal=-2);r=inventory_imports(data,parse_macho(data))[0]
        self.assertEqual(-2,r['ordinal']);self.assertEqual('SPECIAL:-2',r['provider'])
    def test_invalid_chained_table_offsets_and_formats_are_rejected(self):
        for relative,value in ((8,0xffffffff),(12,0xffffffff),(16,0xffffffff),(20,7),(24,1)):
            data=bytearray(chained());base=len(data)-len(struct.pack('<7I',0,28,32,40,1,2,0))-4-8-6
            # Find actual fixups via parsed command, rather than guessing its file location.
            base=parse_macho(bytes(data))['fixups'][0]
            struct.pack_into('<I',data,base+relative,value)
            with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):inventory_imports(bytes(data),parse_macho(bytes(data)))
    def test_legacy_bind_preserves_signed_addend_and_native_address(self):
        data=legacy(b'\x12\x40_test\0\x51\x60\x79\x70\x08\x90\x00')
        rows=inventory_imports(data,parse_macho(data))
        self.assertEqual(('/two','_test',-7,0x1008),tuple(rows[0][k] for k in ('provider','symbol','addend','address')))
    def test_bad_provider_segment_or_unterminated_symbol_rejected(self):
        for stream in (b'\x13\x40_test\0\x70\x00\x90\0',b'\x12\x40noend',b'\x12\x40_test\0\x71\x00\x90\0',b'\x20\x80'):
            data=legacy(stream)
            with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):inventory_imports(data,parse_macho(data))
    def test_leb_is_bounded(self):
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):decode_leb(b'\x80'*12,0,False)
        self.assertEqual((-7,1),decode_leb(b'\x79',0,True))
    def test_export_trie_empty_edge_is_valid_without_permitting_cycles(self):
        from fixtures import macho
        from tools.visirupt_pipeline.bindings import inventory_exports
        trie=b'\x00\x01\x00\x04\x02\x00\x01\x00'
        command=struct.pack('<4I',0x80000033,16,48,len(trie))
        data=macho([command],trie)
        self.assertEqual([{'symbol':'','flags':0,'address':1}],inventory_exports(data,parse_macho(data)))
        cyclic=macho([command],b'\x00\x01\x00\x00\x00\x00\x00\x00')
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):inventory_exports(cyclic,parse_macho(cyclic))
    def test_shared_export_nodes_cannot_expand_without_a_budget(self):
        from fixtures import macho
        from tools.visirupt_pipeline.bindings import inventory_exports
        from unittest.mock import patch
        # Four edges point at one node; that node repeats four empty-leaf visits.
        trie=b'\x00\x04a\x00\x0eb\x00\x0ec\x00\x0ed\x00\x0e'+b'\x00\x04a\x00\x1cb\x00\x1cc\x00\x1cd\x00\x1c'+b'\x00\x00'
        command=struct.pack('<4I',0x80000033,16,48,len(trie));data=macho([command],trie)
        with patch('tools.visirupt_pipeline.bindings.MAX_RECORDS',5):
            with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):inventory_exports(data,parse_macho(data))
