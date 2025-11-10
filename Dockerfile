FROM python:3.12-slim

# Install rrdtool
RUN apt-get update && \
    apt-get install -y rrdtool && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY mqtt_monitor.py .
COPY config.yaml .

# Create directory for RRD data
RUN mkdir -p /data/rrd

# Run the application
CMD ["python", "mqtt_monitor.py"]
