const { Kafka, Partitioners } = require('kafkajs');
const { randomUUID } = require('crypto');

const kafka = new Kafka({
  clientId: 'processor-app',
  brokers: ['localhost:9092']
});

const consumer = kafka.consumer({ groupId: 'processor-group' });
const producer = kafka.producer({
  createPartitioner: Partitioners.LegacyPartitioner
});

const sendToDLQ = async (originalMessage, reason, originalId = 'UNKNOWN') => {
  const dlqEvent = {
    dlq_event_id: randomUUID(),
    original_event_id: originalId,
    failed_at: new Date().toISOString(),
    failure_reason: reason,
    raw_payload: originalMessage
  };

  await producer.send({
    topic: 'dead-letter-topic',
    messages: [
      { key: originalId, value: JSON.stringify(dlqEvent) }
    ]
  });
  console.log(` Event ${originalId} sent to DLQ. Reason: ${reason}`);
};

const run = async () => {
  await producer.connect();
  await consumer.connect();
  console.log('Processor connected to Kafka. Starting to consume');

  await consumer.subscribe({ topic: 'raw-data-topic', fromBeginning: true });

  await consumer.run({
    autoCommit: false, 
    eachMessage: async ({ topic, partition, message }) => {
      const rawValue = message.value.toString();
      const currentOffset = message.offset;
      let parsedEvent;
      let eventId = 'UNKNOWN';

      try {
        let isJsonValid = true;
        
        try {
          parsedEvent = JSON.parse(rawValue);
          eventId = parsedEvent.event_id || 'UNKNOWN';
        } catch (error) {
          isJsonValid = false;
          await sendToDLQ(rawValue, 'INVALID_JSON_FORMAT');
        }

        if (isJsonValid) {
          const amount = parsedEvent.payload?.amount;

          if (amount === undefined || typeof amount !== 'number') {
             await sendToDLQ(parsedEvent, 'INVALID_OR_MISSING_AMOUNT', eventId);
          } else {
            const processedEvent = {
              processed_event_id: randomUUID(),
              original_event_id: eventId,
              status: 'PROCESSED_SUCCESSFULLY',
              processed_at: new Date().toISOString(),
              enriched_data: {
                order_id: parsedEvent.payload.order_id,
                customer_id: parsedEvent.payload.customer_id,
                original_amount: amount,
                tax_added: parseFloat((amount * 0.23).toFixed(2)),
                total_amount: parseFloat((amount * 1.23).toFixed(2))
              }
            };

            await producer.send({
              topic: 'processed-data-topic',
              messages: [{ key: processedEvent.enriched_data.order_id, value: JSON.stringify(processedEvent) }]
            });
            console.log(`Event ${eventId} routed successfully.`);
          }
        }


        const nextOffset = (BigInt(currentOffset) + 1n).toString();
        
        await consumer.commitOffsets([
          { topic, partition, offset: nextOffset }
        ]);
        console.log(`Offset ${currentOffset} saved safely.\n`);

      } catch (error) {
        console.error(`Failed processing offset ${currentOffset}. Offset will NOT be committed.`);
        throw error;
      }
    },
  });
};

run().catch(console.error);

process.on('SIGINT', async () => {
  console.log('\nClosing Processor connections');
  await consumer.disconnect();
  await producer.disconnect();
  process.exit(0);
});