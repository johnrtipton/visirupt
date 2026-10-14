"""Hashed, atomically published stage receipts with dependency invalidation."""
import hashlib
import json
from pathlib import Path
import time
import uuid
from .core import PipelineError, sha256
from .workspace import atomic_json, checked_workspace, private_directory, workspace_lock

DEPENDENCIES = {
    'inspect': (), 'adapters': ('inspect',), 'security': ('inspect',), 'curl': ('inspect',),
    'providers': ('adapters','security','curl'), 'game': ('providers',),
    'host': ('game',), 'assets': ('inspect',), 'transfer': ('assets',),
    'install': ('host','transfer'), 'launch': ('install',),
}

def stage_fingerprint(inputs: dict) -> str:
    return hashlib.sha256(json.dumps(inputs, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()

def read_receipt(workspace: Path, name: str):
    if name not in DEPENDENCIES: raise PipelineError('INVALID_RECEIPT')
    path = workspace / 'receipts' / (name + '.json')
    try:
        checked_workspace(path, [])
        if path.stat().st_size > 4 * 1024 * 1024: return None
        result = json.loads(path.read_text())
        return result if isinstance(result, dict) else None
    except (OSError, ValueError): return None

def validate_receipt(workspace: Path, receipt: dict, _seen=None) -> bool:
    try:
        if not isinstance(receipt, dict) or receipt.get('schema_version') != 1 or receipt.get('state') != 'complete': return False
        name = receipt.get('stage'); seen = set(_seen or ())
        if name not in DEPENDENCIES or name in seen: return False
        seen.add(name)
        if not isinstance(receipt.get('fingerprint'), str) or not receipt['fingerprint']: return False
        deps = receipt.get('dependencies')
        if not isinstance(deps, dict) or set(deps) != set(DEPENDENCIES[name]): return False
        for dependency, fingerprint in deps.items():
            current = read_receipt(workspace, dependency)
            if not current or [current.get('fingerprint'),current.get('run_id')] != fingerprint or not validate_receipt(workspace, current, seen): return False
        if not isinstance(receipt.get('outputs'), list) or not receipt['outputs']: return False
        for artifact in receipt['outputs']:
            if not isinstance(artifact, dict): return False
            relative = Path(artifact['path'])
            if relative.is_absolute() or '..' in relative.parts: return False
            path = workspace / relative
            checked_workspace(path, [])
            if not path.resolve().is_relative_to((workspace / 'stages' / name).resolve()): return False
            if not path.is_file() or path.stat().st_size != artifact['bytes'] or sha256(path) != artifact['sha256']: return False
        return True
    except (OSError, ValueError, KeyError, TypeError): return False

def invalidate_dependents(workspace: Path, name: str):
    pending = {name}
    for candidate in DEPENDENCIES:
        if set(DEPENDENCIES[candidate]) & pending:
            pending.add(candidate)
            receipt = read_receipt(workspace, candidate)
            if receipt:
                receipt['state'] = 'invalid'; receipt['error_code'] = 'INVALID_RECEIPT'
                atomic_json(workspace / 'receipts' / (candidate + '.json'), receipt)

def run_stage(workspace: Path, name: str, fingerprint: str, action) -> dict:
    if name not in DEPENDENCIES: raise PipelineError('INVALID_RECEIPT', 'unknown stage')
    with workspace_lock(workspace):
        current = read_receipt(workspace, name)
        if current and current.get('fingerprint') == fingerprint and validate_receipt(workspace, current): return current
        dependencies = {}
        for dependency in DEPENDENCIES[name]:
            parent = read_receipt(workspace, dependency)
            if not parent or not validate_receipt(workspace, parent):
                raise PipelineError('INVALID_RECEIPT', 'dependency not verified')
            dependencies[dependency] = [parent['fingerprint'],parent['run_id']]
        invalidate_dependents(workspace, name)
        root = workspace / 'stages' / name / uuid.uuid4().hex
        private_directory(root)
        receipt = {'schema_version':1,'stage':name,'state':'running','fingerprint':fingerprint,
                   'dependencies':dependencies,'outputs':[], 'started':time.time(),'run_id':root.name}
        receipt_path = workspace / 'receipts' / (name + '.json')
        atomic_json(receipt_path, receipt)
        try:
            outputs = action(root)
            for path in outputs:
                if path.is_symlink(): raise PipelineError('INVALID_RECEIPT', 'symlink artifact')
                checked_workspace(path, [])
                if not path.resolve().is_relative_to(root.resolve()) or not path.is_file():
                    raise PipelineError('INVALID_RECEIPT', 'output outside owned stage')
                receipt['outputs'].append({'path':str(path.relative_to(workspace)), 'bytes':path.stat().st_size, 'sha256':sha256(path)})
            receipt['state'] = 'complete'
            if not validate_receipt(workspace, receipt): raise PipelineError('INVALID_RECEIPT')
            atomic_json(receipt_path, receipt)
            return receipt
        except BaseException as error:
            receipt['state'] = 'failed'; receipt['error_code'] = getattr(error, 'code', 'TOOL_FAILED')
            atomic_json(receipt_path, receipt)
            raise
