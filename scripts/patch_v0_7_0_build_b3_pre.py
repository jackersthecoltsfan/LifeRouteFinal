#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/SessionToolsViews.swift"


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    anchor = "// v0.7.0 B.3 compatibility anchor: struct ClientVisualIconMakerView: View {\n"
    if anchor in text:
        return
    target = "private struct VisualWorkspaceCard: View {"
    if target not in text:
        raise SystemExit("v0.7.0 Build B.3 prepatch failed: VisualWorkspaceCard boundary missing")
    text = text.replace(target, anchor + target, 1)
    PATH.write_text(text, encoding="utf-8")
    print("LifeRoute v0.7.0 Build B.3 visual section compatibility anchor applied.")


if __name__ == "__main__":
    main()
