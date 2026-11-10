from pathlib import Path
import json
import re

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
OUTPUT = ROOT / "docs" / "figures"
OUTPUT.mkdir(parents=True, exist_ok=True)

plt.rcParams.update({
    "figure.figsize": (10, 5.5),
    "figure.dpi": 140,
    "savefig.dpi": 180,
    "font.size": 11,
    "axes.titlesize": 15,
    "axes.titleweight": "bold",
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": False,
})


def section(filename, heading):
    content = (REPORTS / filename).read_text()
    pattern = re.compile(
        r"(?m)^" + re.escape(heading) + r"\s*\n\s*\{"
    )
    match = pattern.search(content)

    if match is None:
        raise ValueError(f"Missing section: {filename} / {heading}")

    start = content.find("{", match.start())
    data, _ = json.JSONDecoder().raw_decode(content[start:])
    return data


def save(name):
    plt.tight_layout()
    plt.savefig(OUTPUT / name, bbox_inches="tight")
    plt.close()
    print(f"Created docs/figures/{name}")


def annotate(ax, bars, suffix="", precision=0):
    for bar in bars:
        value = bar.get_height()
        ax.annotate(
            f"{value:.{precision}f}{suffix}",
            (bar.get_x() + bar.get_width() / 2, value),
            xytext=(0, 5),
            textcoords="offset points",
            ha="center",
            va="bottom",
            fontsize=10,
        )


def baseline_and_retries():
    baseline = section(
        "01-baseline.log",
        "Inventory periodic 503 without retries",
    )
    without = section(
        "03-retries.log",
        "Ambient baseline intermittent inventory 503",
    )
    with_retry = section(
        "03-retries.log",
        "Ambient inventory with bounded retry",
    )

    names = ["Baseline", "No retries", "Bounded retries"]
    failures = [
        baseline["error_rate_percent"],
        without["error_rate_percent"],
        with_retry["error_rate_percent"],
    ]

    fig, ax = plt.subplots()
    bars = ax.bar(names, failures, width=0.55, color=["#C45B58", "#C45B58", "#448B70"])
    annotate(ax, bars, "%", 1)

    ax.set_title("Inventory Failures and Retry Effectiveness")
    ax.set_ylabel("Client error rate (%)")
    ax.set_ylim(0, 45)
    ax.set_axisbelow(True)
    ax.grid(axis="y", alpha=0.2)

    save("01-retry-effectiveness.png")

    fig, ax = plt.subplots()

    metrics = ["Mean latency", "p95 latency", "p99 latency"]
    original = [
        without["average_latency_ms"],
        without["p95_latency_ms"],
        without["p99_latency_ms"],
    ]
    retried = [
        with_retry["average_latency_ms"],
        with_retry["p95_latency_ms"],
        with_retry["p99_latency_ms"],
    ]

    x = np.arange(len(metrics))
    width = 0.34

    left = ax.bar(x - width / 2, original, width, label="No retries", color="#C45B58")
    right = ax.bar(x + width / 2, retried, width, label="Bounded retries", color="#448B70")

    annotate(ax, left, " ms", 1)
    annotate(ax, right, " ms", 1)

    ax.set_xticks(x, metrics)
    ax.set_ylabel("Latency (ms)")
    ax.set_title("Retry Reliability vs. Latency")
    ax.legend(frameon=False)
    ax.set_ylim(0, max(retried) * 1.25)
    ax.set_axisbelow(True)
    ax.grid(axis="y", alpha=0.2)

    save("02-retry-latency.png")


def retry_amplification():
    labels = [
        "No retries",
        "Application only",
        "Mesh only",
        "Application + mesh",
    ]

    headings = [
        "No retries",
        "Application retries only",
        "Mesh retries only",
        "Application and mesh retries",
    ]

    measured = [
        section("04-retry-amplification.log", heading)[
            "payment_requests_received"
        ]
        for heading in headings
    ]

    expected = [1, 3, 3, 9]
    x = np.arange(len(labels))
    width = 0.34

    fig, ax = plt.subplots(figsize=(11, 5.5))

    first = ax.bar(
        x - width / 2,
        expected,
        width,
        label="Expected",
        color="#A7B3C4",
    )
    second = ax.bar(
        x + width / 2,
        measured,
        width,
        label="Measured",
        color="#4779A8",
    )

    annotate(ax, first)
    annotate(ax, second)

    ax.set_xticks(x, labels)
    ax.set_ylabel("Payment requests per logical request")
    ax.set_title("Retry Amplification Across Two Layers")
    ax.set_ylim(0, max(expected + measured) + 2)
    ax.legend(frameon=False)
    ax.set_axisbelow(True)
    ax.grid(axis="y", alpha=0.2)

    save("03-retry-amplification.png")


def idempotency():
    without = section(
        "05-idempotency.log",
        "Without idempotency key",
    )
    with_key = section(
        "05-idempotency.log",
        "With idempotency key",
    )

    labels = ["Without key", "With key"]
    created = [
        without["payments_created_delta"],
        with_key["payments_created_delta"],
    ]
    replayed = [
        without["payments_replayed_delta"],
        with_key["payments_replayed_delta"],
    ]

    x = np.arange(2)

    fig, ax = plt.subplots()

    bottom = ax.bar(x, created, width=0.5, label="New payments", color="#4779A8")
    top = ax.bar(
        x,
        replayed,
        width=0.5,
        bottom=created,
        label="Replayed responses",
        color="#448B70",
    )

    for index, value in enumerate(created):
        ax.text(index, value / 2, str(value), ha="center", va="center", color="white", fontweight="bold")

    for index, value in enumerate(replayed):
        if value:
            ax.text(index, created[index] + value / 2, str(value), ha="center", va="center", color="white", fontweight="bold")

    ax.set_xticks(x, labels)
    ax.set_ylabel("Payment attempts")
    ax.set_title("Idempotency Prevents Duplicate Payments")
    ax.set_ylim(0, 2.7)
    ax.legend(frameon=False)

    save("04-idempotency.png")


def fault_injection():
    delay = section(
        "06-fault-injection.log",
        "Injected 3s delay",
    )
    full = section(
        "06-fault-injection.log",
        "Injected 503 abort",
    )
    partial = section(
        "06-fault-injection.log",
        "Injected 25 percent abort",
    )

    labels = ["3-second delay", "100% abort", "25% abort"]
    successful = [
        delay["success_count"],
        full["success_count"],
        partial["success_count"],
    ]
    failed = [
        delay["failure_count"],
        full["failure_count"],
        partial["failure_count"],
    ]

    x = np.arange(len(labels))

    fig, ax = plt.subplots()

    first = ax.bar(x, successful, width=0.55, label="HTTP 200", color="#448B70")
    second = ax.bar(
        x,
        failed,
        width=0.55,
        bottom=successful,
        label="HTTP 502",
        color="#C45B58",
    )

    for index in range(len(labels)):
        total = successful[index] + failed[index]
        ax.text(index, total + 1.5, f"{successful[index]} / {failed[index]}", ha="center")

    ax.set_xticks(x, labels)
    ax.set_ylabel("Client requests")
    ax.set_title("Fault Injection: Successes vs. Failures")
    ax.legend(frameon=False)
    ax.set_ylim(0, 95)
    ax.text(
        0.02,
        0.95,
        f"Injected delay: {delay['average_latency_ms']:.1f} ms",
        transform=ax.transAxes,
        va="top",
        fontsize=10,
    )

    save("05-fault-injection.png")


def circuit_breaking():
    ambient_before = section(
        "07-overload.log",
        "High concurrency without circuit breaking",
    )
    ambient_after = section(
        "07-overload.log",
        "High concurrency with waypoint circuit breaking",
    )
    sidecar_before = section(
        "07-overload-sidecar.log",
        "Sidecar without limits",
    )
    sidecar_after = section(
        "07-overload-sidecar.log",
        "Sidecar with limits",
    )

    samples = [
        ambient_before,
        ambient_after,
        sidecar_before,
        sidecar_after,
    ]
    labels = [
        "Ambient\nNo limits",
        "Ambient\nWith limits",
        "Sidecar\nNo limits",
        "Sidecar\nWith limits",
    ]

    success = [sample["success_count"] for sample in samples]
    failure = [sample["failure_count"] for sample in samples]

    x = np.arange(len(labels))

    fig, ax = plt.subplots()

    ax.bar(x, success, width=0.6, label="HTTP 200", color="#448B70")
    ax.bar(
        x,
        failure,
        width=0.6,
        bottom=success,
        label="HTTP 502",
        color="#C45B58",
    )

    for i in range(len(labels)):
        ax.text(i, 72, f"{failure[i]} rejected", ha="center", fontsize=9)

    ax.set_xticks(x, labels)
    ax.set_ylabel("Client requests")
    ax.set_title("Circuit Breaking Under High Concurrency")
    ax.set_ylim(0, 84)
    ax.legend(frameon=False)

    save("06-circuit-breaking.png")


def cascading_failure():
    baseline = section(
        "08-cascading-failure.log",
        "Slow payment cascading baseline",
    )
    timeout = section(
        "08-cascading-failure.log",
        "Slow payment with downstream timeout",
    )

    labels = ["Without timeout", "2-second timeout"]
    mean = [
        baseline["average_latency_ms"],
        timeout["average_latency_ms"],
    ]

    fig, ax = plt.subplots()

    bars = ax.bar(labels, mean, width=0.48, color=["#4779A8", "#C45B58"])
    annotate(ax, bars, " ms", 0)

    ax.set_ylabel("Mean client latency (ms)")
    ax.set_title("Slow Dependency: Waiting Time vs. Timeout")
    ax.set_ylim(0, 6000)
    ax.set_axisbelow(True)
    ax.grid(axis="y", alpha=0.2)

    ax.text(
        0,
        mean[0] / 2,
        "24/24 HTTP 200",
        ha="center",
        color="white",
        fontweight="bold",
    )
    ax.text(
        1,
        mean[1] / 2,
        "24/24 HTTP 502",
        ha="center",
        color="white",
        fontweight="bold",
    )

    save("07-cascading-failure.png")


def main():
    baseline_and_retries()
    retry_amplification()
    idempotency()
    fault_injection()
    circuit_breaking()
    cascading_failure()


if __name__ == "__main__":
    main()
