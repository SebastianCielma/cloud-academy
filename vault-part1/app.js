const axios = require('axios');

const VAULT_ADDR = process.env.VAULT_ADDR || 'http://127.0.0.1:8200';
const VAULT_TOKEN = process.env.VAULT_TOKEN;
const SECRET_PATH = '/v1/secret/data/applications/payment-service/database';

async function fetchConfigFromVault() {
    if (!VAULT_TOKEN) {
        console.error("[CRITICAL] Vault access token is missing. Application cannot start.");
        process.exit(1);
    }

    try {
        console.log(`Attempting to connect to Vault at: ${VAULT_ADDR}...`);
        
        const response = await axios.get(`${VAULT_ADDR}${SECRET_PATH}`, {
            headers: { 'X-Vault-Token': VAULT_TOKEN }
        });

        const dbConfig = response.data.data.data;
        
        console.log("Configuration successfully retrieved from Vault.");
        console.log("--- Database Connection Simulation ---");
        
        console.log(`Host: ${dbConfig.host}:${dbConfig.port}`);
        console.log(`Username: ${dbConfig.username}`);
        
        console.log(`Password: ******** (length: ${dbConfig.password.length} characters)`);

    } catch (error) {
        if (error.response && error.response.status === 404) {
            console.error("[ERROR] Secret not found at the specified Vault path. Ensure the KV engine is enabled and the secret exists.");
        } else if (error.code === 'ECONNREFUSED') {
            console.error("[ERROR] Connection refused. Verify that the Vault server is running and accessible.");
        } else if (error.response && error.response.status === 403) {
            console.error("[ERROR] Access denied (Forbidden). Check if the provided token has the required policies or if Vault is sealed.");
        } else {
            console.error(`[ERROR] An unexpected error occurred: ${error.message}`);
        }
        process.exit(1);
    }
}

fetchConfigFromVault();