import asyncio
from fastapi import FastAPI
from pydantic import BaseModel
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
import os

resource = Resource.create({"service.name": "payment-service", "service.version": "1.0.0"})
provider = TracerProvider(resource=resource)
otel_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=otel_endpoint, insecure=True)))
trace.set_tracer_provider(provider)

app = FastAPI()
FastAPIInstrumentor.instrument_app(app)

class PaymentRequest(BaseModel):
    amount: float

@app.post("/payment")
async def process_payment(request: PaymentRequest):
    await asyncio.sleep(3.0)
    return {"payment": "successful"}