const axios = require('axios');

const VAULT_ADDR = process.env.VAULT_ADDR || 'http://127.0.0.1:8200';
const ROLE_ID = process.env.VAULT_ROLE_ID;
const SECRET_ID = process.env.VAULT_SECRET_ID;
const SECRET_PATH = '/v1/secret/data/applications/payment-service/database';

async function fetchConfigWithAppRole() {
    if (!ROLE_ID || !SECRET_ID) {
        console.error("[CRITICAL] Missing Role ID or Secret ID. Cannot authenticate.");
        process.exit(1);
    }

    try {
        console.log("--- Step 1: Authenticating via AppRole ---");
        const authResponse = await axios.post(`${VAULT_ADDR}/v1/auth/approle/login`, {
            role_id: ROLE_ID,
            secret_id: SECRET_ID
        });

        const vaultToken = authResponse.data.auth.client_token;
        const tokenTtl = authResponse.data.auth.lease_duration;
        console.log(`Authentication successful. Received temporary token valid for ${tokenTtl} seconds.`);

        console.log("\n--- Step 2: Fetching Payment Service Secrets ---");
        const secretResponse = await axios.get(`${VAULT_ADDR}${SECRET_PATH}`, {
            headers: { 'X-Vault-Token': vaultToken }
        });

        const dbConfig = secretResponse.data.data.data;
        console.log("Secret retrieved successfully!");
        console.log(`Host: ${dbConfig.host}:${dbConfig.port}`);
        console.log(`Username: ${dbConfig.username}`);
        console.log(`Password: ******** (length: ${dbConfig.password.length} characters)`);

        console.log("\n--- Step 3: Proving Least Privilege ---");
        try {
            console.log("Attempting to access Notification Service secret...");
            await axios.get(`${VAULT_ADDR}/v1/secret/data/applications/notification-service/email`, {
                headers: { 'X-Vault-Token': vaultToken }
            });
        } catch (err) {
            if (err.response && err.response.status === 403) {
                console.log("Access denied (403). The Principle of Least Privilege is working correctly!");
            }
        }

    } catch (error) {
        if (error.response) {
            console.error(`[ERROR] API request failed with status: ${error.response.status}`);
        } else {
            console.error(`[ERROR] Connection failed: ${error.message}`);
        }
        process.exit(1);
    }
}

fetchConfigWithAppRole();