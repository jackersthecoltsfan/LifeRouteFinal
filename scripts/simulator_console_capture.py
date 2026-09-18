"""Bounded simctl stdout/stderr capture with an explicit console fallback."""
from dataclasses import dataclass
import json
from pathlib import Path
import subprocess
import time
from typing import Callable, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


PASS = "PASS"
FAIL = "FAIL"
CAPTURE_INCOMPLETE = "CAPTURE INCOMPLETE"


def classify_capture(text: str, pass_markers: Iterable[str], fail_markers: Iterable[str]) -> Tuple[str, Optional[str]]:
    """Classify only explicit native terminal markers.

    Missing, empty, and partial output are intentionally incomplete. A real
    failure marker wins if any failure marker is present, so a later unrelated
    line cannot promote an observed failure to PASS.
    """
    lines = [line.strip() for line in text.splitlines()]
    failures = [line for line in lines if any(line.startswith(marker) for marker in fail_markers)]
    if failures:
        return FAIL, failures[-1]
    passes = [line for line in lines if any(line.startswith(marker) for marker in pass_markers)]
    if passes:
        return PASS, passes[-1]
    return CAPTURE_INCOMPLETE, None


@dataclass(frozen=True)
class CaptureResult:
    state: str
    marker: Optional[str]
    stdout: str
    stderr: str
    mode: str
    reason: str
    commands: Tuple[Dict[str, object], ...]

    @property
    def output(self) -> str:
        return "\n".join(part for part in (self.stdout, self.stderr) if part)

    @property
    def complete(self) -> bool:
        return self.state != CAPTURE_INCOMPLETE


def _as_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode(errors="replace")
    return str(value)


def _record(command: Sequence[str], returncode: Optional[int], stdout: str, stderr: str,
            timed_out: bool = False) -> Dict[str, object]:
    return {
        "command": list(command),
        "exit": returncode,
        "timed_out": timed_out,
        "stdout_bytes": len(stdout.encode()),
        "stderr_bytes": len(stderr.encode()),
    }


def _run(command: Sequence[str], *, env: Optional[Mapping[str, str]], cwd: Path,
         timeout: Optional[float] = None) -> Tuple[subprocess.CompletedProcess, str, str, bool]:
    try:
        result = subprocess.run(command, env=env, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return result, result.stdout or "", result.stderr or "", False
    except subprocess.TimeoutExpired as error:
        returncode = None
        stdout = _as_text(error.stdout)
        stderr = _as_text(error.stderr)
        result = subprocess.CompletedProcess(command, returncode, stdout, stderr)
        return result, stdout, stderr, True


def _write_receipt(stdout_path: Path, result: CaptureResult, fallback_attempted: bool) -> None:
    receipt = {
        "state": result.state,
        "marker": result.marker,
        "mode": result.mode,
        "reason": result.reason,
        "redirected_output": str(stdout_path),
        "fallback_attempted": fallback_attempted,
        "commands": list(result.commands),
    }
    (stdout_path.parent / "simulator-console-capture.json").write_text(json.dumps(receipt, indent=2) + "\n")


def capture_simctl_launch(
    *,
    simulator: str,
    bundle_id: str,
    arguments: Sequence[str],
    stdout_path: Path,
    stderr_path: Path,
    timeout_seconds: float,
    pass_markers: Iterable[str] = (),
    fail_markers: Iterable[str] = (),
    ready: Optional[Callable[[str], bool]] = None,
    env: Optional[Mapping[str, str]] = None,
    cwd: Optional[Path] = None,
    redirect_probe_seconds: float = 1.0,
    simctl_command: Sequence[str] = ("xcrun", "simctl"),
) -> CaptureResult:
    """Run a native Simulator launch and fail closed on missing evidence.

    The existing redirected launch gets its original timeout. If its output is
    absent after a short probe, or never reaches the supplied terminal/ready
    predicate, a second bounded ``--console`` launch is attempted. The direct
    console output is written to the same evidence paths, and is classified by
    the same existing markers/predicate.
    """
    workdir = cwd or Path.cwd()
    stdout_path = stdout_path.resolve()
    stderr_path = stderr_path.resolve()
    pass_markers = tuple(pass_markers)
    fail_markers = tuple(fail_markers)
    commands: List[Dict[str, object]] = []

    def state_for(text: str) -> Tuple[str, Optional[str]]:
        if ready is not None and ready(text):
            return PASS, None
        return classify_capture(text, pass_markers, fail_markers)

    redirect_command = [
        *simctl_command, "launch", "--terminate-running-process",
        "--stdout=" + str(stdout_path), "--stderr=" + str(stderr_path),
        simulator, bundle_id, *arguments,
    ]
    launch, _, _, launch_timed_out = _run(redirect_command, env=env, cwd=workdir)
    commands.append(_record(redirect_command, launch.returncode, launch.stdout or "", launch.stderr or "", launch_timed_out))

    if launch.returncode == 0:
        deadline = time.monotonic() + timeout_seconds
        probe_deadline = time.monotonic() + min(redirect_probe_seconds, timeout_seconds)
        while time.monotonic() < deadline:
            redirected_stdout = stdout_path.read_text(errors="replace") if stdout_path.exists() else ""
            redirected_stderr = stderr_path.read_text(errors="replace") if stderr_path.exists() else ""
            redirected_output = "\n".join(part for part in (redirected_stdout, redirected_stderr) if part)
            state, marker = state_for(redirected_output)
            if state != CAPTURE_INCOMPLETE:
                result = CaptureResult(state, marker, redirected_stdout, redirected_stderr,
                                       "redirected", "redirected capture completed", tuple(commands))
                _write_receipt(stdout_path, result, False)
                return result
            if redirected_output.strip() or time.monotonic() < probe_deadline:
                time.sleep(0.1)
                continue
            break
        reason = "redirected capture remained empty" if not stdout_path.exists() and not stderr_path.exists() else "redirected capture did not reach a terminal marker"
    else:
        reason = "redirected simctl launch failed before a native result was captured"

    direct_command = [
        *simctl_command, "launch", "--console", "--terminate-running-process",
        simulator, bundle_id, *arguments,
    ]
    direct, direct_stdout, direct_stderr, direct_timed_out = _run(
        direct_command, env=env, cwd=workdir, timeout=timeout_seconds
    )
    commands.append(_record(direct_command, direct.returncode, direct_stdout, direct_stderr, direct_timed_out))
    if direct_timed_out:
        terminate_command = [*simctl_command, "terminate", simulator, bundle_id]
        terminated, terminated_stdout, terminated_stderr, terminated_timed_out = _run(
            terminate_command, env=env, cwd=workdir, timeout=10
        )
        commands.append(_record(terminate_command, terminated.returncode, terminated_stdout,
                                terminated_stderr, terminated_timed_out))
        reason += "; direct console fallback timed out"
    direct_state, direct_marker = state_for("\n".join(part for part in (direct_stdout, direct_stderr) if part))
    stdout_path.write_text(direct_stdout)
    stderr_path.write_text(direct_stderr)
    result = CaptureResult(direct_state, direct_marker, direct_stdout, direct_stderr,
                           "direct-console", reason, tuple(commands))
    _write_receipt(stdout_path, result, True)
    return result
