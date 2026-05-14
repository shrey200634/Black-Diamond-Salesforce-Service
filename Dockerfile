FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    librdkafka-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 5711

# Run with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:5711", "--workers", "2", "--timeout", "120", "app.main:create_app()"]
