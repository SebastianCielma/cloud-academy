FROM python:3.12-alpine

ARG APP_VERSION=v1

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION} \
    PORT=8080

WORKDIR /app

RUN addgroup -S application && adduser -S -D -H -G application application

COPY server.py /app/server.py

USER 10001:10001

EXPOSE 8080

CMD ["python", "-u", "/app/server.py"]
