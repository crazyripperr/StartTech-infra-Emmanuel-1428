#!/bin/bash
# This script runs automatically when an EC2 instance first starts up.
# Think of it as the "setup instructions" for a brand new server.

set -e

# Update the system
apt-get update -y
apt-get upgrade -y

# Install Docker (needed to run our containerised Golang app)
apt-get install -y docker.io curl wget unzip

systemctl start docker
systemctl enable docker

# Install CloudWatch Agent (sends logs to AWS CloudWatch)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/starttech-backend.log",
            "log_group_name": "/starttech/backend",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWCONFIG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Write environment variables for the app
cat > /etc/starttech.env << EOF
MONGO_URI=${mongo_uri}
REDIS_ADDR=${redis_endpoint}:6379
FRONTEND_URL=https://${frontend_url}
PORT=8080
EOF

# Create a systemd service to start/restart the Docker container automatically
cat > /etc/systemd/system/starttech-backend.service << 'SYSTEMD'
[Unit]
Description=StartTech Backend API
After=docker.service
Requires=docker.service

[Service]
Restart=always
RestartSec=5
EnvironmentFile=/etc/starttech.env
ExecStartPre=-/usr/bin/docker stop starttech-backend
ExecStartPre=-/usr/bin/docker rm starttech-backend
ExecStartPre=/usr/bin/docker pull crazyripperr/starttech-backend:latest
ExecStart=/usr/bin/docker run \
  --name starttech-backend \
  --env-file /etc/starttech.env \
  -p 8080:8080 \
  --log-driver=json-file \
  --log-opt max-size=10m \
  crazyripperr/starttech-backend:latest
StandardOutput=append:/var/log/starttech-backend.log
StandardError=append:/var/log/starttech-backend.log

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable starttech-backend
systemctl start starttech-backend

echo "✅ StartTech backend setup complete!"
