import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
OUTPUT = ROOT / "docs" / "figures"

OUTPUT.mkdir(parents=True, exist_ok=True)

BLUE = "#285A87"
ORANGE = "#E59B38"
RED = "#B74747"

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "font.size": 11,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "axes.titleweight": "bold",
        "figure.facecolor": "white",
        "axes.facecolor": "white",
        "savefig.facecolor": "white",
    }
)


def load_report(name):
    matches = [p for p in REPORTS.glob("*.json") if p.stem.split("-", 1)[-1] == name]

    if len(matches) != 1:
        raise FileNotFoundError(
            f"Expected one report for {name}, found {len(matches)}"
        )

    with matches[0].open(encoding="utf-8") as file:
        data = json.load(file)

    if not data.get("assertions_passed"):
        raise ValueError(f"Experiment did not pass: {name}")

    return data


def save_chart(fig, filename):
    path = OUTPUT / filename
    fig.savefig(path, dpi=200, bbox_inches="tight")
    plt.close(fig)
    print(f"Generated: {path.relative_to(ROOT)}")


def plot_weighted_routing():
    scenarios = [
        ("90/10", "weighted-90-10"),
        ("75/25", "weighted-75-25"),
        ("50/50", "weighted-50-50"),
    ]

    labels = []
    v1_values = []
    v2_values = []

    for label, name in scenarios:
        data = load_report(name)
        total = data["requests"]

        labels.append(label)
        v1_values.append(100 * data["versions"].get("v1", 0) / total)
        v2_values.append(100 * data["versions"].get("v2", 0) / total)

    positions = range(len(labels))

    fig, ax = plt.subplots(figsize=(9, 5))

    ax.bar(
        positions,
        v1_values,
        width=0.55,
        color=BLUE,
        label="Payment v1",
    )

    ax.bar(
        positions,
        v2_values,
        bottom=v1_values,
        width=0.55,
        color=ORANGE,
        label="Payment v2",
    )

    for index, (v1, v2) in enumerate(zip(v1_values, v2_values)):
        ax.text(
            index,
            v1 / 2,
            f"{v1:.1f}%",
            ha="center",
            va="center",
            color="white",
            weight="bold",
        )

        ax.text(
            index,
            v1 + v2 / 2,
            f"{v2:.1f}%",
            ha="center",
            va="center",
            weight="bold",
        )

    ax.set_xticks(list(positions), labels)
    ax.set_ylim(0, 105)
    ax.set_ylabel("Traffic share (%)")
    ax.set_xlabel("Configured traffic split")
    ax.set_title("Weighted Routing - Observed Traffic Distribution")
    ax.legend(frameon=False)

    fig.tight_layout()
    save_chart(fig, "weighted-routing.png")


def plot_header_routing():
    scenarios = [
        ("Beta", "header-beta"),
        ("Default", "header-default"),
        ("Stable", "header-stable"),
    ]

    labels = []
    v1_values = []
    v2_values = []

    for label, name in scenarios:
        data = load_report(name)

        labels.append(label)
        v1_values.append(data["versions"].get("v1", 0))
        v2_values.append(data["versions"].get("v2", 0))

    positions = range(len(labels))

    fig, ax = plt.subplots(figsize=(9, 5))

    ax.bar(
        positions,
        v1_values,
        width=0.55,
        color=BLUE,
        label="Payment v1",
    )

    ax.bar(
        positions,
        v2_values,
        bottom=v1_values,
        width=0.55,
        color=ORANGE,
        label="Payment v2",
    )

    for index, (v1, v2) in enumerate(zip(v1_values, v2_values)):
        value = v1 if v1 else v2

        ax.text(
            index,
            value / 2,
            str(value),
            ha="center",
            va="center",
            color="white" if v1 else "black",
            weight="bold",
        )

    ax.set_xticks(list(positions), labels)
    ax.set_ylim(0, 175)
    ax.set_ylabel("Number of requests")
    ax.set_xlabel("Release channel")
    ax.set_title("Header-Based Routing - Requests by Version")
    ax.legend(frameon=False)

    fig.tight_layout()
    save_chart(fig, "header-routing.png")


def plot_canary_rollback():
    scenarios = [
        ("Before Regression", "pre-regression"),
        ("V2 Regression", "regression"),
        ("After Rollback", "rollback"),
    ]

    labels = []
    error_rates = []

    for label, name in scenarios:
        data = load_report(name)

        labels.append(label)
        error_rates.append(
            100 * data["error_count"] / data["requests"]
        )

    fig, ax = plt.subplots(figsize=(9, 5))

    bars = ax.bar(
        labels,
        error_rates,
        width=0.55,
        color=[BLUE, RED, BLUE],
    )

    for bar, rate in zip(bars, error_rates):
        ax.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 0.8,
            f"{rate:.1f}%",
            ha="center",
            va="bottom",
            weight="bold",
        )

    ax.set_ylim(0, max(35, max(error_rates) * 1.2))
    ax.set_ylabel("HTTP error rate (%)")
    ax.set_title("Canary Deployment - Error Rate Before and After Rollback")

    fig.tight_layout()
    save_chart(fig, "canary-rollback.png")


def main():
    plot_weighted_routing()
    plot_header_routing()
    plot_canary_rollback()


if __name__ == "__main__":
    main()
