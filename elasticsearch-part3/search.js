const { Client } = require('@elastic/elasticsearch');
const fs = require('fs');

const ELASTIC_URL = process.env.ELASTIC_URL || 'https://localhost:9200';
const ELASTIC_USERNAME = process.env.ELASTIC_USERNAME || 'elastic';
const ELASTIC_PASSWORD = process.env.ELASTIC_PASSWORD;
const ELASTIC_CA_CERT_PATH = process.env.ELASTIC_CA_CERT;

let tlsCaCert;
if (ELASTIC_CA_CERT_PATH && fs.existsSync(ELASTIC_CA_CERT_PATH)) {
  tlsCaCert = fs.readFileSync(ELASTIC_CA_CERT_PATH);
} else {
  console.warn(ELASTIC_CA_CERT_PATH);
}

const client = new Client({
  node: ELASTIC_URL,
  auth: {
    username: ELASTIC_USERNAME,
    password: ELASTIC_PASSWORD
  },
  tls: {
    ca: tlsCaCert,
    rejectUnauthorized: true 
  }
});

async function runSearch() {
  try {
    console.log(`Connecting to Elasticsearch at ${ELASTIC_URL}...`);
    
    const health = await client.cluster.health();
    console.log(`\n--- Cluster Health ---`);
    console.log(`Status: ${health.status.toUpperCase()}`);
    console.log(`Active Nodes: ${health.number_of_nodes}`);

    const ALIAS_NAME = 'events-processed';
    const indexExists = await client.indices.existsAlias({ name: ALIAS_NAME });
    
    if (indexExists) {
      const searchResult = await client.search({
        index: ALIAS_NAME,
        body: {
          query: { match_all: {} },
          size: 1
        }
      });
      
      console.log(`\n--- Search Results ---`);
      console.log(`Found ${searchResult.hits.total.value} documents in '${ALIAS_NAME}'.`);
      if (searchResult.hits.hits.length > 0) {
        console.log("Sample document source:");
        console.log(searchResult.hits.hits[0]._source);
      }
    } else {
      console.log(`\nIndex/Alias '${ALIAS_NAME}' not found. You might need to run the Publisher logic first in this new environment.`);
    }

  } catch (error) {
    console.error("\n[ERROR] Connection or Query failed:");
    console.error(error.message);
    if (error.meta && error.meta.body) {
      console.error(error.meta.body);
    }
  }
}

runSearch();

console.log("\nService initialized. Keeping process alive for Kubernetes readiness probes...");
setInterval(() => {}, 1000 * 60 * 60);