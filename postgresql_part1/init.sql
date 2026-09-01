CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    tags JSONB
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    status VARCHAR(50) NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id),
    product_id INT NOT NULL REFERENCES products(id),
    quantity INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

INSERT INTO customers (email, created_at)
SELECT 'user' || i || '@example.com', NOW() - (random() * interval '365 days')
FROM generate_series(1, 100000) s(i);

INSERT INTO products (name, price, tags)
SELECT 'product_' || i, (random() * 1000)::numeric(10,2),
       CASE WHEN random() > 0.5 THEN '["electronics"]'::jsonb ELSE '["clothing"]'::jsonb END
FROM generate_series(1, 50000) s(i);

INSERT INTO orders (customer_id, status, total_amount, created_at)
SELECT
    (random() * 99999 + 1)::int,
    CASE
        WHEN random() < 0.95 THEN 'COMPLETED'
        WHEN random() < 0.08 THEN 'PROCESSING'
        ELSE 'NEW'
    END,
    (random() * 5000)::numeric(10,2),
    NOW() - (random() * interval '365 days')
FROM generate_series(1, 1000000) s(i);

INSERT INTO order_items (order_id, product_id, quantity, price)
SELECT
    (random() * 999999 + 1)::int,
    (random() * 49999 + 1)::int,
    (random() * 5 + 1)::int,
    (random() * 1000)::numeric(10,2)
FROM generate_series(1, 5000000) s(i);