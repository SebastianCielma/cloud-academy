import httpx
from fastapi import FastAPI
from pydantic import BaseModel
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.instrumentation.utils import suppress_instrumentation
import os

resource = Resource.create({
    "service.name": "order-service",
    "service.version": "1.0.0",
    "deployment.environment": "production"
})
provider = TracerProvider(resource=resource)
otel_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=otel_endpoint, insecure=True)))
trace.set_tracer_provider(provider)

app = FastAPI()
FastAPIInstrumentor.instrument_app(app)
HTTPXClientInstrumentor().instrument()

class Order(BaseModel):
    item_id: str
    amount: float
    break_context: bool = False

@app.post("/orders")
async def create_order(order: Order):
    async with httpx.AsyncClient() as client:
        await client.post("http://inventory-service:8002/inventory", json={"item_id": order.item_id})
        
        if order.break_context:
            with suppress_instrumentation():
                await client.post("http://payment-service:8003/payment", json={"amount": order.amount})
        else:
            await client.post("http://payment-service:8003/payment", json={"amount": order.amount})
            
    return {"status": "Order Processed"}