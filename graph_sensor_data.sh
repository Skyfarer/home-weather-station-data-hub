#!/bin/bash

# Graph sensor data from RRD database
# Generates graphs for 24 hours, 1 week, 1 month, and 1 year

RRD_FILE="/data/rrd/sensors.rrd"
OUTPUT_DIR="/data/www/weather_station"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Colors for graphs
COLOR_TEMP="#FF0000"      # Red for temperature
COLOR_PRESSURE="#0000FF"  # Blue for pressure
COLOR_HUMIDITY="#00AA00"  # Green for humidity
COLOR_VOLTAGE="#FF8800"   # Orange for voltage

# Function to create graphs
create_graphs() {
    local period=$1
    local title=$2
    local start=$3

    # Temperature graph
    rrdtool graph "$OUTPUT_DIR/temperature_${period}.png" \
        --start "$start" \
        --title "Temperature - $title" \
        --vertical-label "Temperature (°F)" \
        --width 800 \
        --height 300 \
        DEF:temp="$RRD_FILE":temperature:AVERAGE \
        DEF:temp_min="$RRD_FILE":temperature:MIN \
        DEF:temp_max="$RRD_FILE":temperature:MAX \
        CDEF:temp_filtered=temp,-40,LT,UNKN,temp,60,GT,UNKN,temp,IF,IF \
        CDEF:temp_min_filtered=temp_min,-40,LT,UNKN,temp_min,60,GT,UNKN,temp_min,IF,IF \
        CDEF:temp_max_filtered=temp_max,-40,LT,UNKN,temp_max,60,GT,UNKN,temp_max,IF,IF \
        CDEF:temp_f=temp_filtered,9,*,5,/,32,+ \
        CDEF:temp_min_f=temp_min_filtered,9,*,5,/,32,+ \
        CDEF:temp_max_f=temp_max_filtered,9,*,5,/,32,+ \
        AREA:temp_max_f#FFCCCC:"Max" \
        AREA:temp_min_f#FFFFFF:"Min" \
        LINE2:temp_f$COLOR_TEMP:"Temperature" \
        GPRINT:temp_f:LAST:"Current\:%8.2lf °F" \
        GPRINT:temp_f:AVERAGE:"Average\:%8.2lf °F" \
        GPRINT:temp_min_f:MIN:"Min\:%8.2lf °F" \
        GPRINT:temp_max_f:MAX:"Max\:%8.2lf °F\n"

    # Pressure graph (converted to inches of mercury)
    rrdtool graph "$OUTPUT_DIR/pressure_${period}.png" \
        --start "$start" \
        --title "Atmospheric Pressure - $title" \
        --vertical-label "Pressure (inHg)" \
        --width 800 \
        --height 300 \
        --lower-limit 28.0 \
        --upper-limit 31.0 \
        --rigid \
        DEF:pressure="$RRD_FILE":pressure:AVERAGE \
        DEF:pressure_min="$RRD_FILE":pressure:MIN \
        DEF:pressure_max="$RRD_FILE":pressure:MAX \
        CDEF:pressure_inhg=pressure,33.8639,/ \
        CDEF:pressure_min_inhg=pressure_min,33.8639,/ \
        CDEF:pressure_max_inhg=pressure_max,33.8639,/ \
        AREA:pressure_max_inhg#CCCCFF:"Max" \
        AREA:pressure_min_inhg#FFFFFF:"Min" \
        LINE2:pressure_inhg$COLOR_PRESSURE:"Pressure" \
        GPRINT:pressure_inhg:LAST:"Current\:%8.2lf inHg" \
        GPRINT:pressure_inhg:AVERAGE:"Average\:%8.2lf inHg" \
        GPRINT:pressure_min_inhg:MIN:"Min\:%8.2lf inHg" \
        GPRINT:pressure_max_inhg:MAX:"Max\:%8.2lf inHg\n"

    # Humidity graph
    rrdtool graph "$OUTPUT_DIR/humidity_${period}.png" \
        --start "$start" \
        --title "Humidity - $title" \
        --vertical-label "Humidity (%)" \
        --width 800 \
        --height 300 \
        --lower-limit 0 \
        --upper-limit 100 \
        --rigid \
        DEF:humidity="$RRD_FILE":humidity:AVERAGE \
        DEF:humidity_min="$RRD_FILE":humidity:MIN \
        DEF:humidity_max="$RRD_FILE":humidity:MAX \
        AREA:humidity_max#CCFFCC:"Max" \
        AREA:humidity_min#FFFFFF:"Min" \
        LINE2:humidity$COLOR_HUMIDITY:"Humidity" \
        GPRINT:humidity:LAST:"Current\:%8.2lf %%" \
        GPRINT:humidity:AVERAGE:"Average\:%8.2lf %%" \
        GPRINT:humidity_min:MIN:"Min\:%8.2lf %%" \
        GPRINT:humidity_max:MAX:"Max\:%8.2lf %%\n"

    # Voltage graph (battery level)
    rrdtool graph "$OUTPUT_DIR/voltage_${period}.png" \
        --start "$start" \
        --title "Battery Voltage - $title" \
        --vertical-label "Voltage (V)" \
        --width 800 \
        --height 300 \
        --lower-limit 0 \
        --upper-limit 5 \
        DEF:voltage="$RRD_FILE":voltage:AVERAGE \
        DEF:voltage_min="$RRD_FILE":voltage:MIN \
        DEF:voltage_max="$RRD_FILE":voltage:MAX \
        AREA:voltage_max#FFEECC:"Max" \
        AREA:voltage_min#FFFFFF:"Min" \
        LINE2:voltage$COLOR_VOLTAGE:"Voltage" \
        GPRINT:voltage:LAST:"Current\:%8.2lf V" \
        GPRINT:voltage:AVERAGE:"Average\:%8.2lf V" \
        GPRINT:voltage_min:MIN:"Min\:%8.2lf V" \
        GPRINT:voltage_max:MAX:"Max\:%8.2lf V\n"

    echo "Generated graphs for $title in $OUTPUT_DIR/"
}

# Generate graphs for different time periods
echo "Generating sensor graphs..."
echo ""

create_graphs "24h" "Last 24 Hours" "end-24h"
create_graphs "1week" "Last Week" "end-1w"
create_graphs "1month" "Last Month" "end-1month"
create_graphs "1year" "Last Year" "end-1y"

echo ""
echo "All graphs generated successfully!"
echo "Output directory: $OUTPUT_DIR/"
