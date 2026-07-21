const { Client } = require('@elastic/elasticsearch');

const client = new Client({ node: 'http://localhost:9200' });
const INDEX_NAME = 'business_events';

async function setupIndex() {
  const indexExists = await client.indices.exists({ index: INDEX_NAME });
  
  if (!indexExists) {
    console.log(`Creating index: ${INDEX_NAME}...`);
    await client.indices.create({
      index: INDEX_NAME,
      body: {
        mappings: {
          properties: {
            event_id: { type: 'keyword' },
            event_type: { type: 'keyword' },
            source_service: { type: 'keyword' },
            timestamp: { type: 'date' },
            payload: {
              properties: {
                order_id: { type: 'keyword' },
                customer_id: { type: 'keyword' },
                amount: { type: 'scaled_float', scaling_factor: 100 },
                currency: { type: 'keyword' },
                notes: { 
                  type: 'text',
                  fields: {
                    keyword: { type: 'keyword' }
                  }
                }
              }
            }
          }
        }
      }
    });
    console.log('Index created with explicit mapping.');
  }
}

async function publishEvents() {
  await setupIndex();

  const doc = {
    event_id: "uuid-1234",
    event_type: "order_created",
    source_service: "publisher-service",
    timestamp: "2026-07-20T08:00:00Z",
    payload: {
      order_id: "A-10001",
      customer_id: "C-42",
      amount: 199.90,
      currency: "PLN",
      notes: "Express delivery requested by customer"
    }
  };

  const response = await client.index({
    index: INDEX_NAME,
    id: doc.event_id,
    body: doc
  });

  console.log('Document indexed:', response.result);
}

publishEvents().catch(console.error);