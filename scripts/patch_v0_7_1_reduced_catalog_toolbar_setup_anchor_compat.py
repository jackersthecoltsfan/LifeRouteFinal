#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "LifeRoute/V054ContentView.swift"


def main() -> None:
    text = SHELL.read_text(encoding="utf-8")
    if "v0.7.1 custom LifeRoute bottom toolbar" in text:
        return

    final_anchor = "        .tint(themeStore.palette.accent)\n"
    patch_anchor = "            .tint(themeStore.palette.accent)\n"
    if final_anchor not in text:
        raise SystemExit("v0.7.1 toolbar anchor compatibility failed: final Theme Phase 1 tint anchor missing")
    if patch_anchor in text:
        raise SystemExit("v0.7.1 toolbar anchor compatibility failed: patch anchor already exists unexpectedly")

    text = text.replace(final_anchor, patch_anchor, 1)
    SHELL.write_text(text, encoding="utf-8")
    print("LifeRoute v0.7.1 toolbar anchor compatibility applied: final shell tint indentation normalized for the finishing patch.")


if __name__ == "__main__":
    main()
