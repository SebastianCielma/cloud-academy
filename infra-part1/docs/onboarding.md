# Platform Engineer Onboarding Guide

Welcome to the Platform Engineering team! This guide will help you set up your local environment and run your first deployment using TerraOps.

## 1. Local Setup
TerraOps requires Python 3 and Terraform to be installed locally.

1. **Clone the Repository**:
   `git clone <repository_url>`
2. **Setup Virtual Environment**:
   It is highly recommended to isolate the Python dependencies.
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

## 2. Your First Deployment
To test that your environment is working, run a staging deployment of the Academy Control API.

```bash
# Deploys the service to a Virtual Machine on AWS Staging
python -m terraops.main deploy --cloud aws --env staging --stack vm
```
*Tip: If you want to test the Serverless track, simply change `deploy` to `deploy-serverless` and `--stack vm` to `--service academy-control-api`.*

## 3. Development Workflow & Debugging
* **Logs**: Operational logs are structured and output directly to `stdout`. Watch for tags like `[CommandRunner]` or `[Terraform init]` to trace the execution context.
* **Testing Events**: You can test the Notification Pipeline locally by simulating a database update and reading the fallback JSONL queue:
  ```bash
  python -m terraops.main notifications read --cloud aws --env dev
  ```
* **Adding New Commands**: When adding new functionality, always place the CLI logic in `terraops/commands/` and the actual execution logic in `terraops/providers/`.