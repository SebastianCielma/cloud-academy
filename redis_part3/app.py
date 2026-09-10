import redis
import time

primary = redis.Redis(host='localhost', port=6379, decode_responses=True)
replica = redis.Redis(host='localhost', port=6380, decode_responses=True)

def test_replication():
    print("--- REPLICATION TEST ---")
    primary.set("system_status", "Active")
    time.sleep(0.1) 
    print(f"Data read from Replica: {replica.get('system_status')}")
    print(f"Primary Role: {primary.info('replication')['role']}")
    print(f"Replica Role: {replica.info('replication')['role']}")

def test_lag():
    print("\n--- REPLICATION LAG TEST ---")
    pipe = primary.pipeline()
    for i in range(10000):
        pipe.set(f"lag:{i}", "test_data")
    pipe.execute()
    
    primary_offset = primary.info('replication')['master_repl_offset']
    replica_offset = replica.info('replication')['slave_repl_offset']
    lag = primary_offset - replica_offset
    
    print(f"Replication Lag (offset diff): {lag} bytes")
    print("Risk: Reading from a replica with high lag returns stale data!")

if __name__ == "__main__":
    test_replication()
    test_lag()