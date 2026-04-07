const { Kafka } = require('kafkajs');

const kafka = new Kafka({
  clientId: 'processor-app',
  brokers: ['localhost:9092']
});

const consumer = kafka.consumer({ groupId: 'processor-group' });

const run = async () => {
  await consumer.connect();

  await consumer.subscribe({ topic: 'system-events', fromBeginning: true });

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      const eventData = JSON.parse(message.value.toString());
      console.log(eventData);
    },
  });
};

run().catch(console.error);