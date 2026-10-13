import struct
import unittest
from fixtures import macho,dylib
try:
    from tools.visirupt_pipeline.macho import parse_macho, checked_slice, semantic_inventory
except ImportError: parse_macho=None
class MachoTests(unittest.TestCase):
    def setUp(self):self.assertIsNotNone(parse_macho,'bounded parser missing')
    def test_arm64_header_and_library_versions(self):
        image=parse_macho(macho([dylib('/native')]))
        self.assertEqual(6,image['kind'])
        self.assertEqual('/native',image['dependencies'][0]['path'])
        self.assertEqual(0x10000,image['dependencies'][0]['compatibility'])
    def test_truncated_header_and_commands(self):
        for data in (b'',macho()[:31],macho([dylib('/a')])[:-1]):
            with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):parse_macho(data)
    def test_zero_command_length_and_invalid_header_command_count(self):
        data=bytearray(macho([dylib('/a')]))
        struct.pack_into('<I',data,36,0)
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):parse_macho(bytes(data))
        data=bytearray(macho());struct.pack_into('<I',data,16,2)
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):parse_macho(bytes(data))
    def test_command_string_must_terminate_inside_command(self):
        data=bytearray(macho([dylib('/a')]))
        data[56:]=b'A'*(len(data)-56)
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):parse_macho(bytes(data))
    def test_invalid_section_count_and_out_of_file_range(self):
        segment=struct.pack('<II16sQQQQIIII',25,72,b'__TEXT',0x1000,4096,0,4096,5,5,1,0)
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):parse_macho(macho([segment]))
    def test_negative_and_overflow_slice_rejected(self):
        for offset,length in ((-1,1),(1,-1),(2,0),(0,2),(0,1<<65)):
            with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):checked_slice(b'x',offset,length)
    def test_non_arm64_input_rejected(self):
        data=bytearray(macho());struct.pack_into('<I',data,4,7)
        with self.assertRaisesRegex(ValueError,'INVALID_BINARY'):parse_macho(bytes(data))
