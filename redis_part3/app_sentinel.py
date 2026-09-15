import time
from redis.sentinel import Sentinel
import redis.exceptions

sentinel = Sentinel([
    ('redis-sentinel-1', 26379),
    ('redis-sentinel-2', 26379),
    ('redis-sentinel-3', 26379)
], socket_timeout=2.0)

print("--- REDIS SENTINEL CLIENT ---")
master_ip, master_port = sentinel.discover_master('mymaster')
print(f"Current master is at {master_ip}:{master_port}")
print("\nStarting continuous requests to measure downtime during failover\n")

fail_start = None

for i in range(100):
    try:
        master = sentinel.master_for('mymaster', socket_timeout=0.5, decode_responses=True)
        
        master.set('failover_test', f'value_{i}')
        val = master.get('failover_test')
        
        if fail_start:
            downtime = time.time() - fail_start
            print(f"\n[OK] Reconnected! Sentinel promoted a new Primary. Downtime: {downtime:.2f} seconds.")
            fail_start = None
            
        print(f"[{i:02d}/100] Success: read '{val}' from master")
        time.sleep(1)
        
    except (redis.exceptions.ConnectionError, redis.exceptions.TimeoutError, redis.exceptions.ReadOnlyError):
        if not fail_start:
            fail_start = time.time()
            print(f"\n[!] Primary DOWN! Connection lost. Sentinel quorum is negotiating failover")
        print(f"[{i:02d}/100] Request failed waiting for Sentinel.")
        time.sleep(1)