# Build #106 canonical capture evidence

Trusted main `6aaf9ac5234acd3178701fe0f4494675833b84fd` was checked out clean on a
GitHub macOS runner. The historical `scripts/prepare_build.sh` was run one final
time, without any v0.8.1 donor, and its complete resulting tree was captured.

- GitHub Actions run: `33269800816`
- Job: `99146134377`
- Capture artifact: `9719749621`
- Historical preparation time: 13 seconds
- Total capture run: 23 seconds
- Capture archive SHA-256: `b4c7de...` (full value retained in run evidence)
- Materialized shipping patch ID: `cdc8db5d91f95fb85869c76667c77e83a1df8039`
- Canonical-source promotion commit: `d6fa77321bcb4fb03421cc6883ebb222ae7fffdd`

The independently downloaded artifact and the staged canonical shipping diff
produced the same patch ID. The Xcode project did not change during historical
preparation; 22 shipping files did. Expected generated cache noise was excluded.
This exact result is the source-equivalence anchor for consolidation.

Before consolidation, preparation was 382 lines and referenced 51 distinct
patch scripts plus 53 distinct audits across roughly the v0.5, v0.6, v0.7
Build A-E/theme/v0.7.1, and cumulative v0.8 layers. Six repeated Python
`SyntaxWarning` lines came from an archived v0.7 compatibility patch.
