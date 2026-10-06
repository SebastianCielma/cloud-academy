import pika
import json
import logging
import time

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

class ClusterProducer:
    def __init__(self):
        self.connection = None
        self.channel = None
        self.connect()

    def connect(self):
        nodes = [
            pika.ConnectionParameters(host='localhost', port=5672, connection_attempts=3, retry_delay=2),
            pika.ConnectionParameters(host='localhost', port=5673, connection_attempts=3, retry_delay=2),
            pika.ConnectionParameters(host='localhost', port=5674, connection_attempts=3, retry_delay=2)
        ]
        
        self.connection = pika.BlockingConnection(nodes)
        self.channel = self.connection.channel()
        self.channel.confirm_delivery()
        
        self.channel.queue_declare(
            queue='critical.payment.quorum',
            durable=True,
            arguments={'x-queue-type': 'quorum'}
        )
        logger.info("Connected to cluster and verified quorum queue.")

    def publish_messages(self):
        for i in range(1, 1000):
            try:
                message = {"task_id": i, "status": "critical_payment"}
                self.channel.basic_publish(
                    exchange='',
                    routing_key='critical.payment.quorum',
                    body=json.dumps(message),
                    properties=pika.BasicProperties(delivery_mode=2)
                )
                logger.info(f"Published task {i}")
                time.sleep(0.5)
            except (pika.exceptions.ConnectionClosedByBroker, pika.exceptions.AMQPChannelError, pika.exceptions.AMQPConnectionError) as e:
                logger.error(f"Connection lost: {e}. Reconnecting")
                self.connect()

if __name__ == '__main__':
    producer = ClusterProducer()
    producer.publish_messages()