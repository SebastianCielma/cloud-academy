import contextlib
import json
import os
import signal
import socket
import subprocess
import tempfile
import time
import urllib.request

DEFAULT_CONTEXT = os.environ.get("ISTIO_PART2_CONTEXT", "istio-part1")
NAMESPACE = "istio-part2"


def kubectl(*args, context=DEFAULT_CONTEXT, check=True):
    return subprocess.run(
        ["kubectl", "--context", context, *args],
        text=True,
        capture_output=True,
        check=check,
    )


def apply_route(path, context=DEFAULT_CONTEXT, timeout=75):
    result = kubectl("apply", "-f", str(path), context=context)
    print(result.stdout, end="", flush=True)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        data = json.loads(kubectl("-n", NAMESPACE, "get", "httproute", "payment-routing", "-o", "json", context=context).stdout)
        generation = data["metadata"].get("generation", 0)
        for parent in data.get("status", {}).get("parents", []):
            conditions = {condition["type"]: condition for condition in parent.get("conditions", [])}
            accepted = conditions.get("Accepted", {})
            resolved = conditions.get("ResolvedRefs", {})
            if (accepted.get("status") == "True" and resolved.get("status", "True") == "True"
                    and accepted.get("observedGeneration", 0) >= generation):
                time.sleep(3)
                return
        time.sleep(1)
    raise TimeoutError("HTTPRoute was not accepted and programmed within the expected time")


@contextlib.contextmanager
def port_forward(service, local_port, context=DEFAULT_CONTEXT, timeout=25):
    logfile = tempfile.TemporaryFile(mode="w+t")
    process = subprocess.Popen(
        ["kubectl", "--context", context, "-n", NAMESPACE, "port-forward", "--address", "127.0.0.1", f"service/{service}", f"{local_port}:8080"],
        stdout=logfile,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    try:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if process.poll() is not None:
                logfile.seek(0)
                raise RuntimeError(f"Port forwarding failed: {logfile.read()}")
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{local_port}/healthz", timeout=1) as response:
                    if response.status == 200:
                        break
            except (OSError, ValueError, TimeoutError):
                time.sleep(0.3)
        else:
            raise TimeoutError(f"Port forwarding to {service} did not become ready")
        yield f"http://127.0.0.1:{local_port}"
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=4)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        logfile.close()


def get_stats(url):
    with urllib.request.urlopen(f"{url}/stats", timeout=5) as response:
        return json.load(response)
