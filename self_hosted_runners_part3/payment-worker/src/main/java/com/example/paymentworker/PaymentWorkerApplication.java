package com.example.paymentworker;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class PaymentWorkerApplication {

    public static void main(String[] args) {
        SpringApplication.run(PaymentWorkerApplication.class, args);
    }
}
