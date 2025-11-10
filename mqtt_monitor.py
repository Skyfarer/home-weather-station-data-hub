#!/usr/bin/env python3.12
"""
MQTT Monitor - A utility for monitoring MQTT messages
"""

import sys
import yaml
import json
import subprocess
import paho.mqtt.client as mqtt
from datetime import datetime
from pathlib import Path


def on_connect(client, userdata, flags, rc):
    """Callback when client connects to MQTT broker"""
    if rc == 0:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Connected to MQTT broker")
        topic = userdata.get('topic')
        if topic:
            client.subscribe(topic)
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Subscribed to topic: {topic}")
    else:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Connection failed with code {rc}")
        sys.exit(1)


def convert_to_sea_level_pressure(station_pressure_hpa, elevation_feet):
    """
    Convert station pressure to sea level pressure

    Args:
        station_pressure_hpa: Pressure reading at station elevation (hPa)
        elevation_feet: Station elevation above sea level (feet)

    Returns:
        Sea level pressure in hPa
    """
    # Convert feet to meters
    elevation_m = elevation_feet * 0.3048

    # Standard approximation: add ~1.2 hPa per 10m elevation
    # or approximately 1 hPa per 8.3m
    sea_level_pressure = station_pressure_hpa + (elevation_m / 8.3)

    return sea_level_pressure


def on_message(client, userdata, msg):
    """Callback when a message is received"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"\n[{timestamp}] Topic: {msg.topic}")

    try:
        payload = msg.payload.decode('utf-8')
        data = json.loads(payload)

        # Display MAC address
        mac = data.get('mac', 'Unknown')
        print(f"Device MAC: {mac}")

        # Parse CSV data
        csv_data = data.get('data', '')
        if csv_data:
            values = csv_data.split(',')
            if len(values) >= 4:
                temp_c = float(values[0])
                humidity = float(values[1])
                pressure = float(values[2])
                voltage = float(values[3])

                # Convert temperature to Fahrenheit
                temp_f = (temp_c * 9/5) + 32

                # Convert pressure to sea level if elevation is configured
                elevation_feet = userdata.get('elevation_feet', 0)
                if elevation_feet > 0:
                    sea_level_pressure = convert_to_sea_level_pressure(pressure, elevation_feet)
                    print(f"Temperature: {temp_c:.2f}°C ({temp_f:.2f}°F)")
                    print(f"Humidity:    {humidity:.2f}%")
                    print(f"Pressure:    {pressure:.2f} hPa (station), {sea_level_pressure:.2f} hPa (sea level)")
                    print(f"Battery:     {voltage:.2f}V")
                else:
                    sea_level_pressure = pressure
                    print(f"Temperature: {temp_c:.2f}°C ({temp_f:.2f}°F)")
                    print(f"Humidity:    {humidity:.2f}%")
                    print(f"Pressure:    {pressure:.2f} hPa")
                    print(f"Battery:     {voltage:.2f}V")

                # Update RRD database if configured
                rrd_path = userdata.get('rrd_path')
                if rrd_path:
                    try:
                        # RRD data sources order: temperature, pressure, humidity, voltage
                        # Use sea level pressure for RRD storage
                        cmd = [
                            'rrdtool', 'update', rrd_path,
                            f'N:{temp_c}:{sea_level_pressure}:{humidity}:{voltage}'
                        ]
                        result = subprocess.run(cmd, capture_output=True, text=True)
                        if result.returncode == 0:
                            print(f"RRD updated successfully")
                        else:
                            print(f"RRD update failed: {result.stderr}")
                    except Exception as e:
                        print(f"Error updating RRD: {e}")
            else:
                print(f"Data: {csv_data}")

        data_len = data.get('len', 0)
        print(f"Data length: {data_len}")

    except json.JSONDecodeError:
        # If not JSON, display raw payload
        print(f"Payload: {msg.payload.decode('utf-8', errors='replace')}")
    except Exception as e:
        print(f"Error parsing message: {e}")
        print(f"Raw payload: {msg.payload.decode('utf-8', errors='replace')}")

    print("-" * 80)


def on_disconnect(client, userdata, rc):
    """Callback when client disconnects from MQTT broker"""
    if rc != 0:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Unexpected disconnect")


def load_config(config_path='config.yaml'):
    """Load configuration from YAML file"""
    config_file = Path(config_path)

    if not config_file.exists():
        print(f"Error: Configuration file '{config_path}' not found")
        sys.exit(1)

    try:
        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)
        return config
    except yaml.YAMLError as e:
        print(f"Error parsing configuration file: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error loading configuration: {e}")
        sys.exit(1)


def main():
    """Main entry point for the MQTT monitor"""
    # Load configuration
    config = load_config()

    # Extract MQTT settings
    mqtt_config = config.get('mqtt', {})
    broker = mqtt_config.get('broker')
    port = mqtt_config.get('port', 1883)
    topic = mqtt_config.get('topic')

    # Extract elevation settings
    elevation_config = config.get('elevation', {})
    elevation_feet = elevation_config.get('feet', 0)

    # Extract RRD settings
    rrd_config = config.get('rrd', {})
    rrd_path = rrd_config.get('path')

    # Validate required settings
    if not broker:
        print("Error: 'broker' not specified in config file")
        sys.exit(1)
    if not topic:
        print("Error: 'topic' not specified in config file")
        sys.exit(1)

    print("MQTT Monitor initialized")
    print(f"Broker: {broker}:{port}")
    print(f"Topic: {topic}")
    if elevation_feet > 0:
        print(f"Elevation: {elevation_feet} feet (sea level pressure conversion enabled)")
    if rrd_path:
        print(f"RRD: {rrd_path}")
    print("=" * 80)

    # Create MQTT client
    client = mqtt.Client(userdata={
        'topic': topic,
        'elevation_feet': elevation_feet,
        'rrd_path': rrd_path
    })

    # Set up callbacks
    client.on_connect = on_connect
    client.on_message = on_message
    client.on_disconnect = on_disconnect

    try:
        # Connect to broker
        client.connect(broker, port, 60)

        # Start the loop
        print("Starting MQTT monitoring... (Press Ctrl+C to exit)")
        client.loop_forever()

    except KeyboardInterrupt:
        print(f"\n[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Shutting down...")
        client.disconnect()
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
