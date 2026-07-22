const { Client } = require('@elastic/elasticsearch');
const client = new Client({ node: 'http://localhost:9200' });
const INDEX_NAME = 'distributed_events';

async function runDiagnostics() {
  console.log("\n--- 1. Cluster Health ---");
  const health = await client.cluster.health();
  console.log(`Cluster Status: ${health.status.toUpperCase()}`);
  console.log(`Active Nodes: ${health.number_of_nodes}`);
  
  console.log("\n--- 2. Shard Allocation ---");
  const shards = await client.cat.shards({ index: INDEX_NAME, format: 'json' });
  console.table(shards.map(s => ({
    Shard: s.shard,
    Type: s.prirep === 'p' ? 'Primary' : 'Replica',
    State: s.state,
    Node: s.node,
    Docs: s.docs
  })));

  console.log("\n--- 3. Custom Routing Impact ---");
  const searchWithoutRouting = await client.search({
    index: INDEX_NAME,
    body: { query: { term: { customer_id: "C-5" } } }
  });
  console.log(`Search WITHOUT routing found ${searchWithoutRouting.hits.total.value} docs.`);

  const searchWithRouting = await client.search({
    index: INDEX_NAME,
    routing: "C-5",
    body: { query: { term: { customer_id: "C-5" } } }
  });
  console.log(`Search WITH routing found ${searchWithRouting.hits.total.value} docs.`);
}

runDiagnostics().catch(console.error);