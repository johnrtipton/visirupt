import hashlib,io,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from tools.visirupt_pipeline import preparation
class DownloadTests(unittest.TestCase):
    def test_interruption_and_bad_hash_do_not_poison_explicit_download_retry(self):
        with tempfile.TemporaryDirectory() as t:
            workspace=Path(t).resolve();target=workspace/'official-curl.tar.xz'
            payload=b'official fixture';recipe={'curl':{'url':'https://curl.se/fixture','archive_sha256':hashlib.sha256(payload).hexdigest()}}
            self.assertTrue(hasattr(preparation,'download_archive'),'retryable download helper missing')
            class Interrupted(io.BytesIO):
                def read(self,n=-1):
                    if self.tell():raise OSError('connection interrupted')
                    return super().read(3)
            for stream in (Interrupted(payload),io.BytesIO(b'wrong')):
                with patch('urllib.request.urlopen',return_value=stream):
                    with self.assertRaises((OSError,ValueError)):preparation.download_archive(workspace,recipe)
                self.assertFalse(target.exists());self.assertFalse(list(workspace.glob('*.download')))
            with patch('urllib.request.urlopen',return_value=io.BytesIO(payload)):
                self.assertEqual(target,preparation.download_archive(workspace,recipe))
            self.assertEqual(payload,target.read_bytes());self.assertEqual(0o600,target.stat().st_mode&0o777)
