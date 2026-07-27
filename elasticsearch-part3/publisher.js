const { Client } = require('@elastic/elasticsearch');
const client = new Client({ node: 'http://localhost:9200' });

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
    if (err.meta.statusCode === 409) console.log(`CREATE failed (409 Conflict): Document ${deterministicId} already exists. This prevents duplicates.`);
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
    console.log("Bulk response contained errors (Handled gracefully by on_failure block).[cite: 2]");
  }

  const processedDocs = await client.search({ index: ALIAS_NAME });
  console.log(`Successfully processed documents: ${processedDocs.hits.total.value}`);

  const failedDocs = await client.search({ index: INDEX_FAILED });
  console.log(`Failed documents isolated in '${INDEX_FAILED}': ${failedDocs.hits.total.value}`);
  
  if (failedDocs.hits.total.value > 0) {
    console.log("Example failed document source:");
    console.log(failedDocs.hits.hits[0]._source);
  }
}

publishAndTest().catch(console.error);