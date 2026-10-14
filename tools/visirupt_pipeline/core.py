"""Versioned input identity and structured failures."""
import hashlib
import json
from pathlib import Path
from typing import Any

Recipe = dict[str, Any]
Receipt = dict[str, Any]
Artifact = dict[str, Any]
ROOT = Path(__file__).resolve().parents[2]
RECIPE_ID = 'cyberpunk-mac-2.3-2d-v1'
class PipelineError(ValueError):
    def __init__(self, code: str, detail: str = ''):
        self.code = code
        super().__init__(code + (': ' + detail if detail else ''))

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()

def load_recipe(path: Path | str = RECIPE_ID) -> Recipe:
    if str(path) != RECIPE_ID:
        raise PipelineError('UNSUPPORTED_INPUT', 'recipe is not a reviewed shipped recipe')
    recipe = json.loads((ROOT / 'recipes' / (RECIPE_ID + '.json')).read_text())
    if recipe.get('schema_version') != 1 or recipe.get('id') != RECIPE_ID:
        raise PipelineError('UNSUPPORTED_INPUT', 'recipe schema')
    return recipe

def identify_game(game: Path, recipe: Recipe) -> dict:
    result = {}
    for name, spec in recipe['inputs'].items():
        path = game / 'Contents' / spec['path']
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(game.resolve()):
            raise PipelineError('UNSUPPORTED_INPUT', 'missing or unsafe game input')
        digest = sha256(path)
        if digest != spec['sha256']:
            raise PipelineError('UNSUPPORTED_INPUT', 'game identity mismatch')
        result[name] = {'sha256': digest, 'bytes': path.stat().st_size}
    return result
