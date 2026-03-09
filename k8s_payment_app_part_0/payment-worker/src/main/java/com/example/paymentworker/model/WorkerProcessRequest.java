package com.example.paymentworker.model;

public class WorkerProcessRequest {

    private String paymentId;

    public WorkerProcessRequest() {
    }

    public WorkerProcessRequest(String paymentId) {
        this.paymentId = paymentId;
    }

    public String getPaymentId() {
        return paymentId;
    }

    public void setPaymentId(String paymentId) {
        this.paymentId = paymentId;
    }
}
