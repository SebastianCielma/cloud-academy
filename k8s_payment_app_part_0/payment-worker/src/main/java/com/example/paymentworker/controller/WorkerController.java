package com.example.paymentworker.controller;

import com.example.paymentworker.model.WorkerProcessRequest;
import com.example.paymentworker.service.PaymentWorkerService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/internal/worker")
public class WorkerController {

    private final PaymentWorkerService service;

    public WorkerController(PaymentWorkerService service) {
        this.service = service;
    }

    @PostMapping("/process")
    public ResponseEntity<Void> process(@RequestBody WorkerProcessRequest request) {
        service.processPayment(request);
        return ResponseEntity.ok().build(); // zawsze 200, puste body
    }

}
