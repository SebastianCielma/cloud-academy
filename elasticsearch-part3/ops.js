const { Client } = require('@elastic/elasticsearch');
const client = new Client({ node: 'http://localhost:9200' });

const ALIAS_NAME = 'events-processed';
const INDEX_V1 = 'events-processed-v1';
const INDEX_V2 = 'events-processed-v2';

async function performOperations() {
  console.log("\n--- 1. Optimistic Concurrency Control (OCC) ---");
  const doc = await client.get({ index: ALIAS_NAME, id: 'EVT-9999' });
  const { _seq_no, _primary_term } = doc;
  console.log(`Fetched EVT-9999 (seq_no: ${_seq_no}, primary_term: ${_primary_term})`);

  try {
    await client.index({
      index: ALIAS_NAME,
      id: 'EVT-9999',
      if_seq_no: _seq_no - 1, 
      if_primary_term: _primary_term,
      document: { updated: "this will fail" }
    });
  } catch (err) {
    console.log(`OCC blocked the update (Status: ${err.meta.statusCode}). Stale version detected.[cite: 2]`);
  }

  console.log("\n--- 2. Mapping Migration & Reindexing ---");
  await client.indices.create({
    index: INDEX_V2,
    body: {
      mappings: {
        properties: {
          event_type: { type: 'text' }, 
          amount: { type: 'scaled_float', scaling_factor: 100 }
        }
      }
    }
  });
  console.log(`Created new index version: ${INDEX_V2}`);

  console.log("Reindexing data from v1 to v2...");
  await client.reindex({
    refresh: true,
    body: {
      source: { index: INDEX_V1 },
      dest: { index: INDEX_V2 }
    }
  }); 
  console.log("Reindexing completed.");

  console.log("\n--- 3. Atomic Alias Cutover (Zero Downtime) ---");
  await client.indices.updateAliases({
    body: {
      actions: [
        { remove: { index: INDEX_V1, alias: ALIAS_NAME } },
        { add: { index: INDEX_V2, alias: ALIAS_NAME } }
      ]
    }
  }); 
  console.log(`Alias '${ALIAS_NAME}' successfully switched to '${INDEX_V2}'. Search Service experienced no downtime.[cite: 2]`);

  console.log("\n--- 4. Rollback Procedure ---");
  console.log("If v2 mapping breaks the application, we instantly rollback by reversing the alias actions:");
  console.log("POST /_aliases");
  console.log(JSON.stringify({
    actions: [
      { remove: { index: INDEX_V2, alias: ALIAS_NAME } },
      { add: { index: INDEX_V1, alias: ALIAS_NAME } }
    ]
  }, null, 2));
}

performOperations().catch(console.error);