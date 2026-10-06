import pika
import json
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

class MassFlowProducer:
    def __init__(self):
        nodes = [pika.ConnectionParameters(host='localhost', port=5672)]
        self.connection = pika.BlockingConnection(nodes)
        self.channel = self.connection.channel()
        self.channel.queue_declare(
            queue='critical.payment.quorum', 
            durable=True, 
            arguments={'x-queue-type': 'quorum'}
        )

    def blast_messages(self):
        logger.info("Starting massive message influx for Flow Control test")
        for i in range(1, 50001):
            message = {"task_id": i, "payload": "X" * 1024}
            self.channel.basic_publish(
                exchange='',
                routing_key='critical.payment.quorum',
                body=json.dumps(message),
                properties=pika.BasicProperties(delivery_mode=2)
            )
            if i % 5000 == 0:
                logger.info(f"Published {i} messages")
        self.connection.close()

if __name__ == '__main__':
    producer = MassFlowProducer()
    producer.blast_messages()