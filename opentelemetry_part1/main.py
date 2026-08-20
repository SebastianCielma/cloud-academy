import uuid
from typing import Dict, Any
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

resource = Resource.create({"service.name": "order-service"})
provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(OTLPSpanExporter(endpoint="http://localhost:4317", insecure=True))
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(__name__)
app = FastAPI()
FastAPIInstrumentor.instrument_app(app)

class OrderRequest(BaseModel):
    item_count: int
    currency: str
    fail_validation: bool = False
    break_context: bool = False

class OrderResponse(BaseModel):
    order_id: str
    status: str

db: Dict[str, Dict[str, Any]] = {}

def validate_order(order: OrderRequest) -> None:
    with tracer.start_as_current_span("validate-order") as span:
        span.set_attribute("order.item_count", order.item_count)
        span.set_attribute("order.currency", order.currency)
        if order.fail_validation:
            span.set_status(trace.StatusCode.ERROR, "Validation failed intentionally")
            span.record_exception(ValueError("Invalid order data provided"))
            raise ValueError("Invalid order data")

def calculate_price(order: OrderRequest) -> float:
    with tracer.start_as_current_span("calculate-price") as span:
        price = order.item_count * 10.5
        span.set_attribute("order.calculated_price", price)
        return price

def save_order(order_id: str, order: OrderRequest, price: float) -> None:
    with tracer.start_as_current_span("save-order") as span:
        db[order_id] = {"item_count": order.item_count, "currency": order.currency, "price": price}
        span.set_attribute("order.id", order_id)

def save_order_broken_context(order_id: str, order: OrderRequest, price: float) -> None:
    with tracer.start_span("save-order-broken") as span:
        db[order_id] = {"item_count": order.item_count, "currency": order.currency, "price": price}
        span.set_attribute("order.id", order_id)

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/orders/{order_id}")
def get_order(order_id: str):
    if order_id not in db:
        raise HTTPException(status_code=404, detail="Order not found")
    return db[order_id]

@app.post("/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order(order: OrderRequest):
    order_id = str(uuid.uuid4())
    try:
        validate_order(order)
        price = calculate_price(order)
        
        if order.break_context:
            save_order_broken_context(order_id, order, price)
        else:
            save_order(order_id, order, price)
            
        return OrderResponse(order_id=order_id, status="CREATED")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))