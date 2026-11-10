# Experiment 04: Retry Amplification

## Requirement

Measure how application-level and service-mesh retries affect the number of requests received by Payment Service.

## Objective

Demonstrate whether retry policies at different layers multiply backend traffic during a persistent failure.

## Environment

| Parameter | Value |
|---|---|
| Kubernetes context | kind-istio-part3 |
| Namespace | istio-part3-sidecar |
| Mesh mode | Istio sidecar |
| Target | Payment Service |
| Failure simulation | HTTP 503 on every attempt |
| Application retries | 2 |
| Mesh retries | 2 |
| Mesh policy | VirtualService |
| Retry policy | manifests/sidecar/10-payment-retries.yaml |

Each scenario used a unique X-Request-ID. Payment Service counted the attempts associated with that identifier.

## Test Procedure

1. Deploy Order, Payment and Inventory with Istio sidecars.
2. Configure Payment Service to return HTTP 503.
3. Measure one request without retries.
4. Enable application retries and repeat the measurement.
5. Enable mesh retries and repeat the measurement.
6. Enable both retry layers and repeat the measurement.
7. Compare backend attempt counts against the theoretical model.

Execution command:

    bash scripts/10-run-retry-amplification.sh

## Expected Results

| Scenario | Expected attempts |
|---|---:|
| No retries | 1 |
| Application retries only | 3 |
| Mesh retries only | 3 |
| Application and mesh retries | 9 |

Each layer permits one initial attempt and two retries.

The maximum combined number of attempts is:

    (1 + 2) * (1 + 2) = 9

## Initial Execution

| Scenario | Observed attempts |
|---|---:|
| No retries | 1 |
| Application retries only | 3 |
| Mesh retries only | 1 |
| Application and mesh retries | 5 |

The initial measurements differed from the expected results.

The experiment applied or removed VirtualService resources immediately before sending requests. Configuration propagation to Envoy was identified as a possible explanation for the inconsistent observations.

A 5-second stabilization period was added before sending the test requests.

## Final Execution

| Scenario | Expected | Observed | Client status |
|---|---:|---:|---|
| No retries | 1 | 1 | HTTP 502 |
| Application retries only | 3 | 3 | HTTP 502 |
| Mesh retries only | 3 | 3 | HTTP 502 |
| Application and mesh retries | 9 | 9 | HTTP 502 |

All final measurements matched the expected attempt counts.

## Analysis

Application retries increased Payment requests from one to three.

Mesh retries independently increased Payment requests from one to three.

When both layers were enabled, each application attempt could trigger three mesh-level attempts. This produced nine requests to Payment Service for a single logical request.

All client requests ended with HTTP 502 because Payment Service deliberately returned HTTP 503 on every backend attempt.

The initial inconsistent results and the successful rerun after adding a stabilization period support the configuration propagation hypothesis. However, Envoy configuration was not inspected directly, so the exact cause of the first discrepancy remains unconfirmed.

## Conclusion

Retries at different layers can multiply backend requests rather than simply add together.

In this experiment, one logical client request produced nine Payment Service requests.

During persistent failures, this amplification can increase load on an already failing dependency.

Retry budgets should therefore be coordinated across application and mesh layers.

## Evidence

- reports/04-retry-amplification.log
- reports/04-retry-amplification-initial.log
- manifests/sidecar/10-payment-retries.yaml
- scripts/10-run-retry-amplification.sh
- tools/experiments.py
