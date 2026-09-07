#!/usr/bin/env python3
"""Apply the v2 header conversion to a list of packages, without building.

Reuses convert-easy.py's convert() so the E7 packages get exactly the same
Source-SHA256, Build-Depends and dependency-normalisation treatment the 148 EASY
ones got — including the drop log — rather than a second implementation of it.
"""
import importlib.util, json, sys

spec = importlib.util.spec_from_file_location(
    "ce", "/root/github-repo/huddefs/scripts/convert-easy.py")
ce = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ce)

for p in json.load(open(sys.argv[1])):
    try:
        st, info = ce.convert(p)
        bd = info.get("build_depends") if info else None
        print(f"{p:<16} {st:<12} bd={bd}")
    except Exception as e:
        print(f"{p:<16} EXCEPTION {type(e).__name__}: {e}")
