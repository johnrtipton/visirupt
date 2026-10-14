import hashlib,json,os,tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
from tools.visirupt_pipeline.core import load_recipe
try:
    from tools.visirupt_pipeline.assets import build_asset_manifest,patch_arrow_mapping,verify_asset_manifest,normalized_asset_path
except ImportError:build_asset_manifest=None
XML=b'<root><mapping name="RightX_Axis" type="Axis"><button id="IK_Pad_RightAxisX" /></mapping></root>'
class AssetTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(build_asset_manifest,'asset manifest preparation missing')
        self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.root=Path(self.t.name).resolve();self.game=self.root/'Game.app'
        for name,data in [('archive/Mac/a.archive',b'owned archive'),('r6/config/inputUserMappings.xml',XML)]:
            p=self.game/'Contents/Data'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
        self.recipe=load_recipe();self.recipe['assets']=[{'relative_path':'Data/archive/mac/a.archive','bytes':13,'sha256':hashlib.sha256(b'owned archive').hexdigest()},{'relative_path':'Data/r6/config/inputUserMappings.xml','bytes':len(XML),'sha256':hashlib.sha256(XML).hexdigest()}]
    def test_manifest_normalizes_archive_directory_and_separates_original_patch_identity(self):
        output=self.root/'private/asset-manifest.json';m=build_asset_manifest(self.game,output,self.recipe)
        first=m['files'][0];self.assertEqual('Data/archive/mac/a.archive',first['relative_path']);self.assertEqual('Data/archive/Mac/a.archive',first['source_relative_path'])
        mapping=m['files'][1];self.assertNotEqual(mapping['original_sha256'],mapping['sha256'])
        self.assertEqual(XML,(output.parent/'inputUserMappings.original.xml').read_bytes())
        self.assertEqual(XML,(self.game/'Contents/Data/r6/config/inputUserMappings.xml').read_bytes())
        self.assertTrue(verify_asset_manifest(m,self.game)['originals_verified'])
    def test_arrow_patch_is_idempotent_and_preserves_existing_pad_and_other_bytes(self):
        result=patch_arrow_mapping(XML)
        self.assertEqual(result,patch_arrow_mapping(result))
        self.assertIn(b'IK_Pad_RightAxisX',result)
        self.assertIn(b'IK_Left',result);self.assertIn(b'IK_Right',result)
        self.assertTrue(result.startswith(b'<root>'));self.assertTrue(result.endswith(b'</root>'))
    def test_duplicate_or_malformed_mapping_and_unsafe_entities_are_rejected(self):
        for data in (b'<broken',XML.replace(b'</root>',XML+b'</root>'),XML.replace(b'</mapping>',b'<button id="IK_Left" val="0"/></mapping>'),b'<!DOCTYPE root [<!ENTITY a "bad">]>'+XML):
            with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):patch_arrow_mapping(data)
    def test_missing_archive_or_changed_source_hash_cannot_write_manifest(self):
        archive=self.game/'Contents/Data/archive/Mac/a.archive';archive.unlink()
        with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):build_asset_manifest(self.game,self.root/'out/manifest.json',self.recipe)
        self.assertFalse((self.root/'out').exists())
    def test_symlink_source_cannot_escape_source_tree(self):
        archive=self.game/'Contents/Data/archive/Mac/a.archive';archive.unlink();outside=self.root/'outside';outside.write_bytes(b'owned archive');archive.symlink_to(outside)
        with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):build_asset_manifest(self.game,self.root/'out/manifest.json',self.recipe)
        self.assertFalse((self.root/'out').exists())
    def test_case_collision_and_path_traversal_are_rejected(self):
        self.assertEqual('Data/archive/mac/a.archive',normalized_asset_path('Data/archive/Mac/a.archive'))
        for value in ('../Data/a','/Data/a','Data/../a','Data//a'):
            with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):normalized_asset_path(value)
        self.recipe['assets'].append(dict(self.recipe['assets'][0],relative_path='Data/archive/mac/A.archive'))
        with self.assertRaisesRegex(ValueError,'UNSUPPORTED_INPUT'):build_asset_manifest(self.game,self.root/'out/manifest.json',self.recipe)
    def test_source_change_during_hash_never_commits_completion(self):
        from tools.visirupt_pipeline import assets
        old=assets.stable_hash
        def changed(path):
            if path.suffix=='.archive':path.write_bytes(b'changed bytes')
            return old(path)
        with patch.object(assets,'stable_hash',side_effect=changed):
            with self.assertRaisesRegex(ValueError,'SOURCE_CHANGED'):build_asset_manifest(self.game,self.root/'out/manifest.json',self.recipe)
        self.assertFalse((self.root/'out/manifest.json').exists())
