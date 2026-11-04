FROM python:3.12-alpine

WORKDIR /app

COPY apps/server.py /app/server.py

RUN addgroup -S app && adduser -S app -G app

USER app

EXPOSE 8080

CMD ["python", "-u", "/app/server.py"]
