#!/bin/bash

# Create RRD database for sensor data
# Data collected every 2 minutes (120 seconds)
# 4 data sources: temperature, pressure, humidity, voltage

rrdtool create sensors.rrd \
  --step 120 \
  DS:temperature:GAUGE:240:U:U \
  DS:pressure:GAUGE:240:U:U \
  DS:humidity:GAUGE:240:0:100 \
  DS:voltage:GAUGE:240:0:5 \
  RRA:AVERAGE:0.5:3:240 \
  RRA:AVERAGE:0.5:15:336 \
  RRA:AVERAGE:0.5:60:360 \
  RRA:AVERAGE:0.5:720:365 \
  RRA:MIN:0.5:3:240 \
  RRA:MIN:0.5:15:336 \
  RRA:MIN:0.5:60:360 \
  RRA:MIN:0.5:720:365 \
  RRA:MAX:0.5:3:240 \
  RRA:MAX:0.5:15:336 \
  RRA:MAX:0.5:60:360 \
  RRA:MAX:0.5:720:365

echo "RRD database 'sensors.rrd' created successfully"
