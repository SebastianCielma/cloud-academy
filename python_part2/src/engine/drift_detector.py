from typing import List, Any
from src.models.findings import Finding, FindingType, Severity
from src.models.resources import EnvironmentState, BaseResource

class DriftDetector:
    def __init__(self, desired_state: EnvironmentState, actual_state: EnvironmentState):
        self.desired = desired_state
        self.actual = actual_state
        self.findings: List[Finding] = []

    def detect(self) -> List[Finding]:
        self._compare_category("instances", self.desired.instances, self.actual.instances)
        self._compare_category("security_groups", self.desired.security_groups, self.actual.security_groups)
        self._compare_category("buckets", self.desired.buckets, self.actual.buckets)
        return self.findings

    def _compare_category(self, resource_type: str, desired_list: List[BaseResource], actual_list: List[BaseResource]):
        desired_map = {res.name: res for res in desired_list}
        actual_map = {res.name: res for res in actual_list}

        desired_names = set(desired_map.keys())
        actual_names = set(actual_map.keys())

        for name in desired_names - actual_names:
            self.findings.append(Finding(
                finding_type=FindingType.MISSING_RESOURCE,
                resource_type=resource_type,
                resource_name=name,
                severity=Severity.MEDIUM, 
                reason="Resource exists in desired state but is missing in actual state",
                expected="Exists",
                actual="Missing"
            ))

        for name in actual_names - desired_names:
            self.findings.append(Finding(
                finding_type=FindingType.UNEXPECTED_RESOURCE,
                resource_type=resource_type,
                resource_name=name,
                severity=Severity.LOW, 
                reason="Resource exists in actual state but should not exist",
                expected="Missing",
                actual="Exists"
            ))

        for name in desired_names & actual_names:
            expected_dict = desired_map[name].model_dump()
            actual_dict = actual_map[name].model_dump()

            if not self._is_equal(expected_dict, actual_dict):
                self.findings.append(Finding(
                    finding_type=FindingType.CHANGED_RESOURCE,
                    resource_type=resource_type,
                    resource_name=name,
                    severity=Severity.HIGH, 
                    reason="Configuration drift detected between desired and actual state",
                    expected=expected_dict,
                    actual=actual_dict
                ))

    def _is_equal(self, expected: Any, actual: Any) -> bool:
        if isinstance(expected, dict) and isinstance(actual, dict):
            if expected.keys() != actual.keys():
                return False
            return all(self._is_equal(expected[k], actual[k]) for k in expected)
        
        if isinstance(expected, list) and isinstance(actual, list):
            if len(expected) != len(actual):
                return False
            try:
                sorted_expected = sorted(expected, key=lambda x: str(x))
                sorted_actual = sorted(actual, key=lambda x: str(x))
                return all(self._is_equal(e, a) for e, a in zip(sorted_expected, sorted_actual))
            except TypeError:
                return expected == actual
                
        return expected == actual