# TerraOps: Platform Handover & Technical Documentation

## 1. Platform Architecture Overview
TerraOps is a core internal platform tool used by the organization for infrastructure provisioning, VM and serverless deployments, event-driven integrations, and notification workflows. The architecture is strictly modular to ensure extensibility and ease of maintenance.

### 1.1 Internal Components
The platform codebase is divided into clear logical domains:
* **`terraops/commands/`**: Contains the CLI entry points (e.g., deploy, deploy-serverless, validate, notifications, destroy). It handles the command execution flow directly from user input.
* **`terraops/providers/`**: Implements the provider model (Terraform, VM, Serverless, Notifications). It abstracts the underlying tools and APIs.
* **`terraops/core/`**: Houses central utilities such as the shared command runner, configuration loading flow, logging abstractions, and safety policies.
* **`terraops/terraform/`**: Manages dynamic `.tfvars` generation and integrates the platform configuration with the Terraform deployment lifecycle.

### 1.2 Academy Control API
The primary workload deployed by TerraOps is the Academy Control API. 
* **Purpose**: It serves as the core backend service managing student assignments and metrics. 
* **Runtime Architecture & Database**: Relies on a local SQLite database that requires strict database initialization procedures via migration scripts during the deployment lifecycle.
* **Endpoints & Readiness Checks**:
  * `GET /health`: Basic liveness probe.
  * `GET /ready`: Readiness check ensuring the database connection is established.
  * `GET /stats`: Application-level statistics.
  * `GET /metrics`: Infrastructure and application metrics.
  * `PATCH /assignments/{id}/status`: Triggers the event publishing flow for asynchronous processing.

---

## 2. Deployment Flows & Lifecycle
TerraOps orchestrates infrastructure and software via a strict deployment lifecycle. During any deployment, the configuration is loaded, validated, Terraform is executed, runtime configuration is injected, and services are started.

### 2.1 VM Deployment Flow
* **Trigger**: Executed via standard deploy commands targeting VM stacks.
* **Lifecycle**: Terraform provisions virtual networks, security groups, and virtual machines. 
* **Runtime Injection**: Cloud-init scripts inject configuration and handle database initialization before starting the Academy Control API service.

### 2.2 Serverless Deployment Flow
* **Trigger**: Executed via `terraops deploy-serverless`.
* **Lifecycle**: Provisions required serverless resources (e.g., Azure Functions), packages the application, and deploys the API.
* **Exposition**: Exposes public HTTP endpoints directly via the serverless runtime configuration.

### 2.3 Validation & Safety Mechanisms
To protect production environments and ensure deployment integrity, TerraOps enforces runtime validation and safety guardrails:
* **Fail-Fast Behavior**: The configuration loading flow fails immediately if mandatory parameters are missing.
* **Production Protection Mechanisms**: Hard stops are in place to block the destruction of production environments without explicit confirmation flags.

---

## 3. Event-Driven & Notification Architecture
TerraOps supports asynchronous communication models and event-driven workflows.

* **Event Publishing Flow**: When a user modifies an assignment via `PATCH /assignments/{id}/status`, the Academy Control API publishes an event (e.g., `AssignmentStatusChanged`) containing the payload.
* **Queue Integration**: Events move through the system by being routed from the API to the Event System, and finally into a message queue.
* **Notification Processing & Retrieval**: The `terraops notifications read` command connects to the queue/subscription to retrieve the latest notifications.
* **Debugging**: Developers can use the notification read command to display notification payloads and perform debugging of the event flow.

---

## 4. Troubleshooting Guide
Incident response and debugging require structured approaches. Below are common issues and recommended troubleshooting flows.

### 4.1 Common Failures & Root Causes
* **Configuration Issues**: Occurs when YAML files lack required blocks (e.g., missing database URLs). Check the output of the validation flow first.
* **Readiness Failures & Runtime Instability**: Typically caused by migration failures during database initialization. Check application startup logs and the `/ready` endpoint.
* **Deployment Failures**: Terraform execution errors (e.g., missing cloud capacities). Check the unified Command Runner logs.
* **Notification Failures**: Issues with queue integration or event publishing flow. Verify the event logs within the API and ensure the queue subscription is active.

### 4.2 Recommended Troubleshooting Flow
1. **Check Validation Logs**: Always review the fail-fast validation output in the CLI.
2. **Inspect Terraform Logs**: Locate the exact exit code and stderr provided by the core command execution logger.
3. **Verify Runtime Readiness**: Curl the `/ready` endpoint to determine if database initialization succeeded.
4. **Read the Queue**: Use `terraops notifications read` to verify if events are reaching the notification processing pipeline.

---

## 5. Onboarding Guide for Platform Engineers
Welcome to the TerraOps Platform Engineering team! This onboarding documentation will guide you through your initial setup.

### 5.1 Local Setup & Repository Structure
* Ensure you have Python 3, Terraform, and Docker installed locally.
* The repository is structured into `terraops/` (core platform code), `stacks/` (Terraform configurations), and `services/` (Academy Control API code).
* Create a local virtual environment and install dependencies before executing commands.

### 5.2 Common Commands & Development Workflow
* **Validation**: `python -m terraops.main validate --cloud <cloud> --env <env>`
* **VM Deployment**: `python -m terraops.main deploy --cloud <cloud> --env <env> --stack <stack>`
* **Serverless Deployment**: `python -m terraops.main deploy-serverless --cloud <cloud> --env <env> --service <service>`
* **Notification Debugging**: `python -m terraops.main notifications read --cloud <cloud> --env <env>`

### 5.3 Debugging Approach
When contributing to the platform, leverage the centralized logging system. All command executions produce standardized logs containing the execution context, executed commands, and results. Familiarize yourself with the provider model in `terraops/providers/` to understand how external tools are abstracted.
