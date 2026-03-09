package com.example.paymentapi.service;

import com.example.paymentapi.client.PaymentWorkerClient;
import com.example.paymentapi.model.Payment;
import com.example.paymentapi.model.PaymentRequest;
import com.example.paymentapi.model.PaymentResponse;
import com.example.paymentapi.repository.PaymentRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class PaymentService {

    private static final Logger log = LoggerFactory.getLogger(PaymentService.class);

    private final PaymentRepository repository;
    private final PaymentWorkerClient workerClient;

    public PaymentService(PaymentRepository repository,
                          PaymentWorkerClient workerClient) {
        this.repository = repository;
        this.workerClient = workerClient;
    }

    // używana przez POST /payments
    public PaymentResponse createAndProcessPayment(PaymentRequest request) {
        // 1) Zapisujemy PENDING w DB
        Payment payment = Payment.newPending(
                request.getCustomerId(),
                request.getAmountInCents(),
                request.getCurrency()
        );
        Payment saved = repository.save(payment);
        log.info("Created payment {} with status {}", saved.getId(), saved.getStatus());

        // 2) Wysyłamy info do workera (fire-and-forget)
        try {
            workerClient.sendToWorker(saved.getId());
        } catch (Exception e) {
            log.error("Worker call failed for payment {}: {}", saved.getId(), e.getMessage(), e);
        }

        // 3) Na razie zwracamy PENDING
        return new PaymentResponse(saved.getId(), saved.getStatus().name());
    }

    // używana przez GET /payments/{id}
    public PaymentResponse getPayment(String id) {
        Optional<Payment> payment = repository.findById(id);
        return payment
                .map(p -> new PaymentResponse(p.getId(), p.getStatus().name()))
                .orElse(null);
    }

    // to zostaje na przyszłość – gdy worker będzie zmieniał status w DB
    public PaymentResponse markAsCompletedAndGet(String id) {
        return repository.findById(id)
                .map(p -> {
                    p.markCompleted();          // metoda na encji Payment – ustawia status COMPLETED
                    repository.save(p);
                    log.info("Marked payment {} as COMPLETED", p.getId());
                    return new PaymentResponse(p.getId(), p.getStatus().name());
                })
                .orElse(null);
    }

}
