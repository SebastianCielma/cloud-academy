const { Kafka, Partitioners } = require('kafkajs');
const { randomUUID } = require('crypto');

const kafka = new Kafka({
  clientId: 'publisher-app',
  brokers: ['localhost:9092']
});

const producer = kafka.producer({
  createPartitioner: Partitioners.LegacyPartitioner
});

const run = async () => {
  await producer.connect();
  console.log('Publisher connected');

  const event = {
    event_id: randomUUID(), 
    event_type: "order_created", 
    source_service: "publisher-service", 
    timestamp: new Date().toISOString(), 
    payload: { 
      order_id: "A-10001",
      customer_id: "C-42",
      amount: 199.90,
      currency: "PLN"
    }
  };

  await producer.send({
    topic: 'system-events', 
    messages: [
      {
        key: event.payload.order_id,
        value: JSON.stringify(event) }, 
    ],
  });

  console.log('Send event :', event);
  await producer.disconnect();
};

run().catch(console.error);