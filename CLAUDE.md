# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Home Weather Station Data Hub is a Python-based data processing hub for home weather stations. It subscribes to MQTT topics from weather sensors, processes the data (temperature, humidity, pressure, battery), stores historical data to RRD databases, and republishes processed data for desktop displays and other consumers.

## Development Commands

**Install dependencies:**
```bash
pip install -r requirements.txt
```

**Configure the data hub:**
Edit `config.yaml` to set your MQTT broker, port, topic, and RRD settings:
```yaml
mqtt:
  broker: "localhost"
  port: 1883
  topic: "test/topic"
```

**Run the data hub:**
```bash
python mqtt_monitor.py
# or
./mqtt_monitor.py
```

## Architecture

Single-file data hub script (`mqtt_monitor.py`) with:
- YAML-based configuration from `config.yaml`
- Main entry point at `main()` function
- MQTT subscribe/publish logic using paho-mqtt library
- Callback-based message handling
- RRD database integration for time-series storage
- Sea level pressure conversion based on elevation
- Data processing and republishing for displays
