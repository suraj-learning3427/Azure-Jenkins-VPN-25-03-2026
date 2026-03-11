#!/bin/bash
# Jenkins Installation Script for Azure VM (Rocky Linux/RHEL equivalent)
# Equivalent to GCP startup script

set -e

# Log all output
exec > >(tee -a /var/log/jenkins-startup.log)
exec 2>&1

echo "Starting Jenkins VM setup..."
echo "Timestamp: $(date)"

# Wait for the data disk to be available
echo "Waiting for data disk..."
DISK_DEVICE="${data_disk_device}"
MOUNT_POINT="${mount_point}"
JENKINS_PORT="${jenkins_port}"

# Wait up to 60 seconds for disk to appear
for i in {1..30}; do
    if [ -e "$DISK_DEVICE" ]; then
        echo "Data disk found: $DISK_DEVICE"
        break
    fi
    echo "Waiting for data disk... ($i/30)"
    sleep 2
done

if [ ! -e "$DISK_DEVICE" ]; then
    echo "ERROR: Data disk not found at $DISK_DEVICE"
    exit 1
fi

# Format and mount the data disk
echo "Setting up data disk..."

# Check if the disk is already formatted
if ! blkid "$DISK_DEVICE"; then
    echo "Formatting data disk..."
    mkfs.ext4 -F "$DISK_DEVICE"
else
    echo "Data disk already formatted"
fi

# Create mount point
mkdir -p "$MOUNT_POINT"

# Mount the disk
mount "$DISK_DEVICE" "$MOUNT_POINT"

# Add to fstab for persistent mounting
UUID=$(blkid -s UUID -o value "$DISK_DEVICE")
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
    echo "Added disk to fstab"
fi

echo "Data disk mounted at $MOUNT_POINT"

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y wget curl java-17-openjdk java-17-openjdk-devel

# Set JAVA_HOME
echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk" >> /etc/environment
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk

# Install Jenkins
echo "Installing Jenkins..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins

# Configure Jenkins to use the data disk
echo "Configuring Jenkins..."
systemctl stop jenkins || true

# Create Jenkins directory on data disk
mkdir -p "$MOUNT_POINT/jenkins_home"
chown -R jenkins:jenkins "$MOUNT_POINT/jenkins_home"

# Update Jenkins configuration
JENKINS_SERVICE_FILE="/usr/lib/systemd/system/jenkins.service"
if [ -f "$JENKINS_SERVICE_FILE" ]; then
    # Update JENKINS_HOME in service file
    sed -i "s|Environment=\"JENKINS_HOME=/var/lib/jenkins\"|Environment=\"JENKINS_HOME=$MOUNT_POINT/jenkins_home\"|" "$JENKINS_SERVICE_FILE"
    
    # Update JENKINS_PORT if not default
    if [ "$JENKINS_PORT" != "8080" ]; then
        sed -i "s|Environment=\"JENKINS_PORT=8080\"|Environment=\"JENKINS_PORT=$JENKINS_PORT\"|" "$JENKINS_SERVICE_FILE"
    fi
fi

# Create systemd override directory and configuration
mkdir -p /etc/systemd/system/jenkins.service.d

# Configure Jenkins to run on specified port
cat > /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="JENKINS_PORT=$JENKINS_PORT"
Environment="JENKINS_HOME=$MOUNT_POINT/jenkins_home"
EOF

# If running on privileged port (< 1024), add capability
if [ "$JENKINS_PORT" -lt 1024 ]; then
    echo "AmbientCapabilities=CAP_NET_BIND_SERVICE" >> /etc/systemd/system/jenkins.service.d/override.conf
    
    # Give Java permission to bind to privileged ports
    JAVA_PATH=$(readlink -f /usr/bin/java)
    setcap 'cap_net_bind_service=+ep' "$JAVA_PATH"
    echo "Configured Java for privileged port binding"
fi

# Configure firewall
echo "Configuring firewall..."
systemctl enable firewalld
systemctl start firewalld

# Open Jenkins port
firewall-cmd --permanent --add-port="$JENKINS_PORT/tcp"
firewall-cmd --reload

echo "Firewall configured for port $JENKINS_PORT"

# Reload systemd and start Jenkins
echo "Starting Jenkins service..."
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
for i in {1..30}; do
    if systemctl is-active --quiet jenkins; then
        echo "Jenkins service is active"
        break
    fi
    echo "Waiting for Jenkins service... ($i/30)"
    sleep 5
done

# Wait for Jenkins web interface to be ready
echo "Waiting for Jenkins web interface..."
for i in {1..60}; do
    if curl -s -o /dev/null -w "%%{http_code}" "http://localhost:$JENKINS_PORT" | grep -q "200\|403"; then
        echo "Jenkins web interface is ready"
        break
    fi
    echo "Waiting for Jenkins web interface... ($i/60)"
    sleep 5
done

# Display Jenkins information
echo "Jenkins installation completed!"
echo "Jenkins is running on port $JENKINS_PORT"
echo "Jenkins home directory: $MOUNT_POINT/jenkins_home"
echo "Initial admin password location: $MOUNT_POINT/jenkins_home/secrets/initialAdminPassword"

# Try to display initial admin password
if [ -f "$MOUNT_POINT/jenkins_home/secrets/initialAdminPassword" ]; then
    echo "Initial admin password: $(cat $MOUNT_POINT/jenkins_home/secrets/initialAdminPassword)"
else
    echo "Initial admin password not yet available. Check again in a few minutes."
fi

# Log system status
echo "System status:"
echo "- Jenkins service: $(systemctl is-active jenkins)"
echo "- Disk usage: $(df -h $MOUNT_POINT)"
echo "- Memory usage: $(free -h)"

echo "Jenkins VM setup completed successfully!"
echo "Timestamp: $(date)"