# golang:1.26.3-alpine - STAGE 1: DOWNLOAD DEPDENCIES (USING LAYER CACHING)
FROM golang@sha256:91eda9776261207ea25fd06b5b7fed8d397dd2c0a283e77f2ab6e91bfa71079d AS deps
RUN apk --update add --no-cache ca-certificates
WORKDIR /app
COPY gatus/go.mod gatus/go.sum ./
RUN go mod download

#STAGE 2 COPY SOURCE AND BUILD THE BINARY
FROM deps AS builder
COPY gatus/ ./
ENV GATUS_CONFIG_PATH="config/config.yaml"
RUN CGO_ENABLED=0 GOOS=linux go build -o gatus .

FROM alpine:3.20 AS runtime
LABEL org.opencontainers.image.title="gatus" \
      org.opencontainers.image.description="Gatus uptime/status monitoring service, containerized for ECS Fargate" \
      org.opencontainers.image.licenses="Apache-2.0"
WORKDIR /app
RUN apk add --no-cache curl \
    && addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder /app/gatus ./
COPY config.yaml ./config/config.yaml
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt 
USER appuser

ENV GATUS_CONFIG_PATH="config/config.yaml"
ENV GATUS_LOG_LEVEL="INFO"
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
ENTRYPOINT [ "./gatus" ]