from pydantic import BaseModel

class OrderRequest(BaseModel):
    item_count: int
    currency: str
    fail_validation: bool = False
    simulate_delay: bool = False

class OrderResponse(BaseModel):
    order_id: str
    status: str