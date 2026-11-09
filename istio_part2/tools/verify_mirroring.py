import argparse
import json
import time
from pathlib import Path

from measure import measure, save_report, validate
from runtime import DEFAULT_CONTEXT, apply_route, get_stats, port_forward


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--route", type=Path, required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--requests", type=int, default=120)
    parser.add_argument("--context", default=DEFAULT_CONTEXT)
    args = parser.parse_args(argv)
    if args.requests < 1:
        parser.error("Requests must be positive")
    apply_route(args.route, context=args.context)
    with port_forward("payment-service-v2", 18081, context=args.context) as v2_url:
        before = get_stats(v2_url)
        with port_forward("api-gateway", 18080, context=args.context) as gateway_url:
            records, summary = measure(f"{gateway_url}/order", args.requests, 6, 12, {})
        time.sleep(3)
        after = get_stats(v2_url)
    delta = after["payment_requests"] - before["payment_requests"]
    passed = validate(summary, expected_version="v1", max_errors=0)
    if delta < int(args.requests * 0.75):
        passed = False
        summary["assertions_passed"] = False
        summary["assertion_failures"].append("Mirrored requests did not reach at least 75% of the expected count")
    summary.update({
        "scenario": "optional-request-mirroring",
        "workers": 6,
        "headers": {},
        "v2_payment_requests_before": before["payment_requests"],
        "v2_payment_requests_after": after["payment_requests"],
        "v2_mirrored_requests_observed": delta,
        "mirror_observed_percentage": round(delta / args.requests * 100, 2),
    })
    save_report(args.out, records, summary)
    print(f"Mirrored v2 requests recorded: {delta}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
