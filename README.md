<<<<<<< HEAD
# Azure Firezone Gateway Terraform Module

This Terraform module deploys Firezone Gateway on Azure, equivalent to the GCP terraform-google-gateway module. It creates a Virtual Machine Scale Set running Ubuntu with Firezone Gateway installed and configured.

## Architecture

The module creates:
- **Resource Group**: Contains all Firezone resources
- **Virtual Machine Scale Set**: Runs Firezone Gateway instances
- **User Assigned Identity**: For Azure resource access
- **Network Security Group**: Controls network access
- **Application Gateway** (optional): Load balancer for multiple instances
- **Public IP** (optional): For external access

## Features

- ✅ **Auto-scaling**: VM Scale Set with configurable instance count
- ✅ **High Availability**: Multi-zone deployment support
- ✅ **Load Balancing**: Optional Application Gateway
- ✅ **Health Monitoring**: Built-in health checks
- ✅ **Security**: Network Security Groups and managed identity
- ✅ **Observability**: Azure Monitor integration
- ✅ **IP Forwarding**: Enabled for gateway functionality

## Prerequisites

1. **Azure Subscription**: Active Azure subscription
2. **Terraform**: Version >= 1.0
3. **Azure CLI**: For authentication
4. **Firezone Account**: Get your token from Firezone portal
5. **Virtual Network**: Existing VNet and subnet
6. **SSH Key Pair**: For VM access

## Quick Start

1. **Clone and Configure**:
   ```bash
   # Copy example configuration
   cp terraform.tfvars.example terraform.tfvars
   
   # Edit terraform.tfvars with your values
   nano terraform.tfvars
   ```

2. **Deploy**:
   ```bash
   # Initialize Terraform
   terraform init
   
   # Plan deployment
   terraform plan
   
   # Apply configuration
   terraform apply
   ```

3. **Verify**:
   ```bash
   # Check VM Scale Set status
   az vmss list-instances --resource-group <resource-group-name> --name <vmss-name>
   
   # Check health endpoint (if load balancer enabled)
   curl http://<public-ip>/healthz
   ```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `location` | Azure region | `"East US"` |
| `subnet_id` | Subnet resource ID | `/subscriptions/.../subnets/gateway-subnet` |
| `ssh_public_key` | SSH public key | `"ssh-rsa AAAAB3..."` |
| `firezone_token` | Firezone portal token | `"fz_token_..."` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `name_prefix` | `""` | Prefix for resource names |
| `vm_size` | `"Standard_B2s"` | VM size |
| `instance_count` | `1` | Number of instances |
| `enable_public_ip` | `true` | Assign public IPs |
| `enable_load_balancer` | `false` | Create Application Gateway |
| `log_level` | `"info"` | Firezone log level |

## Networking Requirements

### Subnet Configuration
- **Minimum size**: /28 (16 IPs) for basic deployment
- **Recommended size**: /24 (256 IPs) for production
- **IP forwarding**: Must be enabled on the subnet

### Firewall Rules
The module automatically creates NSG rules for:
- **Port 8080/TCP**: Health checks
- **Port 51820/UDP**: WireGuard VPN traffic
- **Port 22/TCP**: SSH management

### Load Balancer (Optional)
If `enable_load_balancer = true`:
- Requires separate `gateway_subnet_id` for Application Gateway
- Creates public IP for external access
- Configures health probes and backend pools

## Monitoring and Logging

### Azure Monitor Integration
- **System Metrics**: CPU, memory, disk, network
- **Application Logs**: Firezone gateway logs
- **Health Status**: VM and application health

### Log Locations
- **System logs**: `/var/log/syslog`
- **Firezone logs**: `/var/log/firezone-gateway.log`
- **Cloud-init logs**: `/var/log/cloud-init.log`

## Troubleshooting

### Common Issues

1. **VM Scale Set fails to start**:
   ```bash
   # Check cloud-init logs
   az vmss run-command invoke --resource-group <rg> --name <vmss> --instance-id 0 --command-id RunShellScript --scripts "tail -f /var/log/cloud-init.log"
   ```

2. **Health check failures**:
   ```bash
   # Check Firezone service status
   az vmss run-command invoke --resource-group <rg> --name <vmss> --instance-id 0 --command-id RunShellScript --scripts "systemctl status firezone-gateway"
   ```

3. **Network connectivity issues**:
   ```bash
   # Verify NSG rules
   az network nsg rule list --resource-group <rg> --nsg-name <nsg-name>
   ```

### Debug Commands

```bash
# SSH to VM instance
az vmss list-instance-connection-info --resource-group <rg> --name <vmss>

# Check Firezone logs
sudo journalctl -u firezone-gateway -f

# Verify network configuration
ip route show
ip addr show
```

## Security Considerations

1. **SSH Access**: Restrict SSH access to specific IP ranges
2. **Network Segmentation**: Use dedicated subnets
3. **Identity Management**: Leverage Azure AD integration
4. **Secrets Management**: Use Azure Key Vault for tokens
5. **Updates**: Regular OS and application updates

## Cost Optimization

1. **VM Sizing**: Start with Standard_B2s, scale as needed
2. **Disk Type**: Use Standard_LRS for non-production
3. **Public IPs**: Disable if not needed
4. **Load Balancer**: Only enable for multi-instance deployments

## Migration from GCP

Key differences from GCP version:
- **VM Scale Set** instead of Instance Group Manager
- **Application Gateway** instead of Load Balancer
- **User Assigned Identity** instead of Service Account
- **Network Security Group** instead of Firewall Rules

## Support

For issues and questions:
1. Check [Firezone Documentation](https://www.firezone.dev/docs)
2. Review Azure VM Scale Set documentation
3. Check Terraform Azure provider docs

## License

This module is provided under the same license as the original GCP module.
=======
This is test file.
>>>>>>> origin/main
