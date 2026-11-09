import argparse
from pathlib import Path

from measure import measure, parse_headers, save_report, validate
from runtime import DEFAULT_CONTEXT, apply_route, port_forward


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--route", type=Path, required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--requests", type=int, default=1000)
    parser.add_argument("--workers", type=int, default=10)
    parser.add_argument("--header", action="append", default=[])
    parser.add_argument("--expected-v2", type=int)
    parser.add_argument("--expect-version", choices=["v1", "v2"])
    parser.add_argument("--min-error-rate", type=float)
    parser.add_argument("--max-error-rate", type=float)
    parser.add_argument("--context", default=DEFAULT_CONTEXT)
    args = parser.parse_args(argv)
    if args.requests < 1 or args.workers < 1:
        parser.error("Requests and workers must be positive")
    headers = parse_headers(args.header)
    apply_route(args.route, context=args.context)
    with port_forward("api-gateway", 18080, context=args.context) as base_url:
        records, summary = measure(f"{base_url}/order", args.requests, args.workers, 12, headers)
    summary.update({"scenario": args.scenario, "headers": headers, "workers": args.workers, "route_manifest": str(args.route)})
    passed = validate(summary, args.expected_v2, args.expect_version, args.min_error_rate, args.max_error_rate)
    save_report(args.out, records, summary)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
