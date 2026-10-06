import pika
import json
import logging
import time

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

class SlowConsumer:
    def __init__(self):
        nodes = [pika.ConnectionParameters(host='localhost', port=5672)]
        self.connection = pika.BlockingConnection(nodes)
        self.channel = self.connection.channel()
        self.channel.queue_declare(
            queue='critical.payment.quorum', 
            durable=True, 
            arguments={'x-queue-type': 'quorum'}
        )
        self.channel.basic_qos(prefetch_count=50)

    def process_message(self, ch, method, properties, body):
        data = json.loads(body)
        logger.info(f"Processing task {data['task_id']} - simulating heavy load")
        time.sleep(3)
        ch.basic_ack(delivery_tag=method.delivery_tag)

    def start(self):
        logger.info("Slow consumer started. Watch 'Unacked' messages in UI.")
        self.channel.basic_consume(queue='critical.payment.quorum', on_message_callback=self.process_message)
        try:
            self.channel.start_consuming()
        except KeyboardInterrupt:
            self.connection.close()

if __name__ == '__main__':
    consumer = SlowConsumer()
    consumer.start()