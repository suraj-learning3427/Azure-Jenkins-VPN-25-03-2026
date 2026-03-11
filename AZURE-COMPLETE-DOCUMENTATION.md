# Azure Jenkins POC - Complete Documentation

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Component Details](#component-details)
4. [Security Implementation](#security-implementation)
5. [Deployment Guide](#deployment-guide)
6. [Operations Manual](#operations-manual)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [Cost Analysis](#cost-analysis)
9. [Best Practices](#best-practices)
10. [Migration Guide](#migration-guide)

---

## Executive Summary

### Project Overview

This document provides comprehensive documentation for deploying a secure Jenkins CI/CD infrastructure on Microsoft Azure using Infrastructure as Code (Terraform). The solution implements enterprise-grade security, scalability, and operational excellence principles.

### Key Achievements

- **Zero External Exposure**: All compute resources are private with no public IP addresses
- **Enterprise Security**: Azure Bastion for secure access, HTTPS encryption, network segmentation
- **High Availability**: Load-balanced architecture with health monitoring
- **Cost Effective**: Optimized resource sizing with estimated monthly cost of $134
- **Fully Automated**: Complete Infrastructure as Code implementation

### Business Value

- **Reduced Security Risk**: Private infrastructure with defense-in-depth security
- **Faster Time to Market**: Automated CI/CD pipeline for application deployments
- **Operational Efficiency**: Standardized, repeatable infrastructure deployment
- **Cost Control**: Predictable monthly costs with optimization opportunities

---

## Architecture Overview

### High-Level Design

The Azure Jenkins POC implements a hub-spoke network architecture with the following key components:

```
┌─────────────────────────────────────────────────────────┐
│                    EXTERNAL ACCESS                       │
│                                                          │
│  ┌─────────────────┐    ┌─────────────────────────────┐ │
│  │  VPN Gateway    │    │     Azure Bastion           │ │
│  │  (Optional)     │    │   (Secure Access)           │ │
│  └─────────────────┘    └─────────────────────────────┘ │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│              HUB VNET (20.20.0.0/16)                    │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐│
│  │  Subnets:                                           ││
│  │  • subnet-vpn (20.20.0.0/24)                       ││
│  │  • GatewaySubnet (20.20.1.0/24)                    ││
│  │  • AzureBastionSubnet (20.20.2.0/24)               ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────┬───────────────────────────────────┘
                      │ VNet Peering
┌─────────────────────▼───────────────────────────────────┐
│             SPOKE VNET (10.10.0.0/16)                   │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐│
│  │  Private DNS Zone: dreamcompany.intranet            ││
│  │  A Record: jenkins.np → 10.129.0.50                ││
│  └─────────────────────────────────────────────────────┘│
│                      ↓                                   │
│  ┌─────────────────────────────────────────────────────┐│
│  │  Application Gateway (10.129.0.50)                 ││
│  │  • HTTPS Termination (Key Vault Certificate)       ││
│  │  • Health Probes (/login)                          ││
│  │  • Backend Pool → Jenkins VM                       ││
│  └─────────────────────┬───────────────────────────────┘│
│                        │                                 │
│  ┌─────────────────────▼───────────────────────────────┐│
│  │  Jenkins VM (Standard_D2s_v3)                      ││
│  │  • RHEL 9 Operating System                         ││
│  │  • Jenkins on port 8080                            ││
│  │  • Data disk mounted at /jenkins                   ││
│  │  • Private IP only                                 ││
│  └─────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────┘
```

### Network Flow

1. **External Access**: Users connect via VPN Gateway or direct VNet access
2. **Name Resolution**: Private DNS resolves `jenkins.np.dreamcompany.intranet` to `10.129.0.50`
3. **Load Balancing**: Application Gateway terminates SSL and forwards to Jenkins VM
4. **Backend Processing**: Jenkins VM processes requests and returns responses

### Security Layers

1. **Network Isolation**: Hub-spoke VNet design with no public IPs on VMs
2. **Access Control**: Azure Bastion for secure administrative access
3. **Encryption**: HTTPS with Key Vault managed certificates
4. **Firewall**: Network Security Groups with least-privilege rules
5. **Identity**: User Assigned Identities for service authentication

---

## Component Details

### 1. Azure Networking Global (Hub)

**Purpose**: Central network hub for connectivity and shared services

**Resources Created**:
- Resource Group: `{prefix}networking-global-rg`
- Virtual Network: `{prefix}vpc-hub` (20.20.0.0/16)
- Subnets:
  - `subnet-vpn` (20.20.0.0/24)
  - `GatewaySubnet` (20.20.1.0/24)
  - `AzureBastionSubnet` (20.20.2.0/24)
- Network Security Group: `{prefix}hub-nsg`
- Azure Bastion: `{prefix}bastion`
- VPN Gateway: `{prefix}vpn-gateway` (optional)

**Configuration**:
```hcl
# terraform.tfvars
name_prefix = "mycompany-"
location    = "East US"
enable_bastion = true
enable_vpn_gateway = false
hub_address_space = "20.20.0.0/16"
```

### 2. Azure Core Infrastructure (Spoke)

**Purpose**: Application workload network with Jenkins infrastructure

**Resources Created**:
- Resource Group: `{prefix}core-infrastructure-rg`
- Virtual Network: `{prefix}vpc-spoke` (10.10.0.0/16)
- Subnets:
  - `subnet-jenkins` (10.10.0.0/24)
  - `subnet-appgw` (10.129.0.0/23)
- Network Security Groups: `{prefix}jenkins-nsg`, `{prefix}appgw-nsg`
- VNet Peering: Spoke ↔ Hub
- Private DNS Zone: `dreamcompany.intranet`

**Configuration**:
```hcl
# terraform.tfvars
name_prefix = "mycompany-"
location    = "East US"
spoke_address_space = "10.10.0.0/16"
enable_hub_peering = true
hub_vnet_id = "/subscriptions/.../virtualNetworks/mycompany-vpc-hub"
```

### 3. Azure Jenkins VM

**Purpose**: Jenkins CI/CD server with persistent data storage

**Resources Created**:
- Linux Virtual Machine: `jenkins-server`
- Network Interface: `{prefix}jenkins-nic`
- User Assigned Identity: `{prefix}jenkins-identity`
- OS Disk: 30GB Premium_LRS
- Data Disk: 20GB Premium_LRS (mounted at `/jenkins`)

**VM Specifications**:
- **Size**: Standard_D2s_v3 (2 vCPU, 8GB RAM)
- **OS**: RHEL 9 (Red Hat Enterprise Linux)
- **Jenkins**: Latest LTS version
- **Java**: OpenJDK 17
- **Storage**: Separate data disk for Jenkins home

**Configuration**:
```hcl
# terraform.tfvars
name_prefix = "mycompany-"
vm_size = "Standard_D2s_v3"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."
jenkins_port = 8080
```

### 4. Azure Jenkins Application Gateway

**Purpose**: Internal HTTPS load balancer with SSL termination

**Resources Created**:
- Application Gateway: `{prefix}jenkins-appgw`
- Key Vault: `{prefix}jenkins-kv-{random}`
- SSL Certificate: Self-signed certificate in Key Vault
- User Assigned Identity: `{prefix}appgw-identity`
- Public IP: `{prefix}jenkins-appgw-pip` (optional)

**Application Gateway Configuration**:
- **SKU**: Standard_v2 (2 instances)
- **Frontend**: HTTPS (443) and HTTP (80)
- **Backend**: Jenkins VM on port 8080
- **Health Probe**: HTTP GET /login every 30 seconds
- **SSL**: Key Vault managed certificate

**Configuration**:
```hcl
# terraform.tfvars
name_prefix = "mycompany-"
jenkins_private_ip = "10.10.0.4"  # From Jenkins VM deployment
static_private_ip = "10.129.0.50"
jenkins_fqdn = "jenkins.np.dreamcompany.intranet"
```

---

## Security Implementation

### Network Security

**Zero External Exposure**:
- No public IP addresses on compute resources
- All traffic flows through private networks
- VNet peering for controlled inter-network communication

**Network Security Groups (NSGs)**:
```bash
# Hub NSG Rules
Priority 1000: Allow Bastion SSH (VirtualNetwork → *)
Priority 1100: Allow WireGuard UDP 51820 (* → *)
Priority 1200: Allow Spoke HTTPS (10.10.0.0/16 → *)

# Jenkins NSG Rules
Priority 1000: Allow Bastion SSH (VirtualNetwork → *)
Priority 1100: Allow Hub HTTPS (20.20.0.0/16 → *)
Priority 1200: Allow AppGw Traffic (10.129.0.0/23 → 8080,80)
Priority 1300: Allow Azure Load Balancer (AzureLoadBalancer → *)

# Application Gateway NSG Rules
Priority 1000: Allow HTTPS 443 (* → *)
Priority 1100: Allow HTTP 80 (* → *)
Priority 1200: Allow Gateway Manager (GatewayManager → 65200-65535)
```

### Access Control

**Azure Bastion**:
- Secure RDP/SSH access without public IPs
- Azure AD authentication
- Session recording and auditing
- Just-in-time access capabilities

**User Assigned Identities**:
- Jenkins VM identity for Azure resource access
- Application Gateway identity for Key Vault access
- No shared secrets or passwords

### Encryption

**Data in Transit**:
- HTTPS encryption for all web traffic
- TLS 1.2+ enforced on Application Gateway
- SSH encryption for administrative access

**Data at Rest**:
- Azure Disk Encryption for VM disks
- Key Vault for certificate storage
- Encrypted storage accounts for backups

**Certificate Management**:
```bash
# Self-signed certificate in Key Vault
Subject: CN=jenkins.np.dreamcompany.intranet
Validity: 12 months
Key Size: 2048-bit RSA
Auto-renewal: 30 days before expiry
```

### Identity and Access Management

**Azure AD Integration**:
- Service principals for Terraform deployment
- User identities for administrative access
- Role-based access control (RBAC)

**Key Vault Access Policies**:
```json
{
  "Application Gateway Identity": {
    "certificates": ["Get", "List"],
    "secrets": ["Get", "List"]
  },
  "Deployment Service Principal": {
    "certificates": ["Create", "Delete", "Get", "Import", "List", "Update"],
    "secrets": ["Get", "List", "Set", "Delete"]
  }
}
```

---

## Deployment Guide

### Prerequisites

**Azure Environment**:
- Azure subscription with sufficient quota
- Resource Provider registrations
- Appropriate RBAC permissions

**Local Tools**:
- Azure CLI (>= 2.40.0)
- Terraform (>= 1.0)
- SSH key pair for VM access

### Step-by-Step Deployment

#### 1. Prepare Environment

```bash
# Login to Azure
az login
az account set --subscription "Your Subscription Name"

# Verify permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_jenkins_key
```

#### 2. Deploy Hub Network

```bash
cd Azure-code/azure-networking-global

# Configure variables
cat > terraform.tfvars <<EOF
name_prefix = "mycompany-"
location    = "East US"
enable_bastion = true
enable_vpn_gateway = false
tags = {
  Environment = "poc"
  Project     = "jenkins"
}
EOF

# Deploy
terraform init
terraform plan
terraform apply
```

#### 3. Deploy Spoke Network

```bash
cd ../azure-core-infrastructure

# Get Hub VNet ID
HUB_VNET_ID=$(cd ../azure-networking-global && terraform output -raw hub_virtual_network.id)

# Configure variables
cat > terraform.tfvars <<EOF
name_prefix = "mycompany-"
location    = "East US"
enable_hub_peering = true
hub_vnet_id = "$HUB_VNET_ID"
tags = {
  Environment = "poc"
  Project     = "jenkins"
}
EOF

# Deploy
terraform init
terraform plan
terraform apply
```

#### 4. Deploy Jenkins VM

```bash
cd ../azure-jenkins-vm

# Configure variables
cat > terraform.tfvars <<EOF
name_prefix = "mycompany-"
resource_group_name = "mycompany-core-infrastructure-rg"
vnet_name = "mycompany-vpc-spoke"
ssh_public_key = "$(cat ~/.ssh/azure_jenkins_key.pub)"
vm_size = "Standard_D2s_v3"
tags = {
  Environment = "poc"
  Project     = "jenkins"
}
EOF

# Deploy
terraform init
terraform plan
terraform apply
```

#### 5. Deploy Application Gateway

```bash
cd ../azure-jenkins-appgw

# Get Jenkins VM private IP
JENKINS_IP=$(cd ../azure-jenkins-vm && terraform output -raw jenkins_vm.private_ip_address)

# Configure variables
cat > terraform.tfvars <<EOF
name_prefix = "mycompany-"
resource_group_name = "mycompany-core-infrastructure-rg"
vnet_name = "mycompany-vpc-spoke"
jenkins_private_ip = "$JENKINS_IP"
static_private_ip = "10.129.0.50"
jenkins_fqdn = "jenkins.np.dreamcompany.intranet"
tags = {
  Environment = "poc"
  Project     = "jenkins"
}
EOF

# Deploy
terraform init
terraform plan
terraform apply
```

#### 6. Configure DNS

```bash
# Add DNS A record
az network private-dns record-set a add-record \
  --resource-group mycompany-core-infrastructure-rg \
  --zone-name dreamcompany.intranet \
  --record-set-name jenkins.np \
  --ipv4-address 10.129.0.50
```

### Verification Steps

**Network Connectivity**:
```bash
# Test from Hub VNet (via Bastion)
nslookup jenkins.np.dreamcompany.intranet
curl -k https://jenkins.np.dreamcompany.intranet
```

**Application Gateway Health**:
```bash
az network application-gateway show-backend-health \
  --resource-group mycompany-core-infrastructure-rg \
  --name mycompany-jenkins-appgw
```

**Jenkins Service**:
```bash
# Connect to Jenkins VM via Bastion
sudo systemctl status jenkins
curl -I http://localhost:8080
```

---

## Operations Manual

### Daily Operations

**Health Monitoring**:
- Check Application Gateway backend health
- Monitor VM resource utilization
- Review Jenkins build queue and job status
- Verify SSL certificate validity

**Backup Verification**:
- Confirm daily snapshots completed
- Test backup restoration procedures
- Verify Jenkins configuration backup

### Weekly Operations

**Security Updates**:
- Apply OS security patches
- Update Jenkins and plugins
- Review access logs and audit trails
- Rotate SSH keys if needed

**Performance Review**:
- Analyze resource utilization trends
- Review Application Gateway metrics
- Optimize Jenkins job configurations
- Plan capacity adjustments

### Monthly Operations

**Cost Review**:
- Analyze Azure cost reports
- Identify optimization opportunities
- Review resource utilization
- Plan budget adjustments

**Disaster Recovery Testing**:
- Test backup restoration
- Verify failover procedures
- Update disaster recovery documentation
- Train team on recovery procedures

### Monitoring and Alerting

**Azure Monitor Metrics**:
```bash
# VM Metrics
- CPU Percentage
- Memory Available
- Disk Read/Write IOPS
- Network In/Out

# Application Gateway Metrics
- Request Count
- Failed Requests
- Response Time
- Backend Response Time
- Healthy Host Count
```

**Alert Rules**:
```json
{
  "VM CPU > 80%": "Critical",
  "VM Memory < 10%": "Critical", 
  "Disk Space > 90%": "Warning",
  "Application Gateway Failed Requests > 5%": "Critical",
  "Backend Health < 100%": "Warning"
}
```

### Backup and Recovery

**Automated Backups**:
```bash
# Daily VM backup
az backup protection enable-for-vm \
  --resource-group mycompany-core-infrastructure-rg \
  --vault-name mycompany-backup-vault \
  --vm jenkins-server \
  --policy-name DailyPolicy

# Daily disk snapshots
az snapshot create \
  --resource-group mycompany-core-infrastructure-rg \
  --name jenkins-data-snapshot-$(date +%Y%m%d) \
  --source mycompany-jenkins-data-disk
```

**Recovery Procedures**:
1. Create new VM from backup
2. Attach restored data disk
3. Update Application Gateway backend pool
4. Update DNS records
5. Test connectivity and functionality

---

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Jenkins Service Not Starting

**Symptoms**:
- Jenkins web interface not accessible
- Service status shows failed or inactive

**Diagnosis**:
```bash
# Check service status
sudo systemctl status jenkins

# Check logs
sudo journalctl -u jenkins -f

# Check disk space
df -h /jenkins

# Check Java process
ps aux | grep java
```

**Solutions**:
```bash
# Restart service
sudo systemctl restart jenkins

# Fix permissions
sudo chown -R jenkins:jenkins /jenkins/jenkins_home

# Increase Java heap size
sudo systemctl edit jenkins
# Add: Environment="JAVA_OPTS=-Xmx4g -Xms2g"

# Check firewall
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

#### 2. Application Gateway Backend Unhealthy

**Symptoms**:
- 502 Bad Gateway errors
- Backend health shows unhealthy

**Diagnosis**:
```bash
# Check backend health
az network application-gateway show-backend-health \
  --resource-group mycompany-core-infrastructure-rg \
  --name mycompany-jenkins-appgw

# Test health endpoint directly
curl -I http://<jenkins-private-ip>:8080/login

# Check NSG rules
az network nsg rule list \
  --resource-group mycompany-core-infrastructure-rg \
  --nsg-name mycompany-jenkins-nsg
```

**Solutions**:
```bash
# Restart Jenkins service
sudo systemctl restart jenkins

# Update health probe configuration
az network application-gateway probe update \
  --resource-group mycompany-core-infrastructure-rg \
  --gateway-name mycompany-jenkins-appgw \
  --name jenkins-health-probe \
  --path /login \
  --timeout 30

# Check and fix NSG rules
az network nsg rule create \
  --resource-group mycompany-core-infrastructure-rg \
  --nsg-name mycompany-jenkins-nsg \
  --name AllowAppGwHealth \
  --priority 1250 \
  --source-address-prefixes 10.129.0.0/23 \
  --destination-port-ranges 8080 \
  --access Allow \
  --protocol Tcp
```

#### 3. DNS Resolution Issues

**Symptoms**:
- Cannot resolve jenkins.np.dreamcompany.intranet
- Name resolution timeouts

**Diagnosis**:
```bash
# Check DNS zone
az network private-dns zone show \
  --resource-group mycompany-core-infrastructure-rg \
  --name dreamcompany.intranet

# Check DNS records
az network private-dns record-set a show \
  --resource-group mycompany-core-infrastructure-rg \
  --zone-name dreamcompany.intranet \
  --name jenkins.np

# Check VNet links
az network private-dns zone list \
  --resource-group mycompany-core-infrastructure-rg
```

**Solutions**:
```bash
# Create missing DNS record
az network private-dns record-set a add-record \
  --resource-group mycompany-core-infrastructure-rg \
  --zone-name dreamcompany.intranet \
  --record-set-name jenkins.np \
  --ipv4-address 10.129.0.50

# Link DNS zone to VNet
az network private-dns zone create \
  --resource-group mycompany-core-infrastructure-rg \
  --name dreamcompany.intranet

az network private-dns zone virtual-network-link create \
  --resource-group mycompany-core-infrastructure-rg \
  --zone-name dreamcompany.intranet \
  --name spoke-link \
  --virtual-network mycompany-vpc-spoke \
  --registration-enabled false
```

#### 4. SSL Certificate Issues

**Symptoms**:
- SSL certificate warnings
- HTTPS connections failing

**Diagnosis**:
```bash
# Check certificate in Key Vault
az keyvault certificate show \
  --vault-name mycompany-jenkins-kv-* \
  --name jenkins-ssl-cert

# Check certificate expiry
openssl s_client -connect jenkins.np.dreamcompany.intranet:443 -servername jenkins.np.dreamcompany.intranet | openssl x509 -noout -dates
```

**Solutions**:
```bash
# Renew certificate
az keyvault certificate create \
  --vault-name mycompany-jenkins-kv-* \
  --name jenkins-ssl-cert \
  --policy @certificate-policy.json

# Update Application Gateway
az network application-gateway ssl-cert update \
  --resource-group mycompany-core-infrastructure-rg \
  --gateway-name mycompany-jenkins-appgw \
  --name jenkins-ssl-cert \
  --key-vault-secret-id https://mycompany-jenkins-kv-*.vault.azure.net/secrets/jenkins-ssl-cert
```

### Performance Troubleshooting

#### High CPU Usage

**Diagnosis**:
```bash
# Check CPU usage
top
htop
iostat -x 1

# Check Jenkins processes
ps aux | grep java
jstack <jenkins-pid>
```

**Solutions**:
- Increase VM size
- Optimize Jenkins job configurations
- Add Jenkins agents for distributed builds
- Tune JVM parameters

#### Memory Issues

**Diagnosis**:
```bash
# Check memory usage
free -h
cat /proc/meminfo

# Check Java heap usage
jstat -gc <jenkins-pid>
```

**Solutions**:
- Increase VM memory
- Tune Java heap size
- Optimize Jenkins plugins
- Enable swap if needed

#### Network Performance

**Diagnosis**:
```bash
# Check network usage
iftop
netstat -i
ss -tuln
```

**Solutions**:
- Upgrade VM network performance tier
- Optimize Application Gateway configuration
- Review network security group rules
- Consider accelerated networking

---

## Cost Analysis

### Current Cost Breakdown

**Monthly Costs (East US region)**:

| Resource | Specification | Monthly Cost |
|----------|--------------|--------------|
| Jenkins VM | Standard_D2s_v3 | $70 |
| OS Disk | 30GB Premium_LRS | $5 |
| Data Disk | 20GB Premium_LRS | $3 |
| Application Gateway | Standard_v2 (2 instances) | $35 |
| Key Vault | Standard tier | $1 |
| Private DNS Zone | 1 zone | $0.50 |
| Azure Bastion | Standard | $15 |
| Network Egress | ~50GB/month | $5 |
| **Total** | | **~$134** |

### Cost Optimization Strategies

**Short-term (0-3 months)**:
- Use Standard_LRS disks for non-production
- Schedule VM shutdown during off-hours
- Optimize Application Gateway capacity
- Review and remove unused resources

**Medium-term (3-12 months)**:
- Purchase Reserved Instances (30% savings)
- Implement auto-scaling for Application Gateway
- Use Azure Hybrid Benefit for Windows (if applicable)
- Optimize backup retention policies

**Long-term (12+ months)**:
- Consider Azure Spot VMs for Jenkins agents
- Implement multi-region deployment for HA
- Use Azure DevOps Services for some workloads
- Negotiate Enterprise Agreement pricing

### Cost Monitoring

**Azure Cost Management**:
```bash
# Set up budget alerts
az consumption budget create \
  --budget-name jenkins-poc-budget \
  --amount 200 \
  --time-grain Monthly \
  --time-period start-date=2026-03-01 \
  --notifications \
    enabled=true \
    operator=GreaterThan \
    threshold=80 \
    contact-emails=admin@company.com
```

**Cost Allocation Tags**:
```hcl
tags = {
  Environment = "poc"
  Project     = "jenkins"
  CostCenter  = "infrastructure"
  Owner       = "devops-team"
}
```

---

## Best Practices

### Security Best Practices

**Network Security**:
- Implement network segmentation with NSGs
- Use private endpoints for Azure services
- Enable DDoS protection for public IPs
- Regular security assessments and penetration testing

**Identity and Access**:
- Use Azure AD for authentication
- Implement just-in-time access
- Regular access reviews and cleanup
- Multi-factor authentication for all admin accounts

**Data Protection**:
- Enable encryption at rest and in transit
- Regular backup testing and validation
- Implement data retention policies
- Use Azure Key Vault for secrets management

### Operational Best Practices

**Monitoring and Alerting**:
- Comprehensive monitoring strategy
- Proactive alerting on key metrics
- Regular review of monitoring data
- Automated response to common issues

**Change Management**:
- Infrastructure as Code for all changes
- Peer review process for modifications
- Testing in non-production environments
- Rollback procedures for failed changes

**Documentation**:
- Keep documentation current and accurate
- Document all procedures and processes
- Regular training for team members
- Knowledge sharing sessions

### Performance Best Practices

**Resource Optimization**:
- Right-size resources based on usage
- Regular performance reviews
- Capacity planning and forecasting
- Load testing for performance validation

**Application Optimization**:
- Jenkins plugin optimization
- Job configuration best practices
- Build artifact management
- Pipeline optimization

---

## Migration Guide

### From GCP to Azure

**Architecture Mapping**:

| GCP Component | Azure Equivalent | Migration Notes |
|---------------|------------------|-----------------|
| VPC | Virtual Network | Similar concepts, different APIs |
| IAP | Azure Bastion | Different access methods |
| Internal HTTPS LB | Application Gateway | More features in Azure |
| Cloud DNS | Private DNS Zone | Similar functionality |
| Firewall Rules | Network Security Groups | Different rule structure |
| Service Account | User Assigned Identity | Different authentication model |
| Persistent Disk | Managed Disk | Similar performance tiers |

**Migration Steps**:

1. **Assessment Phase**:
   - Inventory existing GCP resources
   - Map to Azure equivalents
   - Identify migration challenges
   - Plan migration timeline

2. **Preparation Phase**:
   - Set up Azure environment
   - Create migration scripts
   - Test migration procedures
   - Train team on Azure

3. **Migration Phase**:
   - Deploy Azure infrastructure
   - Migrate Jenkins configuration
   - Update DNS and networking
   - Test functionality

4. **Cutover Phase**:
   - Switch traffic to Azure
   - Monitor performance
   - Resolve issues
   - Decommission GCP resources

### From On-Premises to Azure

**Assessment Checklist**:
- Current infrastructure inventory
- Network connectivity requirements
- Security and compliance needs
- Performance requirements
- Integration dependencies

**Migration Strategy**:
- Lift-and-shift vs. re-architecture
- Phased migration approach
- Hybrid connectivity options
- Data migration planning

---

## Appendices

### Appendix A: Terraform Variables Reference

**Global Variables**:
```hcl
variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region for deployment"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### Appendix B: Network Security Group Rules

**Hub NSG Rules**:
```json
{
  "AllowBastionSSH": {
    "priority": 1000,
    "direction": "Inbound",
    "access": "Allow",
    "protocol": "Tcp",
    "sourcePortRange": "*",
    "destinationPortRange": "22",
    "sourceAddressPrefix": "VirtualNetwork",
    "destinationAddressPrefix": "*"
  }
}
```

### Appendix C: Monitoring Queries

**Azure Monitor KQL Queries**:
```kql
// VM CPU Usage
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| where Computer == "jenkins-server"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m)

// Application Gateway Requests
AzureMetrics
| where ResourceProvider == "MICROSOFT.NETWORK"
| where MetricName == "TotalRequests"
| summarize sum(Total) by bin(TimeGenerated, 5m)
```

### Appendix D: Backup Scripts

**Automated Backup Script**:
```bash
#!/bin/bash
# Daily backup script for Jenkins

DATE=$(date +%Y%m%d)
RG_NAME="mycompany-core-infrastructure-rg"
DISK_NAME="mycompany-jenkins-data-disk"

# Create snapshot
az snapshot create \
  --resource-group $RG_NAME \
  --name jenkins-data-snapshot-$DATE \
  --source $DISK_NAME

# Cleanup old snapshots (keep 7 days)
az snapshot list --resource-group $RG_NAME \
  --query "[?contains(name, 'jenkins-data-snapshot-') && timeCreated < '$(date -d '7 days ago' -Iseconds)'].name" \
  --output tsv | xargs -I {} az snapshot delete --resource-group $RG_NAME --name {}
```

---

**Document**: Azure Complete Documentation  
**Version**: 1.0  
**Date**: March 10, 2026  
**Status**: Production Ready  
**Next Review**: June 10, 2026