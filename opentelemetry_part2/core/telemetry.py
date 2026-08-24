import logging
import json
from opentelemetry import trace, metrics
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

resource = Resource.create({"service.name": "order-service"})

trace_provider = TracerProvider(resource=resource)
trace_processor = BatchSpanProcessor(OTLPSpanExporter(endpoint="http://localhost:4317", insecure=True))
trace_provider.add_span_processor(trace_processor)
trace.set_tracer_provider(trace_provider)
tracer = trace.get_tracer("order_service_tracer")

metric_reader = PeriodicExportingMetricReader(OTLPMetricExporter(endpoint="http://localhost:4317", insecure=True))
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)
meter = metrics.get_meter("order_service_meter")

orders_created_counter = meter.create_counter("orders.created")
orders_failed_counter = meter.create_counter("orders.failed")
order_processing_duration = meter.create_histogram("order.processing.duration")
order_value_histogram = meter.create_histogram("order.value")

class JSONLogFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        current_span = trace.get_current_span()
        span_context = current_span.get_span_context()
        
        log_data = {
            "level": record.levelname,
            "message": record.getMessage(),
            "trace_id": format(span_context.trace_id, "032x") if span_context.is_valid else "",
            "span_id": format(span_context.span_id, "016x") if span_context.is_valid else ""
        }
        return json.dumps(log_data)

def setup_logger():
    logger = logging.getLogger("order_service_logger")
    logger.setLevel(logging.INFO)
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(JSONLogFormatter())
    if not logger.handlers:
        logger.addHandler(console_handler)
    return logger

logger = setup_logger()