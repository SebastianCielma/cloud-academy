import uuid
import time
from fastapi import APIRouter, HTTPException, status
from models.order import OrderRequest, OrderResponse
from services.order_service import validate_order, calculate_price, save_order
from core.telemetry import logger, order_processing_duration, orders_created_counter, orders_failed_counter

router = APIRouter()

@router.post("/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order(order: OrderRequest):
    order_id = str(uuid.uuid4())
    start_time = time.time()
    
    try:
        logger.info("Processing new order request")
        validate_order(order)
        price = calculate_price(order)
        save_order(order_id, order, price)
        
        duration = time.time() - start_time
        order_processing_duration.record(duration, {"currency": order.currency})
        orders_created_counter.add(1, {"currency": order.currency})
        
        logger.info("Order processed successfully")
        return OrderResponse(order_id=order_id, status="CREATED")
        
    except ValueError as e:
        orders_failed_counter.add(1, {"currency": order.currency})
        logger.error(f"Order processing failed: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))