FROM python:3.12-alpine

ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY apps/server.py /app/server.py

RUN mkdir -p /data && chown -R 10001:10001 /data /app

USER 10001:10001

EXPOSE 8080

CMD ["python", "/app/server.py"]
