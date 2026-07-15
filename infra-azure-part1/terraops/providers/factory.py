from terraops.providers.notifications import NotificationProvider
from terraops.providers.serverless import ServerlessProvider
from terraops.providers.terraform import TerraformProvider
from terraops.providers.vm import VMProvider


def terraform_provider() -> TerraformProvider:
    return TerraformProvider()


def vm_provider() -> VMProvider:
    return VMProvider()


def serverless_provider() -> ServerlessProvider:
    return ServerlessProvider()


def notification_provider() -> NotificationProvider:
    return NotificationProvider()

