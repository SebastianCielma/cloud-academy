package com.example.paymentworker.model;

public class PaymentResponse {

    private String id;
    private String status;

    public PaymentResponse() {
    }

    public PaymentResponse(String id, String status) {
        this.id = id;
        this.status = status;
    }

    public String getId() {
        return id;
    }

    public String getStatus() {
        return status;
    }

    public void setId(String id) {
        this.id = id;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}
