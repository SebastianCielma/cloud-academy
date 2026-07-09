# Deployments, Safety, and Guardrails

TerraOps enforces a strict, validated deployment lifecycle. Whether deploying to a traditional Virtual Machine or a Serverless environment, the platform ensures that the infrastructure code is safe, predictable, and fully observable.

## 1. Deployment Lifecycle

The platform abstracts the complexity of Terraform and application packaging into a unified CLI command (e.g., `terraops deploy` or `terraops deploy-serverless`).

### VM Deployment Flow
1. **Validation Phase**: The `safety.py` module verifies local dependencies (Terraform, Docker, Python) and the presence of mandatory files (`main.tf`, `variables.tf`).
2. **Config Generation**: The environment-specific YAML configuration is loaded and dynamically translated into a `.tfvars` file.
3. **Execution**: The `TerraformProvider` executes `terraform init` followed by `terraform apply --auto-approve` via the centralized `Command Runner`.

### Serverless Deployment Flow
1. **Packaging**: The platform reads the `Academy Control API` source code and compiles it into a deployment package (ZIP archive).
2. **Infrastructure Provisioning**: The `ServerlessProvider` applies the Serverless Terraform stack, which provisions the API Gateway and AWS Lambda resources.
3. **Runtime Adaptation**: The deployed API utilizes the `Mangum` adapter to seamlessly translate API Gateway events into FastAPI requests, requiring no code changes from developers.

---

## 2. Validation & Safety Mechanism

Historically, infrastructure deployments suffered from silent failures and missing configurations. TerraOps implements a "fail-fast" philosophy to protect production environments.

### Pre-Flight Validations
Before any Terraform command runs, the platform executes a suite of safety checks:
* **Dependency Check**: Ensures required CLI tools (`terraform`, `python3`) are installed on the runner.
* **Variable Integrity**: Scans the loaded YAML configuration to ensure critical variables (e.g., `database_url`, `app_port`, `environment`) are present.
* **File Integrity**: Ensures the target Terraform stack contains the necessary `.tf` files.

### Production Protection
The most critical safety mechanism involves the destruction of resources. 
* Executing `terraops destroy` against the `prod` environment is **hard-blocked** by default.
* To perform a destructive action on production, an engineer must explicitly bypass the safety check by passing the `--confirm-prod-destroy` flag. 

### Fail-Fast Behavior
If any validation fails (missing configuration sections, missing dependencies, or a rejected production destroy attempt), the system immediately aborts the deployment pipeline with a non-zero exit code (SystemExit). This prevents partial, corrupted deployments and forces the operator to address the root cause upfront.