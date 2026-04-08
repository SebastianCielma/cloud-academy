const { Kafka, Partitioners } = require('kafkajs');
const { randomUUID } = require('crypto');

const kafka = new Kafka({
  clientId: 'publisher-app',
  brokers: ['localhost:9092']
});

const producer = kafka.producer({
  createPartitioner: Partitioners.LegacyPartitioner
});

const generateOrderId = () => `A-${Math.floor(Math.random() * 90000) + 10000}`;
const generateCustomerId = () => `C-${Math.floor(Math.random() * 100) + 1}`;

const generateEvent = () => {
  const event = {
    event_id: randomUUID(),
    event_type: "order_created",
    source_service: "publisher-service",
    timestamp: new Date().toISOString(),
    payload: {
      order_id: generateOrderId(),
      customer_id: generateCustomerId(),
      amount: parseFloat((Math.random() * 500).toFixed(2)),
      currency: "PLN"
    }
  };

  const chance = Math.random(); 

  if (chance < 0.15) {
    console.log(`\n Event without 'amount' field`);
    delete event.payload.amount;
  } else if (chance >= 0.15 && chance < 0.30) {
    console.log(`\n Event with incorrect 'amount' type`);
    event.payload.amount = "missing_amount_data"; 
  } else {
    console.log(`\n[VALID EVENT]`);
  }

  return event;
};

const run = async () => {
  await producer.connect();
  console.log('Publisher connected to Kafka');

  setInterval(async () => {
    const event = generateEvent();

    try {
      await producer.send({
        topic: 'raw-data-topic', 
        messages: [
          { 
            key: event.payload.order_id, 
            value: JSON.stringify(event) 
          },
        ],
      });
      console.log(`-> Sent to raw-data-topic | ID: ${event.event_id}`);
    } catch (error) {
      console.error('Error sending message:', error);
    }
  }, 3000); 
};

run().catch(console.error);

process.on('SIGINT', async () => {
  console.log('\nClosing Publisher connection');
  await producer.disconnect();
  process.exit(0);
});