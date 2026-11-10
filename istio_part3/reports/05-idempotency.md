# Experiment 05: Payment Idempotency

## Requirement

Demonstrate the effect of repeated payment requests with and without an idempotency key.

## Objective

Verify that retries do not create duplicate payments when the same logical operation is submitted more than once.

## Environment and Configuration

| Parameter | Value |
|---|---|
| Kubernetes context | kind-istio-part3 |
| Application | Payment Service |
| Retry scenario | First response intentionally dropped |
| Test header | X-Lab-Drop-First-Response |
| Idempotency mechanism | Idempotency-Key |
| Evidence source | Payment Service counters |

## Test Procedure

1. Send a payment request with a simulated lost response and no idempotency key.
2. Record the number of payment attempts and created payments.
3. Repeat the scenario using an idempotency key.
4. Verify whether the second attempt creates a new payment or replays the original result.
5. Submit two different payloads using the same idempotency key.
6. Verify that the second payload is rejected.

Execution command:

    bash scripts/11-run-idempotency.sh

## Results

| Metric | Without key | With key |
|---|---:|---:|
| Payment attempts | 2 | 2 |
| Payments created | 2 | 1 |
| Responses replayed | 0 | 1 |
| Final HTTP status | 201 | 200 |

### Scenario A: Without an Idempotency Key

Two payment attempts created two separate payments.

The final response returned HTTP 201.

This demonstrates the risk of duplicate business operations after an uncertain response.

### Scenario B: With an Idempotency Key

Payment Service received two attempts but created only one payment.

The second attempt returned the previously stored result with replayed=true and HTTP 200.

The observed behavior prevented duplicate payment creation.

### Scenario C: Reusing a Key with a Different Payload

| Request | Status | Result |
|---|---|---|
| First payload | HTTP 201 | Payment approved |
| Different payload, same key | HTTP 409 | idempotency_key_conflict |

The implementation rejected an attempt to reuse an existing idempotency key for different payment data.

## Analysis

Retries operate at the HTTP transport level, while idempotency protects the meaning of a business operation.

Without an idempotency key, the application could not distinguish a repeated request from a new payment operation.

With an idempotency key, two HTTP attempts resulted in one payment creation and one replayed response.

Rejecting a different payload under the same key protects against accidental or incorrect reuse of that identifier.

This experiment validates the behavior of the test application. It does not demonstrate durability across process restarts or correctness with multiple replicas sharing persistent state.

## Conclusion

Idempotency is an essential safeguard when retrying operations that change business state.

The test confirmed that one idempotency key prevented duplicate payment creation despite two attempts.

The HTTP 409 conflict check additionally confirmed that the same key could not be reused with different payment data.

## Evidence

- reports/05-idempotency.log
- scripts/11-run-idempotency.sh
- tools/experiments.py
