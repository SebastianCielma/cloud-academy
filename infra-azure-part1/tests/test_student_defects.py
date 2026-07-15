from types import SimpleNamespace

from terraops.commands import deploy
from terraops.core.config_loader import load_config
from terraops.terraform.tfvars import write_tfvars


def test_network_deploy_does_not_run_vm_provider(monkeypatch):
    vm_calls = []

    class FakeVMProvider:
        def deploy(self, environment):
            vm_calls.append(environment)
            return 0

    monkeypatch.setattr(deploy, "load_config", lambda cloud, env: {"cloud": cloud, "environment": env})
    monkeypatch.setattr(deploy, "write_tfvars", lambda config, stack: "generated.tfvars")
    monkeypatch.setattr(deploy, "apply_stack", lambda stack_path, tfvars_path: 0)
    monkeypatch.setattr(deploy, "VMProvider", FakeVMProvider)

    args = SimpleNamespace(cloud="aws", env="staging", stack="network")

    assert deploy.run(args) == 0
    assert vm_calls == []


def test_azure_network_tfvars_are_generated():
    config = load_config("azure", "staging")
    tfvars_path = write_tfvars(config, "network")

    tfvars = tfvars_path.read_text(encoding="utf-8")

    assert 'cloud = "azure"' in tfvars
    assert 'resource_group_name = "terraops-staging-rg"' in tfvars
    assert 'location = "westeurope"' in tfvars
    assert 'vnet_cidr = "10.31.0.0/16"' in tfvars
    assert 'subnet_cidr = "10.31.1.0/24"' in tfvars
