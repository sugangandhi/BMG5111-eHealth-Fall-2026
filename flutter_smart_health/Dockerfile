# ==============================================================================
# Multi-stage Dockerfile for Flutter Smart Health (Unified Web + API)
# ==============================================================================

# Stage 1: Build the Flutter Web application
FROM ghcr.io/cirruslabs/flutter:stable AS flutter_builder
WORKDIR /app
COPY src/app /app
RUN flutter pub get && flutter build web --release

# Stage 2: Python FastAPI backend serving API + Flutter Web static bundle
FROM python:3.11-slim
WORKDIR /workspace

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code and pre-built Flutter web bundle from Stage 1
COPY . .
COPY --from=flutter_builder /app/build/web /workspace/src/app/build/web

ENV PORT=8080
ENV PYTHONUNBUFFERED=1

EXPOSE 8080

CMD ["sh", "-c", "uvicorn src.backend.main:app --host 0.0.0.0 --port ${PORT}"]
