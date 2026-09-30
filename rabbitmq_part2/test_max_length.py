import pika
import os

amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
connection = pika.BlockingConnection(pika.URLParameters(amqp_url))
channel = connection.channel()

channel.exchange_declare(exchange='payment.dlx', exchange_type='direct')
channel.queue_declare(queue='payment.dlq')
channel.queue_bind(exchange='payment.dlx', queue='payment.dlq', routing_key='payment.dead')

channel.queue_declare(queue='payment.queue', arguments={
    'x-max-length': 5,
    'x-overflow': 'drop-head',
    'x-dead-letter-exchange': 'payment.dlx',
    'x-dead-letter-routing-key': 'payment.dead'
})

print("Sending 6 messages to a queue with max length of 5")
for i in range(1, 7):
    channel.basic_publish(
        exchange='',
        routing_key='payment.queue',
        body=f'Message number {i}'
    )
    print(f"Sent: Message number {i}")

connection.close()