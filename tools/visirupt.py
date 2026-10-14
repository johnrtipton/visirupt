#!/usr/bin/env python3
"""Run the private, exact-build VisiRupt preparation pipeline."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.visirupt_pipeline.cli import main
if __name__ == '__main__':
    raise SystemExit(main())
