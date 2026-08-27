FROM python:3.10-slim
WORKDIR /app
RUN pip install fastapi uvicorn pydantic httpx opentelemetry-api opentelemetry-sdk opentelemetry-instrumentation-fastapi opentelemetry-instrumentation-httpx opentelemetry-exporter-otlp
COPY . .
CMD ["uvicorn", "order_service:app", "--host", "0.0.0.0", "--port", "8001"]