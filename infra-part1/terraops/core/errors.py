class TerraOpsError(Exception):
    """Base error for TerraOps."""


class ConfigError(TerraOpsError):
    """Configuration loading or validation failed."""


class CommandExecutionError(TerraOpsError):
    """External command execution failed."""

