CREATE DATABASE orders;
\c orders;

CREATE TABLE orders (
    id UUID PRIMARY KEY,
    customer_id VARCHAR(100) NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE USER legacy_user WITH PASSWORD 'initial-password';
GRANT SELECT, INSERT, UPDATE, DELETE ON orders TO legacy_user;