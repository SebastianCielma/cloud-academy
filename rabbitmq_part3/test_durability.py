import pika
import os

amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
connection = pika.BlockingConnection(pika.URLParameters(amqp_url))
channel = connection.channel()

channel.queue_declare(queue='transient.queue', durable=False)
channel.basic_publish(
    exchange='',
    routing_key='transient.queue',
    body='This will disappear after restart',
    properties=pika.BasicProperties(delivery_mode=1)
)

channel.queue_declare(queue='hardened.queue', durable=True)
channel.basic_publish(
    exchange='',
    routing_key='hardened.queue',
    body='This will survive restart',
    properties=pika.BasicProperties(delivery_mode=2)
)

print("Test messages sent.")
connection.close()