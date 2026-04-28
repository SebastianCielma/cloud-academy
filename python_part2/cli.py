import argparse
import logging
from src.parsers.json_parser import load_json_raw, parse_environment_state
from src.engine.drift_detector import DriftDetector
from src.engine.policies_engine import PolicyEngine
from src.reporters.reporter import Reporter

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

def main():
    parser = argparse.ArgumentParser(description="Drift & Policy Engine for Infrastructure")
    parser.add_argument("--desired", required=True, help="Path to desired state JSON")
    parser.add_argument("--actual", required=True, help="Path to actual state JSON")
    parser.add_argument("--policies", required=True, help="Path to policies JSON")
    parser.add_argument("--output", default="report.json", help="Path for output JSON report")
    
    args = parser.parse_args()

    desired_state = parse_environment_state(args.desired)
    actual_state = parse_environment_state(args.actual)
    policies_config = load_json_raw(args.policies)

    all_findings = []

    drift_detector = DriftDetector(desired_state, actual_state)
    all_findings.extend(drift_detector.detect())

    policy_engine = PolicyEngine(policies_config)
    all_findings.extend(policy_engine.evaluate_all(actual_state))

    reporter = Reporter(all_findings, actual_state)
    reporter.generate_console_report()
    reporter.export_to_json(args.output)

if __name__ == "__main__":
    main()