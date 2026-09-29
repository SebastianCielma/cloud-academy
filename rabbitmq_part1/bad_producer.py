import pika
import os

amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
connection = pika.BlockingConnection(pika.URLParameters(amqp_url))
channel = connection.channel()

channel.basic_publish(
    exchange='orders',
    routing_key='payment.created',
    body='THIS IS NOT A VALID JSON STRING'
)
print("Sent broken message.")
connection.close()