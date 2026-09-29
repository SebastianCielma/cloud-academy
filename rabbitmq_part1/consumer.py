import pika
import json
import logging
import os
import sys

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

class GenericWorker:
    def __init__(self, queue_name, routing_key):
        amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
        self.parameters = pika.URLParameters(amqp_url)
        self.queue_name = queue_name
        self.routing_key = routing_key
        self.connection = None
        self.channel = None

    def connect(self):
        try:
            self.connection = pika.BlockingConnection(self.parameters)
            self.channel = self.connection.channel()
            
            self.channel.exchange_declare(exchange='orders', exchange_type='topic')
            self.channel.queue_declare(queue=self.queue_name)
            self.channel.queue_bind(
                exchange='orders', 
                queue=self.queue_name, 
                routing_key=self.routing_key
            )
            
            self.channel.basic_qos(prefetch_count=1)
            
            logger.info(f"Connected. Queue: {self.queue_name}, Routing Key: {self.routing_key}")
        except pika.exceptions.AMQPConnectionError as e:
            logger.critical(f"Connection failed: {e}")
            sys.exit(1)

    def process_message(self, ch, method, properties, body):
        try:
            data = json.loads(body)
            event_type = data.get('event_type', 'unknown')
            order_id = data.get('order_id', 'unknown')
            
            logger.info(f"Processing event: {event_type}, Order: {order_id}")
            
            ch.basic_ack(delivery_tag=method.delivery_tag)
            logger.info(f"Successfully processed (ACK) order {order_id}.")
            
        except json.JSONDecodeError:
            logger.error("Invalid JSON. Rejecting permanently (NACK without requeue).")
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
            
        except Exception as e:
            logger.warning(f"Error: {e}. Returning to queue (NACK with requeue).")
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

    def start(self):
        self.connect()
        self.channel.basic_consume(
            queue=self.queue_name, 
            on_message_callback=self.process_message
        )
        
        try:
            logger.info("Waiting for messages...")
            self.channel.start_consuming()
        except KeyboardInterrupt:
            logger.info("Shutdown signal received.")
            if self.connection and not self.connection.is_closed:
                self.connection.close()

if __name__ == '__main__':
    queue = os.getenv('QUEUE_NAME', 'payment.queue')
    routing_key = os.getenv('ROUTING_KEY', 'payment.*')
    
    worker = GenericWorker(queue_name=queue, routing_key=routing_key)
    worker.start()