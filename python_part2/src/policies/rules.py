from typing import List
from src.models.findings import Finding, Severity
from src.models.resources import EnvironmentState
from src.policies.base import BasePolicy

class BucketEncryptionRequired(BasePolicy):
    def evaluate(self, actual_state: EnvironmentState) -> List[Finding]:
        findings = []
        for bucket in actual_state.buckets:
            if not bucket.encryption: 
                findings.append(self.create_finding(
                    resource_type="buckets", resource_name=bucket.name,
                    severity=Severity.HIGH, 
                    reason="Bucket encryption is disabled",
                    expected=True, actual=False
                ))
        return findings

class DenyPublicSsh(BasePolicy):
    def evaluate(self, actual_state: EnvironmentState) -> List[Finding]:
        findings = []
        for sg in actual_state.security_groups:
            for rule in sg.ingress:
                if rule.port == 22 and rule.cidr == "0.0.0.0/0": 
                    findings.append(self.create_finding(
                        resource_type="security_groups", resource_name=sg.name,
                        severity=Severity.CRITICAL, 
                        reason="Public SSH access detected on port 22 from 0.0.0.0/0",
                        expected="Restricted CIDR", actual="0.0.0.0/0"
                    ))
        return findings

class RequiredTags(BasePolicy):
    def evaluate(self, actual_state: EnvironmentState) -> List[Finding]:
        findings = []
        required_tags = self.rule_config.get("tags", [])
        for instance in actual_state.instances:
            actual_tags = instance.tags.keys()
            for req_tag in required_tags:
                if req_tag not in actual_tags: 
                    findings.append(self.create_finding(
                        resource_type="instances", resource_name=instance.name,
                        severity=Severity.MEDIUM, 
                        reason=f"Missing required tag: {req_tag}",
                        expected=req_tag, actual="Missing"
                    ))
        return findings

class AllowedInstanceTypesProd(BasePolicy):
    def evaluate(self, actual_state: EnvironmentState) -> List[Finding]:
        findings = []
        allowed_types = self.rule_config.get("allowed", [])
        for instance in actual_state.instances:
            if instance.tags.get("Environment") == "prod": 
                if instance.type not in allowed_types:
                    findings.append(self.create_finding(
                        resource_type="instances", resource_name=instance.name,
                        severity=Severity.HIGH,
                        reason="Unapproved instance type in production",
                        expected=allowed_types, actual=instance.type
                    ))
        return findings