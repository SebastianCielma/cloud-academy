package com.example.paymentworker.service;

import com.example.paymentworker.model.WorkerProcessRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class PaymentWorkerService {

    private static final Logger log = LoggerFactory.getLogger(PaymentWorkerService.class);

    private final long cpuLoadDurationMs;
    private final String paymentApiBaseUrl;
    private final RestTemplate restTemplate;

    public PaymentWorkerService(
            @Value("${worker.cpu-load-ms:300}") long cpuLoadDurationMs,
            @Value("${payment.api.base-url}") String paymentApiBaseUrl
    ) {
        this.cpuLoadDurationMs = cpuLoadDurationMs;
        this.paymentApiBaseUrl = paymentApiBaseUrl;
        this.restTemplate = new RestTemplate();
    }

    public void processPayment(WorkerProcessRequest request) {
        String paymentId = request.getPaymentId();
        log.info("Worker: received payment to process, id={}", paymentId);

        // 1) sztuczne obciążenie CPU
        simulateCpuWork(cpuLoadDurationMs);

        log.info("Worker: finished CPU work for payment {}", paymentId);

        // 2) callback do API – na razie tylko po to, żeby API zalogowało, że coś dostało
        String url = paymentApiBaseUrl + "/payments/internal/" + paymentId + "/callback";
        try {
            ResponseEntity<Void> response = restTemplate.postForEntity(url, null, Void.class);
            log.info("Worker: callback to API done. status={}", response.getStatusCode());
        } catch (Exception e) {
            log.error("Worker: error calling API callback for payment {}: {}", paymentId, e.getMessage(), e);
        }
    }

    private void simulateCpuWork(long durationMs) {
        long start = System.nanoTime();
        long durationNanos = durationMs * 1_000_000L;
        long iterations = 0;

        while (System.nanoTime() - start < durationNanos) {
            double x = Math.sqrt(iterations * 123.4567);
            x = Math.sin(x) * Math.cos(x) / (Math.tan(x + 1) + 1.000001);
            iterations++;
        }

        log.info("Simulated CPU work for ~{} ms, iterations={}", durationMs, iterations);
    }
}
