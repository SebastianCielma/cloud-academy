from abc import ABC, abstractmethod
from typing import List, Dict, Any
from src.models.findings import Finding, FindingType, Severity
from src.models.resources import EnvironmentState

class BasePolicy(ABC):
    def __init__(self, rule_config: Dict[str, Any]):
        self.rule_config = rule_config

    @abstractmethod
    def evaluate(self, actual_state: EnvironmentState) -> List[Finding]:
        pass

    def create_finding(self, resource_type: str, resource_name: str, severity: Severity, reason: str, expected: Any = None, actual: Any = None) -> Finding:
        return Finding(
            finding_type=FindingType.POLICY_VIOLATION,
            resource_type=resource_type,
            resource_name=resource_name,
            severity=severity,
            reason=reason,
            expected=expected,
            actual=actual
        )