from typing import List, Dict, Type
import logging
from src.models.findings import Finding
from src.models.resources import EnvironmentState
from src.policies.base import BasePolicy
from src.policies.rules import (
    BucketEncryptionRequired, 
    DenyPublicSsh, 
    RequiredTags, 
    AllowedInstanceTypesProd
)

logger = logging.getLogger(__name__)

class PolicyEngine:
    POLICY_REGISTRY: Dict[str, Type[BasePolicy]] = {
        "bucket_encryption_required": BucketEncryptionRequired,
        "deny_public_ssh": DenyPublicSsh,
        "required_tags": RequiredTags,
        "allowed_instance_types_prod": AllowedInstanceTypesProd
    }

    def __init__(self, policies_config: Dict):
        self.policies_config = policies_config

    def evaluate_all(self, actual_state: EnvironmentState) -> List[Finding]:
        findings = []
        rules = self.policies_config.get("rules", [])
        
        for rule_config in rules:
            rule_type = rule_config.get("type")
            policy_class = self.POLICY_REGISTRY.get(rule_type)
            
            if policy_class:
                policy_instance = policy_class(rule_config)
                findings.extend(policy_instance.evaluate(actual_state))
            else:
                logger.warning(f"Unsupported policy type detected and ignored: {rule_type}")
                
        return findings