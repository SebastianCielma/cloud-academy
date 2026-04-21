import csv
import json
import logging
from typing import List, Tuple
from datetime import datetime
from models import CostRecord, Anomaly

logger = logging.getLogger(__name__)

class CSVDataLoader:
    def __init__(self, filepath: str):
        self.filepath = filepath

    def load(self) -> Tuple[List[CostRecord], int, int]:
        records: List[CostRecord] = []
        invalid_rows = 0
        total_rows = 0

        try:
            with open(self.filepath, mode='r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row_num, row in enumerate(reader, start=2):
                    try:
                        cost_key = 'cost' if 'cost' in row else 'daily cost'
                        
                        record = CostRecord(
                            date=datetime.strptime(row['date'].strip(), "%Y-%m-%d").date(),
                            service=row['service'].strip(),
                            environment=row['environment'].strip(),
                            cost=float(row[cost_key].strip())
                        )
                        if record.cost < 0:
                            raise ValueError("Cost cannot be negative.")
                            
                        records.append(record)
                        total_rows += 1
                        
                    except (KeyError, ValueError, AttributeError) as e:
                        logger.debug(f"Row {row_num} invalid: {e}. Skipping.")
                        invalid_rows += 1
                        
        except FileNotFoundError:
            logger.error(f"File not found: {self.filepath}")
            raise
            
        return records, total_rows, invalid_rows

class JSONExporter:
    @staticmethod
    def export(anomalies: List[Anomaly], filepath: str) -> None:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump([a.to_dict() for a in anomalies], f, indent=4)
            logger.info(f"Anomalies strictly exported to {filepath}")
        except Exception as e:
            logger.error(f"Failed to export JSON: {e}")
            raise