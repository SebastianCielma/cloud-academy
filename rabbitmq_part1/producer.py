import pika
import json
import logging
import os
import sys
import uuid
from datetime import datetime, timezone

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

class OrderAPIProducer:
    def __init__(self):
        amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
        self.parameters = pika.URLParameters(amqp_url)
        self.connection = None
        self.channel = None

    def connect(self):
        try:
            self.connection = pika.BlockingConnection(self.parameters)
            self.channel = self.connection.channel()
            self.channel.exchange_declare(exchange='orders', exchange_type='topic')
            logger.info("Successfully connected to RabbitMQ.")
        except pika.exceptions.AMQPConnectionError as e:
            logger.critical(f"Failed to connect to broker: {e}. Exiting.")
            sys.exit(1)

    def publish_event(self, event_type, order_id):
        if not self.connection or self.connection.is_closed:
            self.connect()

        message = {
            "event_id": str(uuid.uuid4()),
            "event_type": event_type,
            "order_id": order_id,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        try:
            self.channel.basic_publish(
                exchange='orders',
                routing_key=event_type,
                body=json.dumps(message),
                properties=pika.BasicProperties(
                    delivery_mode=pika.spec.PERSISTENT_DELIVERY_MODE
                )
            )
            logger.info(f"Published event {event_type} for order {order_id}.")
        except Exception as e:
            logger.error(f"Failed to publish message: {e}")

    def close(self):
        if self.connection and not self.connection.is_closed:
            self.connection.close()
            logger.info("Connection closed.")

if __name__ == '__main__':
    producer = OrderAPIProducer()
    producer.connect()
    
    producer.publish_event("payment.created", "A-10001")
    producer.publish_event("email.sent", "A-10001")
    producer.publish_event("order.fraud_check", "A-10001")
    
    producer.close()