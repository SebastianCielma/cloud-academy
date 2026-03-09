package com.example.paymentapi.model;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public class PaymentRequest {

    @NotBlank
    private String customerId;

    @NotNull
    @Min(1)
    private Long amountInCents;

    @NotBlank
    private String currency;

    public PaymentRequest() {
    }

    public String getCustomerId() {
        return customerId;
    }

    public Long getAmountInCents() {
        return amountInCents;
    }

    public String getCurrency() {
        return currency;
    }

    public void setCustomerId(String customerId) {
        this.customerId = customerId;
    }

    public void setAmountInCents(Long amountInCents) {
        this.amountInCents = amountInCents;
    }

    public void setCurrency(String currency) {
        this.currency = currency;
    }
}
