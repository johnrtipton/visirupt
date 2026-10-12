import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location('background_transfer', pathlib.Path(__file__).parents[1] / 'background_transfer.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RangePlanningTests(unittest.TestCase):
    def setUp(self):
        self.asset = dict(bytes=module.CHUNK * 2 + 123, sha256='a' * 64)

    def checkpoint(self, offset=64, verified=False):
        return dict(source_sha256=self.asset['sha256'], offset=offset, verified=verified,
                    chunks=[dict(offset=0, bytes=offset)] if offset else [])

    def test_exact_partial_prefix_is_preserved(self):
        result = module.ranges(self.asset, self.checkpoint())
        self.assertEqual(result[0], (64, module.CHUNK))
        self.assertEqual(sum(size for _, size in result), self.asset['bytes'] - 64)
        self.assertEqual(result[-1][0] + result[-1][1], self.asset['bytes'])

    def test_completed_files_are_skipped(self):
        self.assertEqual(module.ranges(self.asset, self.checkpoint(self.asset['bytes'], True)), [])

    def test_new_file_has_no_missing_or_overlapping_bytes(self):
        self.assertEqual(module.ranges(self.asset, None), [(0, module.CHUNK), (module.CHUNK, module.CHUNK), (module.CHUNK * 2, 123)])

    def test_wrong_source_rejected(self):
        checkpoint = self.checkpoint()
        checkpoint['source_sha256'] = 'b' * 64
        with self.assertRaises(ValueError):
            module.ranges(self.asset, checkpoint)

    def test_inconsistent_checkpoint_rejected(self):
        checkpoint = self.checkpoint()
        checkpoint['chunks'][0]['offset'] = 1
        with self.assertRaises(ValueError):
            module.ranges(self.asset, checkpoint)
        checkpoint = self.checkpoint()
        checkpoint['offset'] += 1
        with self.assertRaises(ValueError):
            module.ranges(self.asset, checkpoint)

    def test_false_complete_rejected(self):
        with self.assertRaises(ValueError):
            module.ranges(self.asset, self.checkpoint(64, True))


if __name__ == '__main__':
    unittest.main()
