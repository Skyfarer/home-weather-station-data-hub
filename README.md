# Home Weather Station Data Hub

A Python-based data hub for home weather stations that processes MQTT sensor data, stores it to RRD (Round Robin Database) for time-series tracking, and republishes processed data for display devices.

## Features

- 📡 **MQTT Data Hub** - Subscribe to weather station MQTT topics and process sensor data
- 🌡️ **Sensor Data Processing** - Parse temperature, humidity, pressure, and battery voltage
- 🏔️ **Sea Level Pressure Conversion** - Automatically adjust pressure readings based on elevation
- 💾 **RRD Storage** - Store time-series data in RRD format for historical tracking and graphing
- 🔄 **Data Republishing** - Republish processed weather data for desktop displays and other consumers
- ☸️ **Kubernetes Ready** - Deploy as a containerized service in k3s/Kubernetes homelab

## Quick Start

### 1. Configuration

Copy the example config and customize it:

```bash
cp config.yaml config.yaml.local
nano config.yaml.local
```

Edit the following settings:
- `mqtt.broker`: Your MQTT broker hostname or IP
- `mqtt.topic`: The MQTT topic to subscribe to
- `elevation.feet`: Your elevation above sea level (for pressure conversion)
- `rrd.path`: Path to your RRD database file

### 2. Install Dependencies

```bash
pip install -r requirements.txt

# Also install rrdtool (system package)
# Ubuntu/Debian:
sudo apt-get install rrdtool

# Fedora/RHEL:
sudo dnf install rrdtool
```

### 3. Create RRD Database

If you don't have an existing RRD file, create one:

```bash
rrdtool create sensors.rrd \
  --step 120 \
  DS:temperature:GAUGE:240:U:U \
  DS:pressure:GAUGE:240:U:U \
  DS:humidity:GAUGE:240:0:100 \
  DS:voltage:GAUGE:240:0:5 \
  RRA:AVERAGE:0.5:3:240 \
  RRA:AVERAGE:0.5:30:336 \
  RRA:AVERAGE:0.5:120:720 \
  RRA:MIN:0.5:30:336 \
  RRA:MAX:0.5:30:336
```

### 4. Run the Data Hub

```bash
# Using your local config
python mqtt_monitor.py

# Or make it executable
chmod +x mqtt_monitor.py
./mqtt_monitor.py
```

## Deployment Options

### k3s/Kubernetes (Recommended for Homelab)

See [k3s/K3S-DEPLOYMENT.md](k3s/K3S-DEPLOYMENT.md) for detailed instructions.

Quick deploy:
```bash
# Build and import image
docker build -t mqtt-monitor:latest .
docker save mqtt-monitor:latest -o mqtt-monitor.tar
sudo k3s ctr images import mqtt-monitor.tar

# Deploy
kubectl apply -f k3s/configmap.yaml
kubectl apply -f k3s/pv-pvc-nfs.yaml
kubectl apply -f k3s/deployment.yaml
```

## Data Format

The data hub expects MQTT messages from the weather station in JSON format with CSV sensor data:

```json
{
  "mac": "AA:BB:CC:DD:EE:FF",
  "data": "21.5,45.3,1013.25,3.25",
  "len": 24
}
```

Where the CSV data contains:
1. Temperature (°C)
2. Humidity (%)
3. Pressure (hPa)
4. Battery voltage (V)

## Output Example

```
[2025-01-10 12:30:45] Topic: sensor/device/ABC123/data
Device MAC: AA:BB:CC:DD:EE:FF
Temperature: 21.50°C (70.70°F)
Humidity:    45.30%
Pressure:    1013.25 hPa (station), 1035.25 hPa (sea level)
Battery:     3.25V
RRD updated successfully
```

## Architecture

- **Single-file utility**: `mqtt_monitor.py`
- **YAML configuration**: `config.yaml`
- **Callback-based**: Uses paho-mqtt client callbacks
- **RRD integration**: Updates via `rrdtool update` subprocess

## Storage Options

1. **NFS on NAS** - Store RRD on network storage (k3s deployment)
2. **Local Path** - Store RRD on local filesystem

## Creating Graphs

Use rrdtool to create graphs from your data:

```bash
# Temperature graph (last 24 hours)
rrdtool graph temp_24h.png \
  --start -86400 \
  --title "Temperature (24h)" \
  DEF:temp=sensors.rrd:temperature:AVERAGE \
  LINE2:temp#FF0000:"Temperature °C"

# Pressure graph (last week)
rrdtool graph pressure_week.png \
  --start -604800 \
  --title "Sea Level Pressure (7 days)" \
  DEF:pressure=sensors.rrd:pressure:AVERAGE \
  LINE2:pressure#0000FF:"Pressure hPa"
```

## Project Structure

```
mqtt_monitor/
├── mqtt_monitor.py          # Main application
├── config.yaml              # Configuration (example - edit for your setup)
├── requirements.txt         # Python dependencies
├── Dockerfile              # Container image definition
├── .dockerignore           # Docker build exclusions
├── .gitignore             # Git exclusions
└── k3s/                   # k3s manifests
    ├── K3S-DEPLOYMENT.md  # k3s deployment guide
    ├── configmap.yaml     # Config as ConfigMap
    ├── deployment.yaml    # Deployment manifest
    └── pv-pvc-nfs.yaml   # NFS storage on NAS
```

## Use Cases

- **Home Weather Station Monitoring** - Central hub for processing weather station data
- **Time-Series Storage** - Long-term storage and trending of environmental data
- **Display Integration** - Feed processed data to desktop displays, dashboards, or other devices
- **Homelab Infrastructure** - Self-hosted weather data processing in your homelab

## Contributing

This is a homelab/learning project. Feel free to fork and customize for your home weather station needs!

## License

MIT License - See LICENSE file for details

## Learn More

- [MQTT Protocol](https://mqtt.org/)
- [RRDtool Documentation](https://oss.oetiker.ch/rrdtool/)
- [paho-mqtt Python Client](https://pypi.org/project/paho-mqtt/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [k3s Lightweight Kubernetes](https://k3s.io/)
