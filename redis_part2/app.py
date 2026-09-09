import redis
import psycopg2
import json
import time
import random

r = redis.Redis(host='localhost', port=6379, decode_responses=True)
db = psycopg2.connect("dbname=shop user=user password=password host=localhost port=5433")
db.autocommit = True

def init_db():
    cursor = db.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS products (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            price DECIMAL(10, 2)
        )
    """)
    cursor.execute("TRUNCATE TABLE products RESTART IDENTITY")
    cursor.execute("INSERT INTO products (id, name, price) VALUES (123, 'Super Laptop', 100.00)")
    cursor.close()

def get_product_advanced(product_id):
    cache_key = f"product:{product_id}"
    
    try:
        cached_data = r.get(cache_key)
        redis_available = True
    except redis.exceptions.ConnectionError:
        print(f"REDIS DOWN! Falling back to PostgreSQL for product {product_id}.")
        cached_data = None
        redis_available = False

    if cached_data:
        if cached_data == "NOT_FOUND":
            return None, "NEGATIVE CACHE HIT"
        return json.loads(cached_data), "HIT"

    cursor = db.cursor()
    cursor.execute("SELECT id, name, price FROM products WHERE id = %s", (product_id,))
    row = cursor.fetchone()

    if row:
        product_data = {"id": row[0], "name": row[1], "price": float(row[2])}
        if redis_available:
            ttl = 60 + random.randint(0, 15) 
            try:
                r.set(cache_key, json.dumps(product_data), ex=ttl)
            except redis.exceptions.ResponseError:
                pass 
        return product_data, "MISS"

    if redis_available:
        try:
            r.set(cache_key, "NOT_FOUND", ex=5)
        except redis.exceptions.ResponseError:
            pass
    return None, "NOT FOUND (DB MISS)"

def test_cache_invalidation():
    print("\nCACHE INVALIDATION & STALE DATA")
    get_product_advanced(123)
    
    cursor = db.cursor()
    cursor.execute("UPDATE products SET price = 120.00 WHERE id = 123")
    
    stale_product, _ = get_product_advanced(123)
    print(f"Stale Data from Redis (Price should be 120, but is): {stale_product['price']}")
    
    print("Applying invalidate-on-write")
    cursor.execute("UPDATE products SET price = 150.00 WHERE id = 123")
    try:
        r.delete("product:123")
    except redis.exceptions.ConnectionError:
        pass
        
    fresh_product, _ = get_product_advanced(123)
    print(f"Fresh Data from PostgreSQL/Redis (Price is): {fresh_product['price']}")

def test_cache_penetration():
    print("\nCACHE PENETRATION MITIGATION")
    print("Querying fake product ID 9999")
    
    _, status1 = get_product_advanced(9999)
    print(f"First request: {status1}")
    
    _, status2 = get_product_advanced(9999)
    print(f"Second request: {status2} (PostgreSQL protected by negative caching!)")

def test_memory_limits():
    print("\nMEMORY LIMIT AND EVICTION")
    try:
        try:
            r.config_set('maxmemory-policy', 'noeviction')
            print("Policy: noeviction. Filling memory with junk data")
            for i in range(100000):
                r.set(f"junk:{i}", "A" * 1024) 
        except redis.exceptions.ResponseError as e:
            print(f"OOM Reached! Redis refused write: {e}")
            
        print("Changing policy to allkeys-lru")
        r.config_set('maxmemory-policy', 'allkeys-lru')
        r.set("new_vital_key", "Success!")
        print(f"Write successful! new_vital_key: {r.get('new_vital_key')}")
    except redis.exceptions.ConnectionError:
        print("REDIS DOWN! Skipping memory limit and eviction test during failure.")

if __name__ == "__main__":
    init_db()
    try:
        r.flushall()
    except:
        pass
        
    test_cache_invalidation()
    test_cache_penetration()
    test_memory_limits()