import argparse
import contextlib
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from loadtest import run

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
CONTEXT = os.environ.get("ISTIO_PART3_CONTEXT", "istio-part1")
AMBIENT = "istio-part3"
SIDECAR = "istio-part3-sidecar"


class ExperimentError(RuntimeError):
    pass


def kubectl(*args, check=True):
    command = ["kubectl", "--context", CONTEXT, *args]
    result = subprocess.run(command, text=True, capture_output=True)
    if check and result.returncode:
        raise ExperimentError(f"Command failed: {' '.join(command)}\n{result.stderr.strip()}")
    return result


def resource(namespace, kind, name):
    response = kubectl("-n", namespace, "get", kind, name, "-o", "json")
    return json.loads(response.stdout)


def apply(filename):
    kubectl("apply", "-f", str(ROOT / filename))


def clear_ambient():
    kubectl("-n", AMBIENT, "delete", "httproute", "payment-timeout", "payment-retries", "inventory-retries", "--ignore-not-found", check=False)
    kubectl("-n", AMBIENT, "delete", "destinationrule", "payment-circuit-breaker", "--ignore-not-found", check=False)
    for service in ("payment-service", "inventory-service"):
        kubectl("-n", AMBIENT, "label", "service", service, "istio.io/use-waypoint-", check=False)


def clear_sidecar():
    kubectl("-n", SIDECAR, "delete", "virtualservice", "payment-retries", "payment-fault", "inventory-retries", "--ignore-not-found", check=False)
    kubectl("-n", SIDECAR, "delete", "destinationrule", "payment-circuit-breaker", "--ignore-not-found", check=False)


def enable_waypoint(service):
    kubectl("-n", AMBIENT, "label", "service", service, "istio.io/use-waypoint=waypoint", "--overwrite")
    gateway = resource(AMBIENT, "gateways.gateway.networking.k8s.io", "waypoint")
    conditions = gateway.get("status", {}).get("conditions", [])
    if not any(item.get("type") == "Programmed" and item.get("status") == "True" for item in conditions):
        raise ExperimentError("Waypoint is not Programmed=True")


def route_ready(name):
    for _ in range(20):
        document = resource(AMBIENT, "httproute", name)
        parents = document.get("status", {}).get("parents", [])
        conditions = [item for parent in parents for item in parent.get("conditions", [])]
        accepted = [item for item in conditions if item.get("type") == "Accepted"]
        resolved = [item for item in conditions if item.get("type") == "ResolvedRefs"]
        if accepted and accepted[0].get("status") == "False":
            raise ExperimentError(f"HTTPRoute {name} was rejected: {accepted[0]}")
        if resolved and resolved[0].get("status") == "False":
            raise ExperimentError(f"HTTPRoute {name} has unresolved references: {resolved[0]}")
        if any(item.get("status") == "True" for item in accepted):
            return
        time.sleep(1)
    raise ExperimentError(f"HTTPRoute {name} has no Accepted=True status")


def retry_schema_supported():
    document = resource("default", "crd", "httproutes.gateway.networking.k8s.io")
    for version in document.get("spec", {}).get("versions", []):
        if version.get("name") != "v1":
            continue
        schema = version.get("schema", {}).get("openAPIV3Schema", {})
        try:
            return "retry" in schema["properties"]["spec"]["properties"]["rules"]["items"]["properties"]
        except KeyError:
            return False
    return False


def available_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def fetch(url, headers=None, method="GET", body=None, timeout=15):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(url, headers=headers or {}, data=data, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        try:
            data = json.load(error)
        except ValueError:
            data = {"error": "invalid_json"}
        return error.code, data


@contextlib.contextmanager
def tunnels(namespace, names):
    processes = []
    ports = {}
    try:
        for name in names:
            port = available_port()
            process = subprocess.Popen(
                ["kubectl", "--context", CONTEXT, "-n", namespace, "port-forward", f"service/{name}", f"{port}:8080", "--address", "127.0.0.1"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
            )
            processes.append(process)
            ports[name] = f"http://127.0.0.1:{port}"
            ready = False
            for _ in range(40):
                if process.poll() is not None:
                    error = process.stderr.read().decode(errors="replace")
                    raise ExperimentError(f"Port-forward failed for {name}: {error}")
                try:
                    code, _ = fetch(ports[name] + "/healthz", timeout=0.5)
                    if code == 200:
                        ready = True
                        break
                except (OSError, TimeoutError, ValueError):
                    time.sleep(0.25)
            if not ready:
                raise ExperimentError(f"Port-forward timed out for {name}")
        yield ports
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
        for process in processes:
            try:
                process.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate()


class Reporter:
    def __init__(self, name):
        REPORTS.mkdir(exist_ok=True)
        self.name = name
        self.log = REPORTS / f"{name}.log"
        self.events = []
        self.log.write_text("", encoding="utf-8")

    def record(self, title, data):
        self.events.append({"step": title, "data": data})
        rendered = f"{title}\n{json.dumps(data, indent=2, sort_keys=True)}\n\n"
        with self.log.open("a", encoding="utf-8") as destination:
            destination.write(rendered)
        print(rendered, end="", flush=True)
        (REPORTS / f"{self.name}.json").write_text(
            json.dumps(self.events, indent=2) + "\n", encoding="utf-8"
        )

    def benchmark(self, title, url, requests=30, concurrency=4, headers=None):
        summary, samples = run(url, requests, concurrency, headers=headers or {}, timeout=20)
        self.record(title, summary)
        import csv
        filename = REPORTS / f"{self.name}-{title.replace(' ', '-').lower()}.csv"
        with filename.open("w", newline="", encoding="utf-8") as file:
            writer = csv.DictWriter(file, fieldnames=samples[0])
            writer.writeheader()
            writer.writerows(samples)
        return summary


def baseline(reporter):
    clear_ambient()
    with tunnels(AMBIENT, ["api-gateway", "payment-service", "inventory-service"]) as urls:
        reporter.record("Environment", {"namespace": AMBIENT, "context": CONTEXT, "mode": "ambient_without_l7_rules"})
        reporter.benchmark("Healthy baseline", urls["api-gateway"] + "/order", 60, 5)
        reporter.benchmark("Inventory periodic 503 without retries", urls["api-gateway"] + "/order", 60, 5, {"X-Lab-Inventory-Fail-Every": "3"})
        reporter.record("Inventory counters", fetch(urls["inventory-service"] + "/stats")[1])


def timeouts(reporter):
    clear_ambient()
    enable_waypoint("payment-service")
    apply("manifests/ambient/10-payment-timeout.yaml")
    route_ready("payment-timeout")
    try:
        with tunnels(AMBIENT, ["api-gateway", "payment-service"]) as urls:
            previous = fetch(urls["payment-service"] + "/stats")[1]
            reporter.benchmark("Delayed payment with 2s mesh timeout", urls["api-gateway"] + "/order/payment-only", 1, 1, {"X-Lab-Payment-Delay-Ms": "5000"})
            immediate = fetch(urls["payment-service"] + "/stats")[1]
            time.sleep(5.2)
            eventual = fetch(urls["payment-service"] + "/stats")[1]
            reporter.record("Payment continues after client timeout", {"before": previous, "immediately_after": immediate, "after_wait": eventual})
    finally:
        clear_ambient()


def retries(reporter):
    clear_ambient()
    with tunnels(AMBIENT, ["api-gateway", "inventory-service"]) as urls:
        baseline_result = reporter.benchmark("Ambient baseline intermittent inventory 503", urls["api-gateway"] + "/order", 60, 4, {"X-Lab-Inventory-Fail-Every": "3"})
    supported = retry_schema_supported()
    reporter.record("Gateway API retry schema availability", {"retry_field_present": supported})
    if not supported:
        reporter.record("Fallback", {"required": "Deploy sidecar variant and run retries-sidecar", "reason": "HTTPRoute retry field absent in installed CRD"})
        return
    enable_waypoint("inventory-service")
    try:
        apply("manifests/ambient/20-inventory-retries.experimental.yaml")
        route_ready("inventory-retries")
        with tunnels(AMBIENT, ["api-gateway", "inventory-service"]) as urls:
            retry_result = reporter.benchmark("Ambient inventory with bounded retry", urls["api-gateway"] + "/order", 60, 4, {"X-Lab-Inventory-Fail-Every": "3"})
            reporter.record("Inventory counters", fetch(urls["inventory-service"] + "/stats")[1])
            improved = retry_result["error_rate_percent"] < baseline_result["error_rate_percent"]
            reporter.record("Observed retry effectiveness", {"error_rate_improved": improved, "baseline_error_rate_percent": baseline_result["error_rate_percent"], "retry_error_rate_percent": retry_result["error_rate_percent"]})
            if not improved:
                reporter.record("Fallback", {"required": "Deploy sidecar variant and run retries-sidecar", "reason": "No measurable improvement from ambient HTTPRoute retry"})
    except ExperimentError as error:
        reporter.record("Fallback", {"required": "Deploy sidecar variant and run retries-sidecar", "reason": str(error)})
    finally:
        clear_ambient()


def retries_sidecar(reporter):
    clear_sidecar()
    with tunnels(SIDECAR, ["order-service", "inventory-service"]) as urls:
        reporter.benchmark("Sidecar inventory baseline", urls["order-service"] + "/order", 60, 4, {"X-Lab-Inventory-Fail-Every": "3"})
        apply("manifests/sidecar/11-inventory-retries.yaml")
        try:
            reporter.benchmark("Sidecar inventory with bounded retry", urls["order-service"] + "/order", 60, 4, {"X-Lab-Inventory-Fail-Every": "3"})
            reporter.record("Inventory counters", fetch(urls["inventory-service"] + "/stats")[1])
        finally:
            clear_sidecar()


def amplification(reporter):
    clear_sidecar()
    with tunnels(SIDECAR, ["order-service", "payment-service"]) as urls:
        for name, app_retries, mesh_retries in (
            ("No retries", 0, False),
            ("Application retries only", 2, False),
            ("Mesh retries only", 0, True),
            ("Application and mesh retries", 2, True),
        ):
            clear_sidecar()
            if mesh_retries:
                apply("manifests/sidecar/10-payment-retries.yaml")
            time.sleep(5)
            request_id = str(uuid.uuid4())
            status, response = fetch(
                urls["order-service"] + "/order/payment-only",
                headers={"X-Request-ID": request_id, "X-Lab-App-Retries": str(app_retries), "X-Lab-Payment-Always-503": "true"},
            )
            _, stats = fetch(urls["payment-service"] + "/stats", headers={"X-Request-ID": request_id})
            reporter.record(name, {"status": status, "response": response, "payment_requests_received": stats["probe_attempts_for_request"], "request_id": request_id})
    clear_sidecar()


def idempotency(reporter):
    clear_ambient()
    with tunnels(AMBIENT, ["api-gateway", "payment-service"]) as urls:
        payload = {"order_id": str(uuid.uuid4()), "amount_cents": 1599, "currency": "USD"}
        for name, key in (("Without idempotency key", None), ("With idempotency key", str(uuid.uuid4()))):
            before = fetch(urls["payment-service"] + "/stats")[1]
            headers = {"X-Request-ID": str(uuid.uuid4()), "X-Lab-App-Retries": "1", "X-Lab-Drop-First-Response": "true"}
            if key:
                headers["Idempotency-Key"] = key
            status, response = fetch(urls["api-gateway"] + "/checkout", headers=headers, method="POST", body=payload)
            after = fetch(urls["payment-service"] + "/stats")[1]
            reporter.record(name, {
                "status": status,
                "response": response,
                "payment_attempts_delta": after["payment_attempts"] - before["payment_attempts"],
                "payments_created_delta": after["payments_created"] - before["payments_created"],
                "payments_replayed_delta": after["payments_replayed"] - before["payments_replayed"],
            })
        conflict_key = str(uuid.uuid4())
        headers = {"Idempotency-Key": conflict_key, "X-Request-ID": str(uuid.uuid4())}
        first_status, first = fetch(urls["api-gateway"] + "/checkout", headers=headers, method="POST", body=payload)
        second_status, second = fetch(urls["api-gateway"] + "/checkout", headers=headers, method="POST", body={**payload, "amount_cents": 9999})
        reporter.record("Same key with different payload", {"first_status": first_status, "first": first, "second_status": second_status, "second": second})


def faults(reporter):
    clear_sidecar()
    with tunnels(SIDECAR, ["order-service", "payment-service"]) as urls:
        for name, file, count in (
            ("Injected 3s delay", "manifests/sidecar/20-fault-delay.yaml", 3),
            ("Injected 503 abort", "manifests/sidecar/21-fault-abort.yaml", 10),
            ("Injected 25 percent abort", "manifests/sidecar/22-fault-percentage.yaml", 80),
        ):
            clear_sidecar()
            apply(file)
            time.sleep(5)
            before = fetch(urls["payment-service"] + "/stats")[1]
            reporter.benchmark(name, urls["order-service"] + "/order/payment-only", count, min(count, 5))
            after = fetch(urls["payment-service"] + "/stats")[1]
            reporter.record(name + " backend observations", {
                "payment_requests_delta": after["probe_requests_received"] - before["probe_requests_received"],
                "payment_active": after["active_requests"],
            })
    clear_sidecar()


def overload(reporter):
    clear_ambient()
    with tunnels(AMBIENT, ["api-gateway", "payment-service"]) as urls:
        reporter.benchmark("High concurrency without circuit breaking", urls["api-gateway"] + "/order/payment-only", 70, 15, {"X-Lab-Payment-Delay-Ms": "400"})
    enable_waypoint("payment-service")
    apply("manifests/ambient/30-payment-circuit-breaker.yaml")
    try:
        with tunnels(AMBIENT, ["api-gateway", "payment-service"]) as urls:
            before = fetch(urls["payment-service"] + "/stats")[1]
            reporter.benchmark("High concurrency with waypoint circuit breaking", urls["api-gateway"] + "/order/payment-only", 70, 15, {"X-Lab-Payment-Delay-Ms": "400"})
            after = fetch(urls["payment-service"] + "/stats")[1]
            reporter.record("Backend received count under limits", {"received_delta": after["probe_requests_received"] - before["probe_requests_received"], "peak_active": after["peak_active_requests"]})
            reporter.record("DestinationRule status", resource(AMBIENT, "destinationrule", "payment-circuit-breaker"))
    finally:
        clear_ambient()


def overload_sidecar(reporter):
    clear_sidecar()
    with tunnels(SIDECAR, ["order-service", "payment-service"]) as urls:
        reporter.benchmark("Sidecar without limits", urls["order-service"] + "/order/payment-only", 70, 15, {"X-Lab-Payment-Delay-Ms": "400"})
        apply("manifests/sidecar/30-payment-circuit-breaker.yaml")
        try:
            reporter.benchmark("Sidecar with limits", urls["order-service"] + "/order/payment-only", 70, 15, {"X-Lab-Payment-Delay-Ms": "400"})
        finally:
            clear_sidecar()


def cascading(reporter):
    clear_ambient()
    with tunnels(AMBIENT, ["api-gateway", "payment-service", "order-service"]) as urls:
        reporter.benchmark("Slow payment cascading baseline", urls["api-gateway"] + "/order/payment-only", 24, 6, {"X-Lab-Payment-Delay-Ms": "5000"})
        reporter.record("Order baseline counters", fetch(urls["order-service"] + "/stats")[1])
    enable_waypoint("payment-service")
    apply("manifests/ambient/10-payment-timeout.yaml")
    route_ready("payment-timeout")
    try:
        with tunnels(AMBIENT, ["api-gateway", "order-service", "payment-service"]) as urls:
            reporter.benchmark("Slow payment with downstream timeout", urls["api-gateway"] + "/order/payment-only", 24, 6, {"X-Lab-Payment-Delay-Ms": "5000"})
            reporter.record("Order after timeout counters", fetch(urls["order-service"] + "/stats")[1])
            reporter.record("Payment after timeout counters", fetch(urls["payment-service"] + "/stats")[1])
    finally:
        clear_ambient()


def capabilities(reporter):
    reporter.record("Kubernetes context", {"context": CONTEXT, "active_context": kubectl("config", "current-context").stdout.strip()})
    reporter.record("Istio components", kubectl("-n", "istio-system", "get", "deployments,daemonsets", "-o", "wide").stdout)
    reporter.record("Gateway API HTTPRoute retry schema", {"present": retry_schema_supported()})
    reporter.record("Ambient waypoint", resource(AMBIENT, "gateways.gateway.networking.k8s.io", "waypoint"))
    reporter.record("Documented limitations", {
        "ambient_virtualservice": "Alpha; not used with HTTPRoute",
        "ambient_httproute_retry": "Feature tested only when retry is in CRD schema and route is Accepted=True; behavior verified experimentally",
        "fault_injection": "Dedicated sidecar VirtualService variant",
        "circuit_breaking": "DestinationRule on waypoint; sidecar test available separately",
    })


def main():
    handlers = {
        "capabilities": ("00-capabilities", capabilities),
        "baseline": ("01-baseline", baseline),
        "timeouts": ("02-timeouts", timeouts),
        "retries": ("03-retries", retries),
        "retries-sidecar": ("03-retries-sidecar", retries_sidecar),
        "amplification": ("04-retry-amplification", amplification),
        "idempotency": ("05-idempotency", idempotency),
        "faults": ("06-fault-injection", faults),
        "overload": ("07-overload", overload),
        "overload-sidecar": ("07-overload-sidecar", overload_sidecar),
        "cascading": ("08-cascading-failure", cascading),
    }
    parser = argparse.ArgumentParser()
    parser.add_argument("experiment", choices=handlers)
    options = parser.parse_args()
    name, handler = handlers[options.experiment]
    reporter = Reporter(name)
    try:
        handler(reporter)
        reporter.record("Execution status", {"status": "completed"})
    except (ExperimentError, OSError, ValueError, subprocess.CalledProcessError) as error:
        reporter.record("Execution status", {"status": "failed", "error": str(error)})
        sys.exit(1)


if __name__ == "__main__":
    main()
