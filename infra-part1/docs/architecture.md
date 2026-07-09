# TerraOps Platform Architecture

TerraOps is the core internal Platform Engineering tool responsible for infrastructure provisioning, deployment orchestration, and environment configuration. It supports both traditional VM-based workloads and modern Serverless event-driven architectures.

## 1. High-Level Architecture

The platform acts as a wrapper and orchestrator around standard tools (like Terraform, AWS Lambda, Docker) to enforce organizational standards, safety guardrails, and consistent observability.

### Directory Structure
* **`terraops/commands/`**: The entry points for the CLI. Each file (e.g., `deploy.py`, `validate.py`, `destroy.py`) parses user arguments and orchestrates the required providers.
* **`terraops/core/`**: The internal "brain" of the platform. Contains the configuration loader (`config_loader.py`), safety validations (`safety.py`), and the centralized execution engine (`command_runner.py`).
* **`terraops/providers/`**: The abstraction layer. Providers (e.g., `terraform.py`, `serverless.py`, `notifications.py`) translate TerraOps commands into actual system or API calls.

## 2. Command Execution Flow

To avoid technical debt and inconsistent error handling, all external processes are executed through a centralized `Command Runner` (`terraops/core/command_runner.py`).

1. **Invocation**: A command (e.g., `terraops deploy`) is triggered.
2. **Execution**: The relevant Provider calls `run_command()`.
3. **Observability**: The runner automatically logs the command context and captures standard output/error.
4. **Error Handling**: If a process fails (exit code != 0), the runner throws a unified `CommandExecutionError`, enabling fail-fast behavior and preventing silent pipeline failures.

## 3. Configuration Loading Flow

Configuration is strictly environment-based (`dev`, `staging`, `prod`) and loaded from `configs/{cloud}.{env}.yaml`. 
The `config_loader.py` enforces a strict schema validation. If required sections (`runtime`, `database`, `network`, `application`) are missing, the loader aborts the process immediately, preventing misconfigured infrastructure from being deployed.

---

## 4. Academy Control API (Target Workload)

The primary application deployed by TerraOps is the **Academy Control API**, built with FastAPI. It supports a dual-runtime architecture: it can run as a standalone process (VM) or as an AWS Lambda function via the Mangum adapter.

### Core Endpoints
* `GET /health` & `GET /ready`: Readiness probes for infrastructure health checks. Returns `503` if the SQLite database is unreachable.
* `GET /stats` & `GET /metrics`: Observability endpoints returning assignment statistics and Prometheus-compatible metrics.
* `PATCH /assignments/{id}/status`: The core business logic endpoint. Updates an assignment's status and automatically triggers the **Event Publishing Flow**, emitting an `AssignmentStatusChanged` event.