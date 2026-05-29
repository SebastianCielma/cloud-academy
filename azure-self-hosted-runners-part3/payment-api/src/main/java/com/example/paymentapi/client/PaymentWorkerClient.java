package com.example.paymentapi.client;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

@Component
public class PaymentWorkerClient {

    private static final Logger log = LoggerFactory.getLogger(PaymentWorkerClient.class);

    private final WebClient webClient;

    public PaymentWorkerClient(
            @Value("${payment.worker.base-url:http://localhost:8090}") String workerBaseUrl
    ) {
        this.webClient = WebClient.builder()
                .baseUrl(workerBaseUrl)
                .build();
    }

    public void sendToWorker(String paymentId) {
        log.info("Calling payment-worker with paymentId={}", paymentId);

        webClient.post()
                .uri("/internal/worker/process")
                .bodyValue(new WorkerProcessRequest(paymentId))
                .retrieve()
                .toBodilessEntity()   // ignorujemy body
                .onErrorResume(ex -> {
                    log.error("Error calling worker: {}", ex.getMessage(), ex);
                    return Mono.empty();
                })
                .block(); // blokujemy, ale nie interesuje nas wynik
    }

    public static class WorkerProcessRequest {
        private String paymentId;

        public WorkerProcessRequest() {}
        public WorkerProcessRequest(String paymentId) {
            this.paymentId = paymentId;
        }

        public String getPaymentId() { return paymentId; }
        public void setPaymentId(String paymentId) { this.paymentId = paymentId; }
    }
}
