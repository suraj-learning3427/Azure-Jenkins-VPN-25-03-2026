# Updated Azure Infrastructure Architecture

## Overview
The Azure infrastructure has been updated to match the new requirements:

1. **Single Jenkins VM** - No high availability or load balancer needed
2. **Multi-Region Firezone VPN Gateways** - Two Firezone gateways in different regions with load balancer
3. **Rocky Linux for Jenkins** - Jenkins application installed on data disk

## Architecture Components

### 1. Single Jenkins VM
- **Location**: Primary region (East US)
- **OS**: Rocky Linux (latest)
- **Installation**: Jenkins installed on data disk (`/jenkins/jenkins_home`)
- **VM Size**: Standard_D2s_v3
- **Network**: Connected to spoke VNet subnet-jenkins

### 2. Multi-Region Firezone VPN Gateways
- **Primary Gateway**: East US region
- **Secondary Gateway**: West US 2 region
- **Load Balancer**: Azure Standard Load Balancer with public IP
- **Protocols**: WireGuard (UDP 51820) and Health Check (HTTP 8080)
- **OS**: Ubuntu 22.04 LTS (Firezone recommended)

### 3. Network Architecture
```
Hub VNet (172.16.0.0/16) - East US
├── VPN Gateway Subnet (if enabled)
└── Peered to Spoke VNets

Primary Spoke VNet (192.168.0.0/16) - East US
├── subnet-jenkins (192.168.0.0/24) - Jenkins VM
├── subnet-appgw (192.168.128.0/23) - Application Gateway
└── subnet-vpn (192.168.130.0/24) - Firezone Gateway

Secondary Spoke VNet (10.168.0.0/16) - West US 2
├── subnet-jenkins (10.168.0.0/24) - Future Jenkins (not used)
└── subnet-vpn (10.168.130.0/24) - Firezone Gateway
```

## Key Changes Made

### 1. Updated main.tf
- Removed multi-region Jenkins deployment
- Added multi-region Firezone deployment
- Updated module dependencies

### 2. Added VPN Subnets
- Added `subnet-vpn` to both primary and secondary infrastructure
- Updated variables and outputs for VPN subnets

### 3. New Variables
- `firezone_token` - Required for Firezone gateway authentication
- `enable_firezone_multi_region` - Controls Firezone deployment (default: true)
- `vpn_subnet_cidr` and `secondary_vpn_subnet_cidr` - VPN subnet ranges

### 4. Jenkins VM Configuration
- Already configured for Rocky Linux
- Jenkins installed on data disk (`/jenkins/jenkins_home`)
- Startup script handles disk formatting and Jenkins installation

## Deployment Steps

### Step 1: Add Firezone Token to Terraform Cloud
```bash
# In Terraform Cloud workspace, add sensitive variable:
# Variable name: firezone_token
# Value: [Your Firezone portal token]
# Sensitive: Yes
```

### Step 2: Deploy Infrastructure (Sequential)
```hcl
# Current main.tf is configured for step-by-step deployment:
# 1. Hub network (already deployed)
# 2. Spoke network with VPN subnet (ready to deploy)
# 3. Jenkins VM (ready to deploy)
# 4. Firezone multi-region (ready to deploy)
```

### Step 3: Verify Deployment
1. Check Jenkins VM is running Rocky Linux
2. Verify Jenkins is installed on data disk
3. Confirm Firezone gateways are registered with portal
4. Test load balancer connectivity

## Next Steps

1. **Add Firezone Token**: Add the `firezone_token` variable to Terraform Cloud workspace
2. **Deploy Step 2**: Apply Terraform to create spoke network with VPN subnet
3. **Deploy Step 3**: Apply Terraform to create Jenkins VM
4. **Deploy Step 4**: Apply Terraform to create Firezone multi-region deployment
5. **Configure Firezone**: Complete Firezone portal configuration
6. **Test Connectivity**: Verify VPN connectivity through load balancer

## Important Notes

- Jenkins VM uses Rocky Linux with 64GB OS disk (minimum required)
- Firezone gateways use Ubuntu 22.04 LTS (Firezone recommended)
- Load balancer provides high availability for Firezone VPN access
- VNet peering connects primary and secondary regions
- DNS zone uses `dglearn.online` domain

## Files Modified

- `main.tf` - Updated architecture
- `variables.tf` - Added Firezone variables
- `outputs.tf` - Updated outputs for Firezone
- `azure-core-infrastructure/main.tf` - Added VPN subnet
- `azure-core-infrastructure/variables.tf` - Added VPN subnet variable
- `azure-core-infrastructure/outputs.tf` - Added VPN subnet output
- `azure-core-infrastructure-secondary/main.tf` - Added VPN subnet
- `azure-core-infrastructure-secondary/variables.tf` - Added VPN subnet variable
- `azure-core-infrastructure-secondary/outputs.tf` - Added VPN subnet output

The infrastructure is now ready for the updated requirements with single Jenkins VM and multi-region Firezone VPN gateways.