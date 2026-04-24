from typing import Dict, List, Any
from pydantic import BaseModel, Field

class IngressRule(BaseModel):
    port: int
    cidr: str

class BaseResource(BaseModel):
    name: str

class ComputeInstance(BaseResource):
    type: str
    tags: Dict[str, str] = Field(default_factory=dict)

class SecurityGroup(BaseResource):
    ingress: List[IngressRule] = Field(default_factory=list)

class Bucket(BaseResource):
    encryption: bool = Field(default=False)

class EnvironmentState(BaseModel):
    instances: List[ComputeInstance] = Field(default_factory=list)
    security_groups: List[SecurityGroup] = Field(default_factory=list)
    buckets: List[Bucket] = Field(default_factory=list)