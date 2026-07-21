const { Client } = require('@elastic/elasticsearch');
const client = new Client({ node: 'http://localhost:9200' });
const INDEX_NAME = 'business_events';

async function runQueries() {
  console.log("\n--- 1. Get Document by _id ---");
  const getById = await client.get({ index: INDEX_NAME, id: 'uuid-1234' });
  console.log(getById._source);

  console.log("\n--- 2. Term Query (Exact Match) ---");
  const termRes = await client.search({
    index: INDEX_NAME,
    body: { query: { term: { "payload.order_id": "A-10001" } } }
  });
  console.log(`Found ${termRes.hits.total.value} documents.`);

  console.log("\n--- 3. Match Query (Full Text) ---");
  const matchRes = await client.search({
    index: INDEX_NAME,
    body: { query: { match: { "payload.notes": "express delivery" } } }
  });
  console.log(`Found ${matchRes.hits.total.value} documents.`);

  console.log("\n--- 4. Filter, Range & Sort ---");
  const filterRes = await client.search({
    index: INDEX_NAME,
    body: {
      query: {
        bool: {
          filter: [
            { term: { "event_type": "order_created" } },
            { range: { "payload.amount": { gte: 100.0, lte: 200.0 } } }
          ]
        }
      },
      sort: [ { "timestamp": { order: "desc" } } ]
    }
  });
  console.log(`Filtered and sorted hits: ${filterRes.hits.total.value}`);

  console.log("\n--- 5. Simple Aggregation ---");
  const aggRes = await client.search({
    index: INDEX_NAME,
    size: 0,
    body: {
      aggs: {
        total_revenue: { sum: { field: "payload.amount" } }
      }
    }
  });
  console.log(`Total Revenue Aggregation: ${aggRes.aggregations.total_revenue.value}`);

  console.log("\n--- 6. Update Document ---");
  await client.update({
    index: INDEX_NAME,
    id: 'uuid-1234',
    body: { doc: { payload: { amount: 250.00 } } }
  });
  console.log("Document updated.");

  console.log("\n--- 7. Observe Refresh Behavior ---");
  await client.index({
    index: INDEX_NAME,
    id: 'uuid-5678',
    body: { event_type: "order_cancelled", timestamp: new Date() }
  });
  
  const immediateSearch = await client.search({
    index: INDEX_NAME,
    body: { query: { term: { "event_type": "order_cancelled" } } }
  });
  console.log(`Immediate search found: ${immediateSearch.hits.total.value} (Expected 0 due to refresh interval)`);

  await client.indices.refresh({ index: INDEX_NAME });
  const afterRefreshSearch = await client.search({
    index: INDEX_NAME,
    body: { query: { term: { "event_type": "order_cancelled" } } }
  });
  console.log(`Search after forced refresh found: ${afterRefreshSearch.hits.total.value} (Expected 1)`);

  console.log("\n--- 8. Delete Document ---");
  await client.delete({ index: INDEX_NAME, id: 'uuid-5678' });
  console.log("Document deleted.");
}

runQueries().catch(console.error);