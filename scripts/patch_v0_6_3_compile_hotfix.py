#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "LifeRoute/LifeRouteApp.swift"
text = path.read_text(encoding="utf-8")
text = text.replace("0x929aa2, 0edf1f4", "0x929aa2, 0xedf1f4")
path.write_text(text, encoding="utf-8")
print("LifeRoute v0.6.3 compile hotfix applied.")
