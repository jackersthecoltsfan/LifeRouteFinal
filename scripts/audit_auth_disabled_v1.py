from pathlib import Path

root = Path(__file__).resolve().parents[1]
auth = (root / "LifeRoute/Web/auth-gate.js").read_text()
prepare = (root / "scripts/prepare_build.sh").read_text()
index = (root / "LifeRoute/Web/index.html").read_text()

checks = []
def require(condition, label):
    checks.append((bool(condition), label))

require('const AUTH_GATE_ENABLED = false;' in auth, 'login gate is explicitly disabled')
require('if (!AUTH_GATE_ENABLED)' in auth, 'disabled gate short-circuits before auth UI setup')
require('window.LifeRouteAuth = { enabled: false' in auth, 'public auth API reports disabled state')
require('document.getElementById("lifeRouteAuthGate")?.remove()' in auth, 'legacy login overlay is removed if present')
require('document.getElementById("lifeRouteAuthSettingsSection")?.remove()' in auth, 'login/security settings row is removed if present')
require('document.dispatchEvent(new CustomEvent("liferoute-auth-disabled"))' in auth, 'disabled-auth state is observable')
require('patch_disable_auth_gate_v1.py' in prepare, 'disabled-login patch is mandatory in prepared builds')
require('audit_auth_disabled_v1.py' in prepare, 'disabled-login audit is mandatory in prepared builds')
require('<script src="auth-gate.js"></script>' in index, 'prepared app still loads recoverable auth module')

# Ensure the disable block returns before the implementation can call renderLoading/start.
disable_pos = auth.find('if (!AUTH_GATE_ENABLED)')
return_pos = auth.find('    return;', disable_pos)
render_pos = auth.find('  const renderLoading =', disable_pos)
require(disable_pos >= 0 and return_pos > disable_pos and render_pos > return_pos, 'disabled-login return precedes auth UI implementation')

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute disabled-login audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(1)
print('LifeRoute opens directly with login/PIN UI disabled while auth code remains recoverable.')
