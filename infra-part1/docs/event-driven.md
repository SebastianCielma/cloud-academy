# Event-Driven Architecture & Notifications

As part of modernizing the platform's workloads, TerraOps supports Serverless integration and asynchronous Event-Driven Architectures (EDA). This decouples components and prevents the Academy Control API from hanging on synchronous integrations.

## 1. Event Publishing Flow

The Academy Control API has been enhanced to publish domain events directly into the cloud messaging backbone. 
When a user updates an assignment status (via `PATCH /assignments/{id}/status`), the following flow is executed asynchronously:
1. **Database Commit**: The assignment's new status is persisted in the SQLite database.
2. **Payload Construction**: A JSON payload containing the `event_type` (`AssignmentStatusChanged`), student, environment, and state diff (old vs. new status) is constructed.
3. **Dispatch**: 
    * In AWS environments, the payload is emitted directly to an **EventBridge Event Bus**.
    * In local/development environments, a fallback queue system is used (appending to a local JSONL file).

## 2. Notification Pipeline & Queue Integration

Once an event is emitted by the API, it enters the Notification Pipeline.
* **Routing**: The Event System (e.g., EventBridge) evaluates rules and routes relevant domain events into a dedicated queue (e.g., AWS SQS).
* **Asynchronous Queueing**: The queue temporarily holds the events. This guarantees delivery and allows downstream consumers to process them at their own pace without overwhelming the system.

## 3. Notification Retrieval & Debugging

To facilitate observability and debugging of the asynchronous flow, TerraOps provides a built-in CLI consumer.

* **Command**: `terraops notifications read --env <environment>`
* **Behavior**: This command connects to the queue integration, retrieves the latest unread notifications, and formats them into a standardized, human-readable JSON output (appending system metadata like `status: received`).
* **Purpose**: This tool is strictly for operational debugging. If engineers suspect an event was lost or a payload was malformed, they can use this command to inspect the queue's exact contents without navigating the cloud provider's console.