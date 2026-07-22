const { Client } = require('@elastic/elasticsearch');

const client = new Client({ node: 'http://localhost:9200' });
const INDEX_NAME = 'distributed_events';

async function setupIndex() {
  const indexExists = await client.indices.exists({ index: INDEX_NAME });
  
  if (indexExists) {
    await client.indices.delete({ index: INDEX_NAME });
  }

  console.log(`Creating index: ${INDEX_NAME}...`);
  await client.indices.create({
    index: INDEX_NAME,
    body: {
      settings: {
        number_of_shards: 3,
        number_of_replicas: 1
      },
      mappings: {
        properties: {
          event_type: { type: 'keyword' },
          customer_id: { type: 'keyword' },
          amount: { type: 'scaled_float', scaling_factor: 100 }
        }
      }
    }
  });
  console.log('Index created with 3 primary shards and 1 replica.');
}

async function publishEvents() {
  await setupIndex();

  const documents = Array.from({ length: 1000 }, (_, i) => ({
    event_type: i % 2 === 0 ? "order_created" : "order_updated",
    customer_id: `C-${(i % 10) + 1}`,
    amount: Math.round((Math.random() * 500) * 100) / 100
  }));

  console.log(`\n--- Performance Test: Individual vs Bulk Indexing ---`);
  
  const individualDocs = documents.slice(0, 500);
  const startIndividual = Date.now();
  
  for (const doc of individualDocs) {
    await client.index({
      index: INDEX_NAME,
      routing: doc.customer_id,
      body: doc
    });
  }
  const timeIndividual = Date.now() - startIndividual;
  console.log(`Individual indexing (500 docs) took: ${timeIndividual}ms`);

  const bulkDocs = documents.slice(500, 1000);
  const startBulk = Date.now();
  
  const operations = bulkDocs.flatMap(doc => [
    { index: { _index: INDEX_NAME, routing: doc.customer_id } },
    doc
  ]);
  
  const bulkResponse = await client.bulk({ refresh: true, operations });
  const timeBulk = Date.now() - startBulk;
  console.log(`Bulk indexing (500 docs) took: ${timeBulk}ms`);
  
  console.log(`\nConclusion: Bulk API was roughly ${(timeIndividual / timeBulk).toFixed(1)}x faster.`);

  if (bulkResponse.errors) {
    const erroredDocuments = [];
    bulkResponse.items.forEach((action, i) => {
      const operation = Object.keys(action)[0];
      if (action[operation].error) {
        erroredDocuments.push({
          status: action[operation].status,
          error: action[operation].error,
          operation: operations[i * 2],
          document: operations[i * 2 + 1]
        });
      }
    });
    console.log("Some documents failed to index:", erroredDocuments);
  } else {
    console.log("All documents bulk-indexed successfully without errors.");
  }
}

publishEvents().catch(console.error);