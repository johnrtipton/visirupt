"""Explicit stage commands; unsupported stages never report success."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from .core import ROOT, RECIPE_ID, PipelineError, load_recipe, identify_game
from .workspace import checked_workspace

COMMANDS = ('doctor','plan','prepare','verify','build','transfer','install','launch','status','report')
LOCAL_STAGES = ('inspect','adapters','security','curl','providers','game')

def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('command', choices=COMMANDS)
    for name in ('workspace','game','curl-archive','device','team','transport','interface','report-output','human-results'):
        p.add_argument('--'+name, default=os.environ.get(name.upper().replace('-','_')) or None)
    p.add_argument('--recipe', default=RECIPE_ID)
    p.add_argument('--download-source', action='store_true')
    p.add_argument('--deploy-receiver', action='store_true')
    p.add_argument('--launch-receiver', action='store_true')
    p.add_argument('--json', action='store_true')
    return p

def doctor(recipe):
    tools = {name: shutil.which(name) is not None for name in ('xcrun','xcodebuild','xcodegen','cmake','ninja','codesign')}
    sdk = None
    if tools['xcrun']:
        r = subprocess.run(['xcrun','--sdk','xros','--show-sdk-version'], text=True, capture_output=True, timeout=30)
        if r.returncode == 0:
            sdk = r.stdout.strip()
    return {'recipe': recipe['id'], 'tools': tools, 'sdk': sdk,
            'supported_toolchain': sdk == recipe['target']['sdk'] and all(tools.values()),
            'python_supported': sys.version_info >= (3,11)}

def main(argv=None):
    p = parser(); args = p.parse_args(argv)
    try:
        recipe = load_recipe(args.recipe)
        mutating = args.command in ('prepare','build','transfer','install','launch','report')
        if mutating and not args.workspace:
            p.error('--workspace is required')
        if args.command in ('transfer','install','launch') and not args.device:
            p.error('--device is required')
        if args.command == 'build' and not args.team:
            p.error('--team is required')
        if args.command == 'prepare' and not args.game:
            p.error('--game is required')
        workspace = None
        if args.workspace:
            protected = [ROOT]
            if args.game:
                protected.append(Path(args.game))
            workspace = checked_workspace(Path(args.workspace), protected)
        if args.command == 'doctor':
            result = doctor(recipe)
            if args.game:
                result['inputs'] = identify_game(Path(args.game), recipe)
        elif args.command == 'plan':
            result = {'recipe': recipe['id'], 'stages': list(LOCAL_STAGES),
                      'device_actions': [], 'download_requested': args.download_source,
                      'writes': ['private workspace stage artifacts and receipts'],
                      'workspace_configured': workspace is not None}
        elif args.command == 'prepare':
            from .preparation import prepare
            result=prepare(ROOT,Path(args.game),workspace,recipe,Path(args.curl_archive) if args.curl_archive else None,args.download_source)
        elif args.command == 'build':
            from .host import build_host
            result=build_host(ROOT,workspace,recipe,args.team)
        elif args.command == 'transfer':
            if not args.game or not args.transport:p.error('--game and --transport are required')
            from .transfer_control import transfer_assets
            result=transfer_assets(workspace,recipe,args.device,args.transport,args.deploy_receiver,game_root=Path(args.game),interface=args.interface,team=args.team,launch_receiver=args.launch_receiver)
        elif args.command == 'install':
            from .device import install_prepared_host
            result=install_prepared_host(workspace,recipe,args.device,deploy_receiver=args.deploy_receiver,launch_receiver=args.launch_receiver,team=args.team)
        elif args.command == 'launch':
            from .device import launch_host
            result=launch_host(workspace,args.device)
        elif args.command == 'verify':
            if workspace is None:p.error('--workspace is required')
            from .verify import verify
            result=verify(workspace,recipe)
        elif args.command == 'status':
            if workspace is None:p.error('--workspace is required')
            from .reports import stage_status
            result={'state':'pending','recipe':recipe['id'],'stages':stage_status(workspace)}
            states={item['state'] for item in result['stages'].values()}
            result['state']='complete' if states=={'complete'} else 'invalid' if 'invalid' in states else 'failed' if 'failed' in states else 'running' if states-{'pending'} else 'pending'
        elif args.command == 'report':
            if not args.report_output:p.error('--report-output is required')
            from .reports import workspace_report,write_report
            result=write_report(workspace_report(workspace,recipe,args.human_results),Path(args.report_output))
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except PipelineError as error:
        print(str(error), file=sys.stderr)
        return 2 if error.code in ('UNSUPPORTED_INPUT','WORKSPACE_OVERLAP') else 1
    except (OSError, ValueError, subprocess.TimeoutExpired):
        print('TOOL_FAILED: inspect private diagnostics', file=sys.stderr)
        return 1
