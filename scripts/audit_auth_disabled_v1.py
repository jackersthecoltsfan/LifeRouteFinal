from pathlib import Path

root = Path(__file__).resolve().parents[1]
auth = (root / "LifeRoute/Web/auth-gate.js").read_text()
prepare = (root / "scripts/prepare_build.sh").read_text()
index = (root / "LifeRoute/Web/index.html").read_text()
patch = (root / "scripts/patch_auth_keychain_reliability_v1.py").read_text()

checks = []
def require(condition, label):
    checks.append((bool(condition), label))

# v0.4.0 loads directly into the product. The legacy auth implementation is
# retained below an immediate bypass for future redesign/recovery only.
for marker in [
    'const AUTH_GATE_ENABLED = 0',
    'window.__lifeRouteAuthGateDisabledV040 = true',
    'if (!AUTH_GATE_ENABLED)',
    'removeDisabledAuthUI',
    'window.LifeRouteAuth = { enabled: false',
]:
    require(marker in auth, f'direct-launch marker present: {marker}')

for marker in [
    'document.getElementById("lifeRouteAuthGate")?.remove()',
    'document.getElementById("lifeRouteAuthStyles")?.remove()',
    'document.getElementById("lifeRouteAuthSettingsSection")?.remove()',
    'document.documentElement.removeAttribute("data-life-route-auth-locked")',
    'document.body?.removeAttribute("data-life-route-auth-locked")',
]:
    require(marker in auth, f'stale auth blocker cleanup present: {marker}')

bypass_pos = auth.find('if (!AUTH_GATE_ENABLED)')
return_pos = auth.find('    return;', bypass_pos)
require(bypass_pos >= 0 and return_pos > bypass_pos, 'disabled-login early return exists')
for marker, label in [
    ('const derivePin = async', 'PIN derivation'),
    ('const styles = document.createElement("style")', 'auth style construction'),
    ('const renderLoading =', 'auth loading UI'),
    ('const installSettings =', 'auth settings polling'),
    ('const start = () =>', 'auth startup'),
]:
    position = auth.find(marker, bypass_pos)
    require(position > return_pos, f'disabled-login return precedes {label}')

require('<script src="auth-gate.js"></script>' in index, 'prepared app still loads recoverable auth module')
require('patch_auth_keychain_reliability_v1.py' in prepare, 'prepared builds run auth reliability/bypass path')
require('runpy.run_path("scripts/patch_disable_auth_gate_v1.py"' in patch, 'auth reliability patch deterministically applies bypass')
require('username + 4-digit PIN' in auth and 'PBKDF2' in auth, 'legacy auth implementation remains recoverable below bypass')

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute v0.4.0 direct-launch audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(1)
print('LifeRoute launches directly; auth UI/work is bypassed before execution while the legacy implementation remains recoverable.')
