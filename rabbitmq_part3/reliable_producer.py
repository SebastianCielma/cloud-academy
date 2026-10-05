import pika
import json
import logging
import os
import uuid

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

class ReliableProducer:
    def __init__(self):
        amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
        self.connection = pika.BlockingConnection(pika.URLParameters(amqp_url))
        self.channel = self.connection.channel()
        
        self.channel.exchange_declare(exchange='secure_orders', exchange_type='topic', durable=True)
        self.channel.confirm_delivery()
        logger.info("Publisher confirms enabled.")

    def publish(self, routing_key, event_type, mandatory=True):
        event_id = str(uuid.uuid4())
        message = {
            "event_id": event_id,
            "event_type": event_type,
            "amount": 150.00
        }
        
        try:
            self.channel.basic_publish(
                exchange='secure_orders',
                routing_key=routing_key,
                body=json.dumps(message),
                mandatory=mandatory,
                properties=pika.BasicProperties(
                    delivery_mode=pika.spec.PERSISTENT_DELIVERY_MODE,
                    content_type='application/json'
                )
            )
            logger.info(f"Broker confirmed message {event_id} (Routing: {routing_key})")
            
        except pika.exceptions.UnroutableError:
            logger.error(f"Message {event_id} returned as UNROUTABLE.")
        except pika.exceptions.NackError:
            logger.error(f"Broker NACKed message {event_id}. Disk full or internal error.")
        except pika.exceptions.AMQPError as e:
            logger.critical(f"Connection/Timeout error: {e}")

    def close(self):
        if self.connection and not self.connection.is_closed:
            self.connection.close()

if __name__ == '__main__':
    producer = ReliableProducer()
    
    producer.publish(routing_key='payment.charge', event_type='charge_customer')
    producer.publish(routing_key='invalid.nowhere', event_type='lost_event', mandatory=True)
    
    producer.close()