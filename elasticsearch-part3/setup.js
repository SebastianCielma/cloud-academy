const { Client } = require('@elastic/elasticsearch');
const client = new Client({ node: 'http://localhost:9200' });

const INDEX_V1 = 'events-processed-v1';
const INDEX_FAILED = 'events-failed';
const ALIAS_NAME = 'events-processed';
const PIPELINE_NAME = 'enrich_events_pipeline';

async function runSetup() {
  console.log("\n--- 1. Creating Failed and Processed Indices ---");
  
  const failedExists = await client.indices.exists({ index: INDEX_FAILED });
  if (!failedExists) {
    await client.indices.create({
      index: INDEX_FAILED,
      body: {
        mappings: {
          properties: {
            error_message: { type: 'text' },
            failed_processor: { type: 'keyword' },
            failure_timestamp: { type: 'date' }
          }
        }
      }
    });
  }

  const v1Exists = await client.indices.exists({ index: INDEX_V1 });
  if (!v1Exists) {
    await client.indices.create({
      index: INDEX_V1,
      body: {
        mappings: {
          properties: {
            event_type: { type: 'keyword' },
            amount: { type: 'scaled_float', scaling_factor: 100 },
            "@timestamp": { type: 'date' },
            customer_id: { type: 'keyword' },
            is_processed: { type: 'boolean' },
            tax_amount: { type: 'scaled_float', scaling_factor: 100 }
          }
        }
      }
    });
  }

  const aliasExists = await client.indices.existsAlias({ name: ALIAS_NAME });
  if (!aliasExists) {
    await client.indices.putAlias({ index: INDEX_V1, name: ALIAS_NAME });
  }
  console.log(`Alias '${ALIAS_NAME}' mapped to '${INDEX_V1}'.`);

  console.log("\n--- 2. Defining Ingest Pipeline with Failure Handling ---");
  const pipelineDefinition = {
    description: "Normalizes event data and routes failures to a dedicated index",
    processors: [
      { rename: { field: "raw_amount", target_field: "amount" } },
      { convert: { field: "amount", type: "float" } },
      { date: { field: "raw_date", target_field: "@timestamp", formats: ["yyyy-MM-dd'T'HH:mm:ssZ"] } },
      { set: { field: "is_processed", value: true } },
      { script: { source: "ctx.tax_amount = ctx.amount * 0.23" } }, 
      { remove: { field: "temp_field", ignore_missing: true } }
    ],
    on_failure: [
      { set: { field: "_index", value: INDEX_FAILED } },
      { set: { field: "error_message", value: "{{_ingest.on_failure_message}}" } }, 
      { set: { field: "failed_processor", value: "{{_ingest.on_failure_processor_type}}" } },
      { set: { field: "failure_timestamp", value: "{{_ingest.timestamp}}" } }
    ]
  };

  console.log("Simulating Pipeline processing...");
  const simResult = await client.ingest.simulate({
    body: {
      pipeline: pipelineDefinition,
      docs: [{ _source: { raw_amount: "100.50", raw_date: "2026-07-22T10:00:00Z", temp_field: "drop_me" } }]
    }
  });
  console.log("Simulation Result:", JSON.stringify(simResult.docs[0].doc._source, null, 2));

  await client.ingest.putPipeline({
    id: PIPELINE_NAME,
    body: pipelineDefinition
  });
  console.log(`Pipeline '${PIPELINE_NAME}' created successfully.`);
}

runSetup().catch(console.error);