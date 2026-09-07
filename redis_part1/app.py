import redis
import psycopg2
import json
import time

r = redis.Redis(host='localhost', port=6379, decode_responses=True)
db = psycopg2.connect("dbname=shop user=user password=password host=localhost port=5433")
db.autocommit = True

def init_db():
    print("Initializing PostgreSQL...")
    cursor = db.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS products (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            price DECIMAL(10, 2)
        )
    """)
    cursor.execute("TRUNCATE TABLE products RESTART IDENTITY")
    cursor.execute("INSERT INTO products (id, name, price) VALUES (123, 'Super Laptop', 4999.99)")
    cursor.close()

def get_product(product_id):
    start_time = time.time()
    cache_key = f"product:{product_id}"
    
    cached_data = r.get(cache_key)
    
    if cached_data:
        duration = time.time() - start_time
        return json.loads(cached_data), "HIT", duration
        
    cursor = db.cursor()
    cursor.execute("SELECT id, name, price FROM products WHERE id = %s", (product_id,))
    row = cursor.fetchone()
    
    if row:
        product_data = {"id": row[0], "name": row[1], "price": float(row[2])}
        r.set(cache_key, json.dumps(product_data), ex=2)
        duration = time.time() - start_time
        return product_data, "MISS", duration
        
    return None, "NOT FOUND", time.time() - start_time

def run_performance_test():
    print("\n--- PERFORMANCE TEST (500 requests) ---")
    hits = 0
    misses = 0
    total_time_redis = 0
    total_time_pg = 0
    
    for i in range(500):
        _, status, duration = get_product(123)
        
        if status == "HIT":
            hits += 1
            total_time_redis += duration
        elif status == "MISS":
            misses += 1
            total_time_pg += duration
            
        if i % 100 == 0 and i > 0:
            print(f"[{i}/500] Waiting 2.5s to force key TTL expiration (EXPIRE)...")
            time.sleep(2.5) 
            
    total_reqs = hits + misses
    hit_ratio = (hits / total_reqs) * 100
    
    print(f"Cache HITS: {hits}")
    print(f"Cache MISSES: {misses}")
    print(f"Cache Hit Ratio: {hit_ratio:.2f}%")
    if hits > 0:
        print(f"Average time from Redis (HIT): {total_time_redis/hits:.6f} s")
    if misses > 0:
        print(f"Average time from PostgreSQL (MISS): {total_time_pg/misses:.6f} s")

def test_redis_features():
    print("\n--- DATA STRUCTURES AND ATOMIC OPERATIONS TEST ---")
    
    r.set("test_key", "value")
    print(f"EXISTS before DEL: {r.exists('test_key')}")
    r.delete("test_key")
    print(f"EXISTS after DEL: {r.exists('test_key')}")
    
    r.hset("customer:42", mapping={"name": "John Doe", "tier": "VIP"})
    print("HASH customer:42 name:", r.hget("customer:42", "name"))
    
    r.set("product_views:123", 100)
    r.incr("product_views:123")
    r.incr("product_views:123")
    r.decr("product_views:123")
    print("INCR/DECR Counter:", r.get("product_views:123"))

def test_remaining_requirements():
    print("\n--- TTL STATES DEMONSTRATION ---")
    
    r.set("key_no_ttl", "persistent_value")
    
    r.set("key_with_ttl", "temporary_value", ex=10)
    
    r.set("key_expired", "old_value", ex=1)
    time.sleep(1.5) 
    
    print(f"TTL for key_no_ttl (Persistent): {r.ttl('key_no_ttl')}")
    print(f"TTL for key_with_ttl (Expiring): {r.ttl('key_with_ttl')}")
    print(f"TTL for key_expired (Expired): {r.ttl('key_expired')}")
    
    print("\n--- REMAINING DATA STRUCTURES ---")
    
    r.delete("history:user:123")
    r.lpush("history:user:123", "login", "view_item_123", "add_to_cart")
    print("LIST (Event History):", r.lrange("history:user:123", 0, -1))
    
    r.delete("tags:product:123")
    r.sadd("tags:product:123", "electronics", "laptop", "sale", "laptop") 
    print("SET (Unique Tags):", r.smembers("tags:product:123"))
    
    r.delete("ranking:products")
    r.zadd("ranking:products", {"laptop": 150, "mouse": 350, "keyboard": 90})
    print("SORTED SET (Ranking by score):", r.zrevrange("ranking:products", 0, -1, withscores=True))

if __name__ == "__main__":
    init_db()
    r.flushdb()
    
    run_performance_test()
    test_redis_features()
    test_remaining_requirements()