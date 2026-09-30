import pika
import os

amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
connection = pika.BlockingConnection(pika.URLParameters(amqp_url))
channel = connection.channel()

channel.exchange_declare(exchange='payment.dlx', exchange_type='direct')

channel.queue_declare(queue='payment.retry.queue', arguments={
    'x-dead-letter-exchange': 'payment.dlx',
    'x-dead-letter-routing-key': 'payment.main'
})

print("Sending message with TTL = 2 seconds")
channel.basic_publish(
    exchange='',
    routing_key='payment.retry.queue',
    body='Message (expires in 2s)',
    properties=pika.BasicProperties(
        expiration='2000'
    )
)

print("Sending message with TTL = 10 seconds")
channel.basic_publish(
    exchange='',
    routing_key='payment.retry.queue',
    body='Message (expires in 10s)',
    properties=pika.BasicProperties(
        expiration='10000'
    )
)

connection.close()