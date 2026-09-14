import redis


rc = redis.RedisCluster(host='localhost', port=7001, decode_responses=True)

def test_hash_tags_and_crossslot():
    print("--- CROSSSLOT & HASH TAGS ---")
    try:
        print("Attempting operation on cart:customer42 and cart-items:customer42 (different slots)")
        rc.mset({"cart:customer42": "active", "cart-items:customer42": "apple"})
    except redis.exceptions.RedisClusterException as e:
        print(f"ERROR: {e}")
        
    print("\nFixing using Hash Tags {customer42}...")
    rc.mset({"cart:{customer42}": "active", "cart-items:{customer42}": "apple"})
    print("SUCCESS! Both keys landed in the same slot on the same node.")

def test_moved_redirection():
    print("\n--- MOVED REDIRECTION ---")
    r_single = redis.Redis(host='localhost', port=7001, decode_responses=True)
    try:
        r_single.set("some_random_key_belonging_to_node_2", "value")
    except redis.exceptions.ResponseError as e:
        print(f"Received error from node: {e}")
        print("Explanation: MOVED means the client hit the wrong node. The cluster redirects it to the correct one.")

if __name__ == "__main__":
    test_hash_tags_and_crossslot()
    test_moved_redirection()