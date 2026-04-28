# IPMI Power Exporter

A bash script that collects IPMI power metrics and uploads them to an S3-compatible storage as Prometheus metrics.

## How It Works

The script:
1. Uses `ipmitool` to retrieve hardware information (manufacturer, product name)
2. Gets the instantaneous power reading via IPMI DCMI
3. Formats the data as Prometheus metrics
4. Uploads to S3-compatible storage using AWS signature authentication

## Requirements

- `ipmitool` - For IPMI hardware access
- `openssl` - For AWS signature generation
- `curl` - For S3 upload
- S3-compatible storage with AWS signature support

## Configuration

Copy [`ipmi-power-exporter.conf.example`](ipmi-power-exporter.conf.example) to `/etc/ipmi-power-exporter.conf` and configure the S3 credentials.

## Output Format

The script outputs Prometheus metrics in this format:

```
# HELP power Current power draw
# TYPE power counter
power{manufacturer="Dell", product="PowerEdge R740", host="server01", unit="Watt"} 245
```

## Systemd Setup

### Install Timer and Service

```bash
sudo cp ipmi-power-exporter.service /etc/systemd/system/
sudo cp ipmi-power-exporter.timer /etc/systemd/system/
sudo chmod +x /usr/bin/ipmi-power-exporter
sudo systemctl daemon-reload
sudo systemctl enable --now ipmi-power-exporter.timer
```

### Verify

```bash
systemctl status ipmi-power-exporter.timer
```

The timer runs every minute to collect and upload power metrics.
