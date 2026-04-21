import statistics
import logging
from typing import List, Dict, Tuple
from collections import defaultdict
from models import CostRecord, Anomaly
import config

logger = logging.getLogger(__name__)

class BaselineStrategy:
    """Interface for baseline calculation algorithms (Open/Closed Principle)."""
    def calculate(self, historical_costs: List[float]) -> float:
        raise NotImplementedError

class RollingMeanBaseline(BaselineStrategy):
    """Implementation using a moving average (rolling mean)."""
    def calculate(self, historical_costs: List[float]) -> float:
        if not historical_costs:
            return 0.0
        return statistics.mean(historical_costs)

class CostAnomalyDetector:
    def __init__(self, baseline_strategy: BaselineStrategy):
        # Dependency Injection
        self.baseline_strategy = baseline_strategy

    def _group_and_sort_records(self, records: List[CostRecord]) -> Dict[Tuple[str, str], List[CostRecord]]:
        grouped = defaultdict(list)
        for r in records:
            grouped[(r.service, r.environment)].append(r)
            
        for key in grouped:
            grouped[key].sort(key=lambda x: x.date)
            
        return grouped

    def _determine_severity(self, increase_percent: float) -> str:
        if increase_percent >= config.THRESHOLD_CRITICAL:
            return "CRITICAL"
        elif increase_percent >= config.THRESHOLD_WARNING:
            return "WARNING"
        return "INFO"

    def detect(self, records: List[CostRecord]) -> List[Anomaly]:
        anomalies: List[Anomaly] = []
        grouped_data = self._group_and_sort_records(records)
        
        for (service, env), group_records in grouped_data.items():
            for i in range(len(group_records)):
                current = group_records[i]
                
                if current.cost < config.MIN_ABSOLUTE_COST:
                    continue
                    
                history_slice = group_records[max(0, i - config.HISTORY_WINDOW_DAYS):i]
                
                if len(history_slice) < config.MIN_HISTORY_DAYS:
                    continue
                    
                baseline = self.baseline_strategy.calculate([r.cost for r in history_slice])
                
                if baseline <= 0:
                    continue
                    
                increase_percent = ((current.cost - baseline) / baseline) * 100.0
                
                if increase_percent >= config.THRESHOLD_INFO:
                    anomalies.append(
                        Anomaly(
                            date=current.date.strftime("%Y-%m-%d"),
                            service=service,
                            environment=env,
                            actual_cost=round(current.cost, 2),
                            baseline_cost=round(baseline, 2),
                            increase_percent=round(increase_percent, 2),
                            severity=self._determine_severity(increase_percent),
                            reason="cost exceeded anomaly threshold"
                        )
                    )
                    logger.debug(f"Anomaly found for {service} ({env}): +{increase_percent:.2f}%")
                    
        return anomalies