"""Owned process execution: no shell, private logs and bounded cancellation."""
import os
from pathlib import Path
import signal
import subprocess
from .core import PipelineError
from .workspace import checked_workspace

def run_tool(argv:list[str],cwd:Path,log:Path,timeout:float) -> dict:
    if not argv or timeout<=0:raise PipelineError('TOOL_FAILED','invalid command')
    checked_workspace(log,[])
    log.parent.mkdir(parents=True,mode=0o700,exist_ok=True)
    fd=os.open(log,os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW,0o600)
    os.fchmod(fd,0o600)
    with os.fdopen(fd,'wb') as stream:
        try:
            process=subprocess.Popen(argv,cwd=cwd,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
        except OSError:raise PipelineError('TOOL_FAILED','tool could not start') from None
        try:
            code=process.wait(timeout=timeout)
        except BaseException:
            try:os.killpg(process.pid,signal.SIGTERM)
            except ProcessLookupError:pass
            try:process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                try:os.killpg(process.pid,signal.SIGKILL)
                except ProcessLookupError:pass
                process.wait()
            raise PipelineError('TOOL_FAILED','owned process interrupted') from None
        if code:raise PipelineError('TOOL_FAILED','see private log')
    return {'returncode':code,'log':str(log)}
