# Basic Azure Firezone Gateway Deployment Example

This example demonstrates a basic deployment of Firezone Gateway on Azure, equivalent to the GCP NAT gateway example. It creates a complete network infrastructure with NAT Gateway for outbound connectivity.

## Architecture

```
Internet
    ↓
NAT Gateway (Outbound only)
    ↓
Virtual Network (10.0.0.0/16)
    ├── Gateway Subnet (10.0.1.0/24)
    │   └── Firezone Gateway VM Scale Set
    └── AppGW Subnet (10.0.2.0/24) [Optional]
        └── Application Gateway [If enabled]
```

## Features

- ✅ **Complete Network Setup**: VNet, subnets, NAT Gateway
- ✅ **Secure by Default**: No public IPs on VMs, outbound via NAT
- ✅ **Single Instance**: Perfect for development/testing
- ✅ **Auto-generated SSH Keys**: Optional key generation
- ✅ **Health Monitoring**: Built-in health checks

## Quick Start

1. **Configure Variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   nano terraform.tfvars
   ```

2. **Set Required Variables**:
   - `firezone_token`: Get from your Firezone portal
   - `ssh_public_key`: Your SSH public key (or leave empty to generate)

3. **Deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Get Connection Info**:
   ```bash
   terraform output connection_info
   ```

## Configuration Options

### Network Modes

**NAT Gateway Mode (Recommended)**:
```hcl
enable_nat_gateway = true
enable_public_ip   = false
```
- Secure outbound internet access
- No direct inbound access to VMs
- Cost-effective for single instance

**Public IP Mode**:
```hcl
enable_nat_gateway = false
enable_public_ip   = true
```
- Direct internet access to VMs
- Higher security risk
- Useful for testing/development

### Load Balancer

Enable for multiple instances:
```hcl
instance_count       = 3
enable_load_balancer = true
```

## Accessing the Gateway

### SSH Access
```bash
# If using generated key
terraform output -raw ssh_private_key > private_key.pem
chmod 600 private_key.pem

# Get VM instance IP
az vmss list-instance-public-ips --resource-group <rg-name> --name <vmss-name>

# SSH to instance
ssh -i private_key.pem azureuser@<instance-ip>
```

### Health Check
```bash
# If load balancer enabled
curl http://<public-ip>/healthz

# Direct to instance (if public IP enabled)
curl http://<instance-ip>:8080/healthz
```

## Monitoring

### Check Gateway Status
```bash
# SSH to instance and check service
sudo systemctl status firezone-gateway
sudo journalctl -u firezone-gateway -f
```

### Azure Monitor
- VM metrics available in Azure portal
- Application logs in Log Analytics (if configured)
- Health probe status in Application Gateway

## Troubleshooting

### Common Issues

1. **Gateway not starting**:
   ```bash
   # Check cloud-init logs
   sudo tail -f /var/log/cloud-init.log
   
   # Check Firezone service
   sudo systemctl status firezone-gateway
   sudo journalctl -u firezone-gateway
   ```

2. **Network connectivity**:
   ```bash
   # Check NAT Gateway association
   az network vnet subnet show --resource-group <rg> --vnet-name <vnet> --name gateway-subnet
   
   # Test outbound connectivity
   curl -I https://api.firezone.dev
   ```

3. **Health check failures**:
   ```bash
   # Test health endpoint locally
   curl localhost:8080/healthz
   
   # Check NSG rules
   az network nsg rule list --resource-group <rg> --nsg-name <nsg-name>
   ```

## Cost Optimization

### Development/Testing
```hcl
vm_size            = "Standard_B1s"    # Smallest size
instance_count     = 1                 # Single instance
enable_nat_gateway = true              # Cheaper than public IPs
```

### Production
```hcl
vm_size              = "Standard_B2s"  # Balanced performance
instance_count       = 2               # High availability
enable_load_balancer = true            # Load distribution
```

## Security Considerations

1. **Network Isolation**: Uses private subnets with NAT Gateway
2. **SSH Keys**: Use strong SSH keys, rotate regularly
3. **NSG Rules**: Minimal required ports only
4. **Updates**: Regular OS and application updates
5. **Monitoring**: Enable Azure Security Center

## Cleanup

```bash
terraform destroy
```

This will remove all created resources including:
- Virtual Machine Scale Set
- Virtual Network and subnets
- NAT Gateway and public IP
- Network Security Groups
- Resource Group

## Next Steps

1. **Production Setup**: Review security and scaling requirements
2. **Monitoring**: Set up Azure Monitor and Log Analytics
3. **Backup**: Configure VM backup policies
4. **Updates**: Set up automatic OS updates
5. **Integration**: Connect to existing Azure infrastructure