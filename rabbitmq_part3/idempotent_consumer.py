import pika
import json
import logging
import os
import sys

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

class IdempotentWorker:
    def __init__(self):
        amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
        self.connection = pika.BlockingConnection(pika.URLParameters(amqp_url))
        self.channel = self.connection.channel()
        
        self.channel.exchange_declare(exchange='secure_orders', exchange_type='topic', durable=True)
        self.channel.queue_declare(queue='secure.payment.queue', durable=True)
        self.channel.queue_bind(exchange='secure_orders', queue='secure.payment.queue', routing_key='payment.*')
        
        self.channel.basic_qos(prefetch_count=1)
        
        self.processed_events = set()
        self.simulated_crash_done = False

    def process_message(self, ch, method, properties, body):
        data = json.loads(body)
        event_id = data.get('event_id')
        
        logger.info(f"Received message. Redelivered flag: {method.redelivered}")

        if event_id in self.processed_events:
            logger.warning(f"IDEMPOTENCY TRIGGERED: Event {event_id} already processed. Sending ACK and skipping.")
            ch.basic_ack(delivery_tag=method.delivery_tag)
            return

        logger.info(f"Charging customer $150.00 for event {event_id}...")
        self.processed_events.add(event_id)

        if not self.simulated_crash_done:
            self.simulated_crash_done = True
            logger.critical("CRASH SIMULATION: System died before ACK. Connection dropped.")
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
            return

        ch.basic_ack(delivery_tag=method.delivery_tag)
        logger.info(f"Successfully processed and ACKed event {event_id}.")

    def start(self):
        self.channel.basic_consume(queue='secure.payment.queue', on_message_callback=self.process_message)
        try:
            logger.info("Idempotent worker waiting for messages")
            self.channel.start_consuming()
        except KeyboardInterrupt:
            if self.connection and not self.connection.is_closed:
                self.connection.close()

if __name__ == '__main__':
    worker = IdempotentWorker()
    worker.start()