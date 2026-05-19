FROM nginx:1.25-alpine

# For ECS container health checks that use curl
RUN apk add --no-cache curl

EXPOSE 80

# Optional: local healthcheck (ECS ma własny)
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -f http://localhost/ || exit 1
