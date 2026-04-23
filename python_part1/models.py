from dataclasses import dataclass
from datetime import date

@dataclass
class CostRecord:
    date: date
    service: str
    environment: str
    cost: float

@dataclass
class Anomaly:
    date: str
    service: str
    environment: str
    actual_cost: float
    baseline_cost: float
    increase_percent: float
    severity: str
    reason: str
    
    def to_dict(self) -> dict:
        """Serializes the object to match the required JSON output format."""
        return {
            "date": self.date,
            "service": self.service,
            "environment": self.environment,
            "actual cost": self.actual_cost,
            "baseline cost": self.baseline_cost,
            "increase percent": self.increase_percent,
            "severity": self.severity,
            "reason": self.reason
        }