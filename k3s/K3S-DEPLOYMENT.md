# Home Weather Station Data Hub - k3s Deployment Guide

This guide is for deploying the Home Weather Station Data Hub to k3s using NFS storage on your NAS.

## k3s Advantages for This Project

- Lightweight and perfect for homelab/IoT applications
- Easy image management with `k3s ctr`
- Simple NFS integration for centralized storage

## Prerequisites

- k3s cluster running
- NFS server (NAS) accessible from k3s nodes
- `kubectl` configured
- Docker installed for building images

## Step 1: Build and Import the Docker Image

k3s uses containerd, so we need to import the Docker image:

```bash
cd /path/to/mqtt_monitor

# Build with Docker
docker build -t mqtt-monitor:latest .

# Save the image to a tar file
docker save mqtt-monitor:latest -o mqtt-monitor.tar

# Import into k3s
sudo k3s ctr images import mqtt-monitor.tar

# Verify it's available
sudo k3s ctr images ls | grep mqtt-monitor

# Clean up the tar file
rm mqtt-monitor.tar
```

## Step 2: Configure NFS Storage on Your NAS

### On your NFS server (NAS):

Create the directory and NFS export:

```bash
# Create directory (adjust path for your setup)
sudo mkdir -p /mnt/ssd/k3s/mqtt-monitor

# Set permissions (nobody:nogroup for NFS)
sudo chown -R nobody:nogroup /mnt/ssd/k3s/mqtt-monitor
sudo chmod 755 /mnt/ssd/k3s/mqtt-monitor

# Add to /etc/exports (replace 192.168.1.0/24 with your network)
echo "/mnt/ssd/k3s/mqtt-monitor 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Apply the export
sudo exportfs -ra

# Verify the export
sudo exportfs -v
```

### Update the k3s manifest:

Edit `k3s/pv-pvc-nfs.yaml` and set your NAS details:

```bash
nano k3s/pv-pvc-nfs.yaml

# Update these values:
# server: <YOUR_NAS_IP>           # e.g., 192.168.1.100
# path: <YOUR_NFS_EXPORT_PATH>    # e.g., /mnt/ssd/k3s/mqtt-monitor
```

### Copy existing RRD (optional):

If you have an existing RRD file, copy it to the NAS:

```bash
# Via SCP (if NAS has SSH)
scp /path/to/your/existing/sensors.rrd user@nas:/mnt/ssd/k3s/mqtt-monitor/

# Or copy it directly on the NAS
cp /path/to/sensors.rrd /mnt/ssd/k3s/mqtt-monitor/
```

## Step 3: Configure the Application

Edit `k3s/configmap.yaml` to set your MQTT broker and settings:

```bash
nano k3s/configmap.yaml

# Update:
# - mqtt.broker: Your MQTT broker IP/hostname
# - mqtt.topic: Your MQTT topic
# - elevation.feet: Your elevation above sea level
```

## Step 4: Deploy to k3s

Apply the manifests:

```bash
# Create ConfigMap
kubectl apply -f k3s/configmap.yaml

# Create NFS PV and PVC
kubectl apply -f k3s/pv-pvc-nfs.yaml

# Verify PVC is bound
kubectl get pv,pvc
# Should show STATUS: Bound

# Deploy the application
kubectl apply -f k3s/deployment.yaml

# Check pod status
kubectl get pods -l app=mqtt-monitor
```

## Step 5: Verify Deployment

### Check pod is running:
```bash
kubectl get pods -l app=mqtt-monitor

# Should show STATUS: Running
```

### View logs:
```bash
# Follow logs in real-time
kubectl logs -f deployment/mqtt-monitor

# Expected output:
# Home Weather Station Data Hub initialized
# Broker: mqtt.example.local:1883
# Topic: sensor/device/+/data
# Elevation: 600 feet (sea level pressure conversion enabled)
# RRD: /data/rrd/sensors.rrd
# ================================================================================
# [timestamp] Connected to MQTT broker
# [timestamp] Subscribed to topic: sensor/device/+/data
```

When sensor data arrives, you should see:
```
[timestamp] Topic: sensor/device/ABC123/data
Device MAC: AA:BB:CC:DD:EE:FF
Temperature: 21.50°C (70.70°F)
Humidity:    45.30%
Pressure:    980.50 hPa (station), 1002.50 hPa (sea level)
Battery:     3.25V
RRD updated successfully
```

## Step 6: Verify RRD Updates

### Check RRD from the pod:
```bash
POD_NAME=$(kubectl get pods -l app=mqtt-monitor -o jsonpath='{.items[0].metadata.name}')

# Check last update time
kubectl exec $POD_NAME -- rrdtool lastupdate /data/rrd/sensors.rrd

# View RRD info
kubectl exec $POD_NAME -- rrdtool info /data/rrd/sensors.rrd
```

### Or check directly on NAS:
```bash
# If you have the NFS share mounted or SSH access to NAS
rrdtool lastupdate /mnt/ssd/k3s/mqtt-monitor/sensors.rrd
```

## Managing the Application

### Update configuration:
```bash
# Edit ConfigMap
kubectl edit configmap mqtt-monitor-config

# Restart deployment to pick up changes
kubectl rollout restart deployment/mqtt-monitor
```

### View logs:
```bash
kubectl logs -f deployment/mqtt-monitor
```

### Check resource usage:
```bash
kubectl top pod -l app=mqtt-monitor
```

### Restart the deployment:
```bash
kubectl rollout restart deployment/mqtt-monitor
```

### Delete everything:
```bash
kubectl delete -f k3s/deployment.yaml
kubectl delete -f k3s/pv-pvc-nfs.yaml
kubectl delete -f k3s/configmap.yaml
```

## Troubleshooting

### Pod not starting:
```bash
kubectl describe pod -l app=mqtt-monitor
kubectl logs -l app=mqtt-monitor
```

### Image not found:
```bash
# List images in k3s
sudo k3s ctr images ls | grep mqtt

# If missing, re-import
docker save mqtt-monitor:latest -o mqtt-monitor.tar
sudo k3s ctr images import mqtt-monitor.tar
```

### NFS not mounting/PVC not binding:
```bash
# Check PVC and PV status
kubectl describe pvc mqtt-monitor-rrd-pvc
kubectl describe pv mqtt-monitor-rrd-pv

# Common issues:
# - NFS server IP/hostname incorrect in pv-pvc-nfs.yaml
# - NFS export not configured on server
# - Firewall blocking NFS ports (2049, 111)
# - no_root_squash not set in NFS exports

# Test NFS mount manually from a k3s node:
sudo mount -t nfs <NAS_IP>:/mnt/ssd/k3s/mqtt-monitor /mnt/test
ls -la /mnt/test
sudo umount /mnt/test
```

### Permission denied on RRD file:
```bash
# On NFS server, check permissions
ls -la /mnt/ssd/k3s/mqtt-monitor/

# Fix ownership
sudo chown -R nobody:nogroup /mnt/ssd/k3s/mqtt-monitor/
sudo chmod 755 /mnt/ssd/k3s/mqtt-monitor/

# If RRD file exists, ensure it's writable
sudo chmod 644 /mnt/ssd/k3s/mqtt-monitor/sensors.rrd
```

### Can't connect to MQTT broker:
```bash
# Test connectivity from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- nc -zv mqtt.example.local 1883

# Check ConfigMap settings
kubectl get configmap mqtt-monitor-config -o yaml
```

### RRD not updating:
```bash
# Check pod logs for errors
kubectl logs -l app=mqtt-monitor | grep -i error

# Exec into pod to debug
kubectl exec -it $POD_NAME -- sh
ls -la /data/rrd/
rrdtool info /data/rrd/sensors.rrd
```

## Next Steps

Consider adding:
- **Web UI pod** to generate and serve RRD graphs
- **Ingress** for external access to graphs (k3s includes Traefik)
- **Horizontal Pod Autoscaling** (though single replica is typical for RRD writes)
- **Monitoring** with Prometheus metrics
- **Backup automation** for RRD data on NAS

## Learning Points

This deployment demonstrates:

1. **Containerization** - Building and managing Docker images in k3s
2. **ConfigMaps** - Externalizing configuration from container images
3. **PersistentVolumes** - Using NFS for stateful storage
4. **Deployments** - Declarative application management
5. **Resource limits** - Controlling CPU and memory usage
6. **NFS integration** - Connecting k3s to network storage
7. **Troubleshooting** - Debugging k3s deployments
