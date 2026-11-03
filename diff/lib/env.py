"""Paths shared by the Python tools (bug-injection scripts) of the harnesses.

    import sys, pathlib
    sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents
                                if (p / 'lib/env.py').exists())))  # diff/
    from lib.env import REPO, UPSTREAM, OUT, DIFF

THREE_UPSTREAM (default .repos/three.js) and THREE_DIFF_OUT (default diff/.out);
relative values resolve against the repository root.
"""
import os
from pathlib import Path

DIFF = Path(__file__).resolve().parent.parent
REPO = DIFF.parent
UPSTREAM = (REPO / os.environ.get('THREE_UPSTREAM', '.repos/three.js')).resolve()
OUT = (REPO / os.environ.get('THREE_DIFF_OUT', 'diff/.out')).resolve()


def out_dir(*parts):
    d = OUT.joinpath(*parts)
    d.mkdir(parents=True, exist_ok=True)
    return d
