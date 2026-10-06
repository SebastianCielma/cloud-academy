import pika
import json
import logging
import time

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

class ClusterConsumer:
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
        
        while True:
            try:
                self.connection = pika.BlockingConnection(nodes)
                self.channel = self.connection.channel()
                self.channel.basic_qos(prefetch_count=10)
                
                self.channel.queue_declare(
                    queue='critical.payment.quorum',
                    durable=True,
                    arguments={'x-queue-type': 'quorum'}
                )
                logger.info("Connected to cluster. Waiting for messages.")
                break
            except pika.exceptions.AMQPConnectionError:
                logger.error("Failed to connect to any node. Retrying in 5s...")
                time.sleep(5)

    def process_message(self, ch, method, properties, body):
        data = json.loads(body)
        logger.info(f"Processing task {data['task_id']}")
        time.sleep(0.1) 
        ch.basic_ack(delivery_tag=method.delivery_tag)

    def start(self):
        while True:
            try:
                self.channel.basic_consume(queue='critical.payment.quorum', on_message_callback=self.process_message)
                self.channel.start_consuming()
            except (pika.exceptions.ConnectionClosedByBroker, pika.exceptions.AMQPConnectionError):
                logger.error("Connection dropped. Reconnecting")
                self.connect()
            except KeyboardInterrupt:
                self.connection.close()
                break

if __name__ == '__main__':
    consumer = ClusterConsumer()
    consumer.start()