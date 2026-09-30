import pika
import json
import os

amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
connection = pika.BlockingConnection(pika.URLParameters(amqp_url))
channel = connection.channel()

events = [
    {"event_type": "payment.created", "payload": "Valid transaction"},
    {"event_type": "poison", "payload": "Will cause temporary failure"},
    {"event_type": "fatal", "payload": "Will cause permanent failure"}
]

for event in events:
    channel.basic_publish(
        exchange='orders',
        routing_key='payment.created',
        body=json.dumps(event)
    )

channel.basic_publish(
    exchange='orders',
    routing_key='payment.created',
    body='INVALID_JSON_STRING'
)

print("Sent test messages to payment queue.")
connection.close()