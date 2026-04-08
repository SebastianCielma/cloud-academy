const { Kafka } = require('kafkajs');

const instanceName = process.env.INSTANCE_NAME || 'Processor-Default';

const kafka = new Kafka({
  clientId: `processor-app-${instanceName}`, 
  brokers: ['localhost:9092']
});

const consumer = kafka.consumer({ groupId: 'processor-group' });

const run = async () => {
  await consumer.connect();
  console.log(`[${instanceName}] connected to Kafka in the "processor-group".`);

  await consumer.subscribe({ topic: 'system-events', fromBeginning: true });

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      const eventData = JSON.parse(message.value.toString());
      
      console.log(`[${instanceName}] | Partition: ${partition} | Event ID: ${eventData.event_id}`);
    },
  });
};

run().catch(console.error);