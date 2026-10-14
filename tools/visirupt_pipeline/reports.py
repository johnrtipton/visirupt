"""Reconstruct shareable drafts from a small typed schema, never raw diagnostics."""
import json
import os
from pathlib import Path
import re
import subprocess
from .core import ROOT,RECIPE_ID,PipelineError
from .stages import DEPENDENCIES,read_receipt,validate_receipt
from .workspace import checked_workspace

STATES={'pending','running','complete','failed','invalid'}
ERRORS={'UNSUPPORTED_INPUT','WORKSPACE_OVERLAP','WORKSPACE_BUSY','INVALID_RECEIPT','INVALID_BINARY','SOURCE_CHANGED','TOOL_FAILED','DEVICE_BUSY','INCOMPLETE_TRANSFER','CONTAINER_OWNERSHIP_UNKNOWN'}
HUMAN=('menu','gameplay','movement_release','turn_look','fire','scroll','output_1280x720','audio','save_relaunch','extended_stability','independent_reproduction')
OUTCOMES={'passed','failed','pending','skipped'}

def stage_status(workspace:Path) -> dict:
    checked_workspace(workspace,[ROOT]);result={}
    for name in DEPENDENCIES:
        receipt=read_receipt(workspace,name)
        state=receipt.get('state') if receipt else 'pending'
        if not isinstance(state,str) or state not in STATES:state='invalid'
        if state=='complete' and not validate_receipt(workspace,receipt):state='invalid'
        item={'state':state}
        code=receipt.get('error_code') if receipt else None
        if state=='invalid':code='INVALID_RECEIPT'
        if isinstance(code,str) and code in ERRORS:item['error_code']=code
        result[name]=item
    return result

def mapping(value):return value if isinstance(value,dict) else {}

def public_report(private:dict) -> dict:
    if not isinstance(private,dict):raise PipelineError('INVALID_RECEIPT','report source')
    recipe=mapping(private.get('recipe'))
    if recipe.get('id')!=RECIPE_ID or type(recipe.get('version')) is not int or not 1<=recipe['version']<=1000:
        raise PipelineError('INVALID_RECEIPT','report recipe')
    result={'schema_version':1,'recipe':{'id':RECIPE_ID,'version':recipe['version']},'stages':{},'tools':{},'counts':{},'human_tests':{key:'pending' for key in HUMAN}}
    revision=private.get('source_revision')
    if isinstance(revision,str) and re.fullmatch('[0-9a-f]{40}',revision):result['source_revision']=revision
    for name,item in mapping(private.get('stages')).items():
        if name not in DEPENDENCIES or not isinstance(item,dict) or not isinstance(item.get('state'),str) or item.get('state') not in STATES:continue
        result['stages'][name]={'state':item['state']}
        if isinstance(item.get('error_code'),str) and item.get('error_code') in ERRORS:result['stages'][name]['error_code']=item['error_code']
    for name in ('sdk','python','xcode','os'):
        value=mapping(private.get('tools')).get(name)
        if isinstance(value,str) and re.fullmatch(r'[0-9]{1,2}(?:\.[0-9]{1,3}){1,2}',value):result['tools'][name]=value
    if isinstance(private.get('hardware'),str) and private.get('hardware') in ('M2 Vision Pro','M5 Vision Pro'):result['hardware']=private['hardware']
    for name in ('files','bytes','frameworks','tests_passed','tests_skipped'):
        value=mapping(private.get('counts')).get(name)
        if type(value) is int and 0<=value<=10**13:result['counts'][name]=value
    for name,value in mapping(private.get('human_tests')).items():
        if name in HUMAN and isinstance(value,str) and value in OUTCOMES:result['human_tests'][name]=value
    if any(result['stages'].get(name,{}).get('state')!='complete' for name in ('install','launch')):
        for name in HUMAN:
            if result['human_tests'][name]=='passed':result['human_tests'][name]='pending'
    return result

def write_report(private:dict,output:Path) -> dict:
    result=public_report(private);checked_workspace(output,[ROOT])
    if not output.parent.is_dir():raise PipelineError('UNSUPPORTED_INPUT','report parent missing')
    try:fd=os.open(output,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    except FileExistsError:raise PipelineError('UNSUPPORTED_INPUT','report draft already exists') from None
    try:
        with os.fdopen(fd,'w') as handle:
            json.dump(result,handle,indent=2,sort_keys=True,allow_nan=False);handle.write('\n');handle.flush();os.fsync(handle.fileno())
    except BaseException:
        output.unlink(missing_ok=True);raise
    return {'state':'draft','privacy_review_required':True,'published':False}

def workspace_report(workspace,recipe,human_results=None):
    checked_workspace(workspace,[ROOT])
    revision=subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
    private={'recipe':{'id':recipe['id'],'version':recipe['version']},'source_revision':revision,'stages':stage_status(workspace)}
    if human_results:
        path=checked_workspace(Path(human_results),[])
        if path.stat().st_size>65536:raise PipelineError('INVALID_RECEIPT','human results too large')
        private['human_tests']=mapping(json.loads(path.read_text()))
    return private
