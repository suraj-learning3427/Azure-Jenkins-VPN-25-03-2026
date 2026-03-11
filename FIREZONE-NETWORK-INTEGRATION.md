# Firezone VPN Network Integration Guide

## Overview

This document outlines the network configuration changes made to support Firezone VPN integration between GCP and Azure clouds. The CIDR ranges have been updated to avoid conflicts and enable seamless connectivity through Firezone VPN clients.

## Network Architecture for Multi-Cloud Connectivity

```
┌─────────────────────────────────────────────────────────────────┐
│                    FIREZONE VPN CLIENTS                         │
│                  (Remote Users/Devices)                         │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                 FIREZONE GATEWAY                                │
│              (Deployed in GCP Hub)                             │
│                20.20.0.0/16                                    │
└─────────────┬───────────────────────────────┬─────────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────────────┐    ┌─────────────────────────────┐
│        GCP CLOUD            │    │        AZURE CLOUD          │
│                             │    │                             │
│  Hub VPC: 20.20.0.0/16     │    │  Hub VNet: 172.16.0.0/16   │
│  ├─ Firezone Gateway        │    │  ├─ Azure Bastion           │
│  └─ VPN Subnet              │    │  └─ VPN Gateway (Optional)  │
│                             │    │                             │
│  Spoke VPC: 10.10.0.0/16   │    │  Spoke VNet: 192.168.0.0/16│
│  └─ Jenkins Server          │    │  └─ Jenkins Server          │
└─────────────────────────────┘    └─────────────────────────────┘
```

## Updated Network Ranges

### GCP Networks (Unchanged)
- **Hub VPC**: `20.20.0.0/16`
  - VPN Subnet: `20.20.0.0/16`
  - Firezone Gateway deployed here
- **Spoke VPC**: `10.10.0.0/16`
  - Jenkins Subnet: `10.10.0.0/16`
  - Jenkins Server: `10.10.10.50` (via Internal Load Balancer)

### Azure Networks (Updated)
- **Hub VNet**: `172.16.0.0/16` *(Changed from 20.20.0.0/16)*
  - VPN Subnet: `172.16.0.0/24`
  - Gateway Subnet: `172.16.1.0/24`
  - Bastion Subnet: `172.16.2.0/24`
- **Spoke VNet**: `192.168.0.0/16` *(Changed from 10.10.0.0/16)*
  - Jenkins Subnet: `192.168.0.0/24`
  - Application Gateway Subnet: `192.168.129.0/23`
  - Jenkins Server: `192.168.129.50` (via Application Gateway)

## Firezone VPN Configuration

### Route Configuration

**Firezone Gateway Routes** (to be configured in Firezone portal):
```
# GCP Routes (existing)
10.10.0.0/16 → GCP Spoke VPC (Jenkins)
20.20.0.0/16 → GCP Hub VPC (Internal)

# Azure Routes (new)
192.168.0.0/16 → Azure Spoke VNet (Jenkins)
172.16.0.0/16 → Azure Hub VNet (Internal)
```

### Client Access Patterns

**Remote Users via Firezone VPN**:
1. Connect to Firezone Gateway in GCP Hub (20.20.0.0/16)
2. Access GCP Jenkins: `https://jenkins.np.dreamcompany.intranet` → `10.10.10.50`
3. Access Azure Jenkins: `https://jenkins.azure.dreamcompany.intranet` → `192.168.129.50`

## DNS Configuration

### GCP Private DNS Zone
- **Zone**: `dreamcompany.intranet`
- **Records**:
  - `jenkins.np.dreamcompany.intranet` → `10.10.10.50`

### Azure Private DNS Zone
- **Zone**: `dreamcompany.intranet`
- **Records**:
  - `jenkins.azure.dreamcompany.intranet` → `192.168.129.50`

### Firezone DNS Configuration
Configure Firezone to use custom DNS servers:
- Primary: GCP DNS Forwarder IP
- Secondary: Azure DNS resolver IP
- Search domains: `dreamcompany.intranet`

## Security Considerations

### Network Segmentation
- **No Direct Inter-Cloud Connectivity**: Traffic flows through Firezone VPN
- **Isolated Address Spaces**: No CIDR overlap between clouds
- **Controlled Access**: All access via authenticated VPN clients

### Firewall Rules

**GCP Firewall Rules** (existing):
```
# Allow Firezone VPN traffic
allow-firezone-udp: UDP 51820 from 0.0.0.0/0

# Allow VPN client access to spoke
allow-vpn-to-spoke: TCP 443 from 20.20.0.0/16 to 10.10.0.0/16
```

**Azure Network Security Groups** (updated):
```
# Allow VPN client access from Firezone
AllowFirezoneAccess: TCP 443 from 20.20.0.0/16 to 192.168.0.0/16

# Allow hub-to-spoke communication
AllowHubTraffic: TCP 443 from 172.16.0.0/16 to 192.168.0.0/16
```

## Implementation Steps

### 1. Update Azure Infrastructure
```bash
# Update all Azure Terraform modules with new CIDR ranges
cd Azure-code/azure-networking-global
# Update terraform.tfvars with new hub_address_space = "172.16.0.0/16"
terraform plan
terraform apply

cd ../azure-core-infrastructure
# Update terraform.tfvars with new spoke_address_space = "192.168.0.0/16"
terraform plan
terraform apply

# Continue with other modules...
```

### 2. Configure Firezone Routes
In Firezone portal, add routes for Azure networks:
```
Destination: 192.168.0.0/16
Description: Azure Spoke VNet (Jenkins)

Destination: 172.16.0.0/16
Description: Azure Hub VNet (Management)
```

### 3. Update DNS Records
```bash
# Azure DNS
az network private-dns record-set a add-record \
  --resource-group mycompany-core-infrastructure-rg \
  --zone-name dreamcompany.intranet \
  --record-set-name jenkins.azure \
  --ipv4-address 192.168.129.50
```

### 4. Test Connectivity
```bash
# From Firezone VPN client
ping 10.10.10.50    # GCP Jenkins
ping 192.168.129.50 # Azure Jenkins

# Test HTTPS access
curl -k https://jenkins.np.dreamcompany.intranet     # GCP
curl -k https://jenkins.azure.dreamcompany.intranet  # Azure
```

## Monitoring and Troubleshooting

### Network Connectivity Tests
```bash
# From GCP Jenkins VM
ping 192.168.129.50  # Should fail (no direct connectivity)

# From Firezone VPN client
ping 10.10.10.50     # Should succeed
ping 192.168.129.50  # Should succeed
```

### Firezone Gateway Logs
Monitor Firezone gateway logs for routing and connectivity issues:
```bash
# On Firezone gateway VM
sudo journalctl -u firezone-gateway -f
```

### Azure Network Monitoring
```bash
# Check NSG flow logs
az network watcher flow-log show \
  --resource-group mycompany-core-infrastructure-rg \
  --name jenkins-nsg-flow-log

# Monitor Application Gateway metrics
az monitor metrics list \
  --resource /subscriptions/.../applicationGateways/mycompany-jenkins-appgw \
  --metric TotalRequests,FailedRequests
```

## Cost Impact

### Additional Costs for Multi-Cloud Setup
- **Firezone Gateway**: Already deployed in GCP
- **VPN Gateway** (Azure, optional): ~$25/month
- **Cross-cloud data transfer**: Minimal (only management traffic)
- **Additional DNS zones**: ~$0.50/month per zone

### Total Estimated Monthly Cost
- **GCP Infrastructure**: ~$82/month (existing)
- **Azure Infrastructure**: ~$134/month (updated ranges)
- **Multi-cloud connectivity**: ~$25/month (if VPN Gateway enabled)
- **Total**: ~$241/month for complete multi-cloud setup

## Best Practices

### Network Design
- **Consistent Naming**: Use similar naming conventions across clouds
- **Documentation**: Keep network diagrams and IP allocations updated
- **Monitoring**: Implement comprehensive network monitoring
- **Security**: Regular security reviews and access audits

### Operational Excellence
- **Automation**: Use Infrastructure as Code for all changes
- **Testing**: Regular connectivity and failover testing
- **Backup**: Document all network configurations
- **Training**: Ensure team understands multi-cloud networking

## Future Enhancements

### Potential Improvements
1. **Site-to-Site VPN**: Direct cloud-to-cloud connectivity
2. **Global Load Balancer**: Traffic distribution across clouds
3. **Multi-Region Deployment**: High availability across regions
4. **Zero Trust Architecture**: Enhanced security model

### Scaling Considerations
- **Additional Clouds**: AWS, Oracle Cloud integration
- **Multiple Regions**: Regional Firezone gateways
- **Performance Optimization**: CDN and edge locations
- **Cost Optimization**: Reserved instances and committed use

---

**Document**: Firezone Network Integration Guide  
**Version**: 1.0  
**Date**: March 10, 2026  
**Status**: Implementation Ready