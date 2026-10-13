"""Private workspace containment. Validation never creates files."""
from pathlib import Path
from .core import PipelineError

def overlaps(a: Path, b: Path) -> bool:
    return a == b or a.is_relative_to(b) or b.is_relative_to(a)

def checked_workspace(path: Path, protected: list[Path]) -> Path:
    absolute = path.absolute()
    for component in (absolute, *absolute.parents):
        trusted = {Path('/var'): Path('/private/var'), Path('/tmp'): Path('/private/tmp'), Path('/etc'): Path('/private/etc')}
        if component.is_symlink() and trusted.get(component) != component.resolve():
            raise PipelineError('WORKSPACE_OVERLAP', 'symlink workspace')
    resolved = absolute.resolve()
    if any(overlaps(resolved, item.resolve()) for item in protected):
        raise PipelineError('WORKSPACE_OVERLAP', 'protected input or source tree')
    return resolved

import contextlib
import fcntl
import json
import os
import tempfile

def private_directory(path: Path) -> None:
    checked_workspace(path, [])
    path.mkdir(parents=True, mode=0o700, exist_ok=True)
    if not path.is_dir() or path.stat().st_uid != os.getuid():
        raise PipelineError('WORKSPACE_OVERLAP', 'workspace ownership')
    path.chmod(0o700)

def atomic_json(path: Path, value: dict) -> None:
    checked_workspace(path, [])
    path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    payload = json.dumps(value, sort_keys=True, indent=2, allow_nan=False).encode() + b'\n'
    if len(payload) > 4 * 1024 * 1024:
        raise PipelineError('INVALID_RECEIPT', 'receipt too large')
    fd, temporary = tempfile.mkstemp(prefix='.receipt-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(payload); stream.flush(); os.fsync(stream.fileno())
        # Never follow or silently replace a symlink at the destination.
        checked_workspace(path, [])
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY)
        try: os.fsync(directory)
        finally: os.close(directory)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)

@contextlib.contextmanager
def workspace_lock(path: Path):
    private_directory(path)
    lock = path / '.writer.lock'
    checked_workspace(lock, [])
    fd = os.open(lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try: fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise PipelineError('WORKSPACE_BUSY') from None
        yield
    finally:
        os.close(fd)
