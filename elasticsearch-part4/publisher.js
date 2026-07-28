const { Client } = require('@elastic/elasticsearch');
const fs = require('fs');

const ELASTIC_URL = process.env.ELASTIC_URL || 'https://localhost:9200';
const ELASTIC_USERNAME = process.env.ELASTIC_USERNAME || 'elastic';
const ELASTIC_PASSWORD = process.env.ELASTIC_PASSWORD;
const ELASTIC_CA_CERT_PATH = process.env.ELASTIC_CA_CERT;

let tlsCaCert;
if (ELASTIC_CA_CERT_PATH && fs.existsSync(ELASTIC_CA_CERT_PATH)) {
  tlsCaCert = fs.readFileSync(ELASTIC_CA_CERT_PATH);
}

const client = new Client({
  node: ELASTIC_URL,
  auth: {
    username: ELASTIC_USERNAME,
    password: ELASTIC_PASSWORD
  },
  tls: {
    ca: tlsCaCert,
    rejectUnauthorized: false
  }
});

const ALIAS_NAME = 'events-processed';
const INDEX_FAILED = 'events-failed';
const PIPELINE_NAME = 'enrich_events_pipeline';

async function publishAndTest() {
  console.log("\n--- 1. Idempotency & Duplicates: index vs create ---");
  
  const docBody = { raw_amount: "50", raw_date: "2026-07-22T12:00:00Z" };
  const deterministicId = "EVT-9999";

  try {
    await client.create({ index: ALIAS_NAME, id: deterministicId, document: docBody });
    console.log(`Document created with ID: ${deterministicId}`);
  } catch (err) {
    if (err.meta && err.meta.statusCode === 409) {
      console.log(`CREATE failed (409 Conflict): Document ${deterministicId} already exists. This prevents duplicates.`);
    } else {
      console.log(`Error during create: ${err.message}`);
    }
  }

  const indexResponse = await client.index({ index: ALIAS_NAME, id: deterministicId, document: docBody });
  console.log(`INDEX operation completed. Version bumped to: ${indexResponse._version}`);

  console.log("\n--- 2. Bulk Indexing with Pipeline and Failure Handling ---");
  const operations = [
    { index: { _index: ALIAS_NAME, pipeline: PIPELINE_NAME } },
    { event_type: "login", raw_amount: "200", raw_date: "2026-07-22T15:00:00Z", temp_field: "x" },
    { index: { _index: ALIAS_NAME, pipeline: PIPELINE_NAME } },
    { event_type: "purchase", raw_amount: "INVALID_NUMBER", raw_date: "BAD_DATE", temp_field: "x" }
  ];

  const bulkRes = await client.bulk({ refresh: true, operations });
  
  if (bulkRes.errors) {
    console.log("Bulk response contained errors (Handled gracefully by on_failure block).");
  }

  const processedDocs = await client.search({ index: ALIAS_NAME });
  console.log(`Successfully processed documents: ${processedDocs.hits.total.value}`);

  try {
    const failedDocs = await client.search({ index: INDEX_FAILED });
    console.log(`Failed documents isolated in '${INDEX_FAILED}': ${failedDocs.hits.total.value}`);
    if (failedDocs.hits.total.value > 0) {
      console.log("Example failed document source:");
      console.log(failedDocs.hits.hits[0]._source);
    }
  } catch (e) {
    console.log(`Index '${INDEX_FAILED}' does not exist yet (no pipeline setup or no failed docs).`);
  }
}

publishAndTest().catch(console.error);

setInterval(() => {}, 1000 * 60 * 60);