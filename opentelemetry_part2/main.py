from fastapi import FastAPI
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from api.routers import orders, health

app = FastAPI()

app.include_router(health.router)
app.include_router(orders.router)

FastAPIInstrumentor.instrument_app(app)