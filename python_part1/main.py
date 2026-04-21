import argparse
import logging
import sys
from typing import List
import config
from io_handlers import CSVDataLoader, JSONExporter
from detector import CostAnomalyDetector, RollingMeanBaseline
from models import Anomaly

def setup_logging():
    logging.basicConfig(
        level=config.LOG_LEVEL,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S"
    )

def parse_args():
    parser = argparse.ArgumentParser(description="Cloud Cost Anomaly Detector")
    parser.add_argument('-input', required=True, help="Path to the input CSV file")
    return parser.parse_args()

def print_stdout_report(anomalies: List[Anomaly], total_records: int):
    sorted_anomalies = sorted(anomalies, key=lambda a: a.increase_percent, reverse=True)
    severity_counts = {"INFO": 0, "WARNING": 0, "CRITICAL": 0}

    print("\n" + "="*80)
    print(" DETECTED ANOMALIES REPORT")
    print("="*80)
    
    for anom in sorted_anomalies:
        severity_counts[anom.severity] += 1
        print(f"[{anom.severity}] {anom.date} | service={anom.service} | env={anom.environment} | "
              f"cost=${anom.actual_cost:.2f} | baseline=${anom.baseline_cost:.2f} | "
              f"increase={anom.increase_percent:.2f}% | reason: {anom.reason}")

    print("\n" + "="*80)
    print(" EXECUTION SUMMARY")
    print("="*80)
    print(f"- Total records analyzed: {total_records}")
    print(f"- Total anomalies detected: {len(anomalies)}")
    print("- Anomalies by severity:")
    for sev, count in severity_counts.items():
        print(f"  * {sev}: {count}")
        
    print("\n- Top 3 most suspicious anomalies:")
    for i, anom in enumerate(sorted_anomalies[:3]):
        print(f"  {i+1}. {anom.date} | {anom.service} ({anom.environment}) | +{anom.increase_percent:.2f}%")

def main():
    setup_logging()
    logger = logging.getLogger(__name__)
    args = parse_args()

    logger.info(f"Loading data from {args.input}...")
    try:
        loader = CSVDataLoader(args.input)
        records, total, invalid = loader.load()
    except Exception:
        sys.exit(1)

    if invalid > 0:
        logger.warning(f"Skipped {invalid} invalid or incomplete rows.")

    logger.info("Calculating baselines and detecting anomalies...")
    baseline_strategy = RollingMeanBaseline()
    detector = CostAnomalyDetector(baseline_strategy=baseline_strategy)
    anomalies = detector.detect(records)

    print_stdout_report(anomalies, total)
    
    JSONExporter.export(anomalies, config.OUTPUT_JSON_FILENAME)

if __name__ == "__main__":
    main()