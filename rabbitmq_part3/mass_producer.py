import pika
import json
import os
import uuid

amqp_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
connection = pika.BlockingConnection(pika.URLParameters(amqp_url))
channel = connection.channel()

for i in range(1, 11):
    event_id = str(uuid.uuid4())
    message = {"event_id": event_id, "event_type": "charge_customer", "amount": 150.00}
    
    channel.basic_publish(
        exchange='secure_orders',
        routing_key='payment.charge',
        body=json.dumps(message)
    )
    print(f"Sent task {i}")

connection.close()