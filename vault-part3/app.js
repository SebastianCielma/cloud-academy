const axios = require('axios');
const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');

const VAULT_ADDR = process.env.VAULT_ADDR || 'http://127.0.0.1:8200';
const ROLE_ID = process.env.VAULT_ROLE_ID;
const SECRET_ID = process.env.VAULT_SECRET_ID;

let vaultToken = null;
let dbPool = null;
let currentLeaseId = null;
let renewalInterval = null;

async function authenticateAppRole() {
    console.log("[INFO] Authenticating via AppRole...");
    const res = await axios.post(`${VAULT_ADDR}/v1/auth/approle/login`, {
        role_id: ROLE_ID,
        secret_id: SECRET_ID
    });
    vaultToken = res.data.auth.client_token;
    console.log("[SUCCESS] Authenticated with Vault.");
}

async function getDynamicCredentials() {
    console.log("[INFO] Requesting dynamic DB credentials from Vault...");
    const res = await axios.get(`${VAULT_ADDR}/v1/database/creds/dynamic-order-role`, {
        headers: { 'X-Vault-Token': vaultToken }
    });

    const { username, password } = res.data.data;
    currentLeaseId = res.data.lease_id;
    const leaseDuration = res.data.lease_duration; // e.g., 120s

    console.log(`[SUCCESS] Credentials acquired. Username: ${username}, Lease: ${currentLeaseId}, TTL: ${leaseDuration}s`);
    
    startLeaseRenewalLoop(currentLeaseId, leaseDuration);
    return { username, password };
}

function startLeaseRenewalLoop(leaseId, duration) {
    if (renewalInterval) clearInterval(renewalInterval);
    // Renew at 80% of lease duration to be safe
    const renewTimeMs = (duration * 0.8) * 1000;
    
    renewalInterval = setInterval(async () => {
        try {
            console.log(`[RENEWAL] Attempting to renew lease: ${leaseId}`);
            const res = await axios.put(`${VAULT_ADDR}/v1/sys/leases/renew`, { lease_id: leaseId }, {
                headers: { 'X-Vault-Token': vaultToken }
            });
            console.log(`[RENEWAL SUCCESS] Lease extended. New TTL: ${res.data.lease_duration}s`);
        } catch (err) {
            console.error(`[RENEWAL ERROR] Failed to renew lease: ${err.message}. Connection might drop soon!`);
            // Graceful degradation: If renewal fails (e.g., reached max_ttl), app should fetch new credentials and recreate pool.
        }
    }, renewTimeMs);
}

async function executeDatabaseOperations(credentials) {
    dbPool = new Pool({
        host: 'postgres',
        port: 5432,
        database: 'orders',
        user: credentials.username,
        password: credentials.password
    });

    try {
        console.log("[DB] Attempting authorized INSERT...");
        await dbPool.query(
            'INSERT INTO orders (id, customer_id, amount, created_at) VALUES ($1, $2, $3, NOW())',
            [uuidv4(), 'CUST-001', 150.50]
        );
        console.log("[DB SUCCESS] Data inserted successfully.");

        console.log("[DB] Attempting authorized SELECT...");
        const res = await dbPool.query('SELECT * FROM orders LIMIT 1');
        console.log(`[DB SUCCESS] Retrieved row: ${JSON.stringify(res.rows[0])}`);

        console.log("[DB] Attempting unauthorized operation (DROP TABLE)...");
        await dbPool.query('DROP TABLE orders');
    } catch (err) {
        if (err.code === '42501') {
            console.log(`[DB SECURITY BLOCK] Operation blocked as expected (Insufficient Privilege): ${err.message}`);
        } else {
            console.error(`[DB ERROR] Unexpected error: ${err.message}`);
        }
    }
}

async function main() {
    try {
        await authenticateAppRole();
        const creds = await getDynamicCredentials();
        await executeDatabaseOperations(creds);
        
        console.log("[INFO] Application running. Watching for lease expiration or manual revocation...");
    } catch (err) {
        console.error(`[FATAL] Application failed to start: ${err.message}`);
        process.exit(1);
    }
}

main();