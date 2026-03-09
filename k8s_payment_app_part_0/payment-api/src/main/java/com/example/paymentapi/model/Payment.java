package com.example.paymentapi.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "payments")
public class Payment {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(nullable = false)
    private String customerId;

    @Column(nullable = false)
    private Long amountInCents;

    @Column(nullable = false, length = 3)
    private String currency;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PaymentStatus status;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    protected Payment() {
        // JPA
    }

    private Payment(String customerId, Long amountInCents, String currency) {
        this.customerId = customerId;
        this.amountInCents = amountInCents;
        this.currency = currency;
        this.status = PaymentStatus.PENDING;
    }

    public static Payment newPending(String customerId, long amountInCents, String currency) {
        return new Payment(customerId, amountInCents, currency);
    }

    @PrePersist
    void prePersist() {
        Instant now = Instant.now();
        this.createdAt = now;
        this.updatedAt = now;
    }

    @PreUpdate
    void preUpdate() {
        this.updatedAt = Instant.now();
    }

    public void markCompleted() {
        this.status = PaymentStatus.COMPLETED;
    }

    // GETTERY

    public String getId() {
        return id;
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

    public PaymentStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
