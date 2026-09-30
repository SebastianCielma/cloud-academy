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

class ResilientPaymentWorker:
    def __init__(self):
        amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
        self.parameters = pika.URLParameters(amqp_url)
        self.connection = None
        self.channel = None
        self.max_retries = 3

    def connect(self):
        try:
            self.connection = pika.BlockingConnection(self.parameters)
            self.channel = self.connection.channel()

            self.channel.exchange_declare(exchange='orders', exchange_type='topic')
            self.channel.exchange_declare(exchange='payment.dlx', exchange_type='direct')

            self.channel.queue_declare(queue='payment.dlq')
            self.channel.queue_bind(exchange='payment.dlx', queue='payment.dlq', routing_key='payment.dead')

            self.channel.queue_declare(queue='payment.retry.queue', arguments={
                'x-dead-letter-exchange': 'payment.dlx',
                'x-dead-letter-routing-key': 'payment.main',
                'x-message-ttl': 30000
            })
            self.channel.queue_bind(exchange='payment.dlx', queue='payment.retry.queue', routing_key='payment.retry')

            self.channel.queue_declare(queue='payment.queue', arguments={
                'x-dead-letter-exchange': 'payment.dlx',
                'x-dead-letter-routing-key': 'payment.retry'
            })
            self.channel.queue_bind(exchange='orders', queue='payment.queue', routing_key='payment.*')
            self.channel.queue_bind(exchange='payment.dlx', queue='payment.queue', routing_key='payment.main')

            self.channel.basic_qos(prefetch_count=1)
            logger.info("Resilient topology configured.")
        except Exception as e:
            logger.critical(f"Connection failed: {e}")
            sys.exit(1)

    def get_retry_count(self, properties):
        if not properties.headers or 'x-death' not in properties.headers:
            return 0
        for death in properties.headers['x-death']:
            if death.get('queue') == 'payment.queue':
                return death.get('count', 0)
        return 0

    def send_to_dlq(self, ch, method, properties, body, reason):
        logger.warning(f"Routing to DLQ. Reason: {reason}")
        ch.basic_publish(
            exchange='payment.dlx',
            routing_key='payment.dead',
            body=body,
            properties=pika.BasicProperties(
                headers={'dlq_reason': reason}
            )
        )
        ch.basic_ack(delivery_tag=method.delivery_tag)

    def process_message(self, ch, method, properties, body):
        retry_count = self.get_retry_count(properties)

        if retry_count >= self.max_retries:
            self.send_to_dlq(ch, method, properties, body, "Max retries exceeded")
            return

        try:
            data = json.loads(body)
            event_type = data.get('event_type')
            
            if event_type == 'poison':
                raise ValueError("Simulated temporary failure")
            elif event_type == 'fatal':
                raise TypeError("Simulated permanent failure")

            logger.info(f"Processed successfully: {data}")
            ch.basic_ack(delivery_tag=method.delivery_tag)

        except TypeError as e:
            self.send_to_dlq(ch, method, properties, body, str(e))
            
        except json.JSONDecodeError:
            self.send_to_dlq(ch, method, properties, body, "Invalid JSON")

        except Exception as e:
            logger.info(f"Temporary failure ({retry_count + 1}/{self.max_retries}). NACKing to retry queue.")
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)

    def start(self):
        self.connect()
        self.channel.basic_consume(queue='payment.queue', on_message_callback=self.process_message)
        try:
            logger.info("Waiting for messages")
            self.channel.start_consuming()
        except KeyboardInterrupt:
            if self.connection and not self.connection.is_closed:
                self.connection.close()

if __name__ == '__main__':
    worker = ResilientPaymentWorker()
    worker.start()