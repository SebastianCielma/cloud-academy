import time
from typing import Dict, Any
from opentelemetry import trace
from models.order import OrderRequest
from core.telemetry import tracer, logger, order_value_histogram

db: Dict[str, Dict[str, Any]] = {}

def validate_order(order: OrderRequest) -> None:
    with tracer.start_as_current_span("validate-order") as span:
        logger.info(f"Starting validation for order with {order.item_count} items")
        if order.fail_validation:
            logger.error("Validation failed due to bad request flags")
            span.set_status(trace.StatusCode.ERROR)
            raise ValueError("Invalid order data")
        logger.info("Validation successful")

def calculate_price(order: OrderRequest) -> float:
    with tracer.start_as_current_span("calculate-price") as span:
        logger.info("Calculating price")
        if order.simulate_delay:
            logger.warning("Delay injected into calculate-price")
            time.sleep(2)
        price = order.item_count * 10.5
        order_value_histogram.record(price, {"currency": order.currency})
        return price

def save_order(order_id: str, order: OrderRequest, price: float) -> None:
    with tracer.start_as_current_span("save-order") as span:
        logger.info("Saving order to database")
        db[order_id] = {"item_count": order.item_count, "currency": order.currency, "price": price}