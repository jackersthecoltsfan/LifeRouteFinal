from pathlib import Path

root = Path(__file__).resolve().parents[1]
auth = (root / "LifeRoute/Web/auth-gate.js").read_text()
prepare = (root / "scripts/prepare_build.sh").read_text()
index = (root / "LifeRoute/Web/index.html").read_text()

checks = []
def require(condition, label):
    checks.append((bool(condition), label))

# v0.4.0 must load directly into the product with no local LifeRoute gate.
for marker in [
    'const AUTH_GATE_ENABLED = 0',
    'window.__lifeRouteAuthGateDisabledV040 = true',
    'cleanupLegacyGate',
    'enabled: !!AUTH_GATE_ENABLED',
    'return false;',
]:
    require(marker in auth, f'direct-launch marker present: {marker}')

# The compatibility stub may clean up stale legacy UI, but it must never create,
# style, poll, hash, or start the old authentication experience.
for forbidden in [
    'Create your login',
    'Welcome back',
    'renderLoading',
    'renderLogin',
    'renderSetup',
    'PBKDF2',
    'crypto.subtle',
    'setInterval(',
    'post({ action: "authStatus"',
    'document.createElement("div")',
    'document.body.appendChild',
    'lrAuthGate{position:fixed',
]:
    require(forbidden not in auth, f'legacy auth work absent: {forbidden}')

require('document.getElementById("lifeRouteAuthGate")?.remove()' in auth, 'stale login overlay is defensively removed')
require('document.getElementById("lifeRouteAuthStyles")?.remove()' in auth, 'stale login styles are defensively removed')
require('<script src="auth-gate.js"></script>' in index, 'recoverable compatibility module remains in deterministic startup order')
require('patch_auth_keychain_reliability_v1.py' in prepare, 'prepared builds deterministically recreate the inert auth module')

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute v0.4.0 direct-launch audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(1)
print('LifeRoute launches directly with no login overlay, polling, PIN derivation, or auth interaction interception.')
