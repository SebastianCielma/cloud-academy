from enum import Enum
from pydantic import BaseModel, Field
from typing import Any, Optional

class Severity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

class FindingType(str, Enum):
    CHANGED_RESOURCE = "changed_resource"
    MISSING_RESOURCE = "missing_resource"
    UNEXPECTED_RESOURCE = "unexpected_resource"
    POLICY_VIOLATION = "policy_violation"

class Finding(BaseModel):
    finding_type: FindingType
    resource_type: str
    resource_name: str
    severity: Severity
    reason: str
    expected: Optional[Any] = Field(default=None)
    actual: Optional[Any] = Field(default=None)