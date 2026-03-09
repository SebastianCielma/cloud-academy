package com.example.paymentapi.controller;

import com.example.paymentapi.model.PaymentRequest;
import com.example.paymentapi.model.PaymentResponse;
import com.example.paymentapi.service.PaymentService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/payments")
public class PaymentController {

    private final PaymentService service;

    public PaymentController(PaymentService service) {
        this.service = service;
    }

    // 3) endpoint INTERNAL – callback od workera (na razie tylko logowanie)
    // @PostMapping("/internal/{id}/callback")
    // public ResponseEntity<Void> workerCallback(@PathVariable("id") String id) {
    //     System.out.println("API: received callback from worker for payment " + id);
    //     return ResponseEntity.ok().build();
    // }
    @PostMapping("/internal/{id}/callback")
    public ResponseEntity<PaymentResponse> workerCallback(@PathVariable("id") String id) {
        System.out.println("API: received callback from worker for payment " + id);

        PaymentResponse response = service.markAsCompletedAndGet(id);
        if (response == null) {
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.ok(response);
    }



    // 1) klient woła ten endpoint
    @PostMapping
    public ResponseEntity<PaymentResponse> createAndProcess(
            @Valid @RequestBody PaymentRequest request
    ) {
        PaymentResponse response = service.createAndProcessPayment(request);
        return ResponseEntity.ok(response);
    }

    // podgląd statusu
    @GetMapping("/{id}")
    public ResponseEntity<PaymentResponse> get(@PathVariable("id") String id) {
        PaymentResponse response = service.getPayment(id);
        if (response == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(response);
    }

    // 2) endpoint INTERNAL – tylko dla workera
    @PostMapping("/internal/{id}/complete")
    public ResponseEntity<PaymentResponse> completeInternal(@PathVariable("id") String id) {
        PaymentResponse response = service.markAsCompletedAndGet(id);
        if (response == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(response);
    }
}
