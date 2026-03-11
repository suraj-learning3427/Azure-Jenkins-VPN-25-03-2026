# Azure Jenkins POC - Deployment Checklist

## Pre-Deployment Requirements

### ✅ Azure Prerequisites

**Azure Subscription & Access**
- [ ] Active Azure subscription with sufficient credits/budget
- [ ] Subscription Owner or Contributor role
- [ ] Resource Provider registrations:
  ```bash
  az provider register --namespace Microsoft.Compute
  az provider register --namespace Microsoft.Network
  az provider register --namespace Microsoft.KeyVault
  az provider register --namespace Microsoft.Storage
  ```

**Local Development Environment**
- [ ] Azure CLI installed and configured
  ```bash
  az --version  # Should be >= 2.40.0
  az login
  az account show
  ```
- [ ] Terraform installed (>= 1.0)
  ```bash
  terraform --version
  ```
- [ ] SSH key pair generated
  ```bash
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_jenkins_key
  ```

**Network Planning**
- [ ] Confirm IP address ranges don't conflict with existing networks
  - Hub VNet: `172.16.0.0/16`
  - Spoke VNet: `192.168.0.0/16`
  - Application Gateway: `192.168.129.0/23`
- [ ] DNS domain name decided: `dreamcompany.intranet`
- [ ] Jenkins FQDN decided: `jenkins.np.dreamcompany.intranet`

## Deployment Steps

### Step 1: Hub Network Infrastructure (15-20 minutes)

**Deploy Azure Networking Global (Hub)**
```bash
cd Azure-code/azure-networking-global

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

**Required Variables:**
```hcl
name_prefix = "mycompany-"
location    = "East US"
enable_bastion = true
enable_vpn_gateway = false  # Set to true if needed
```

**Verification:**
- [ ] Hub VNet created: `mycompany-vpc-hub`
- [ ] Azure Bastion deployed and accessible
- [ ] Network Security Groups configured
- [ ] Resource group created: `mycompany-networking-global-rg`

### Step 2: Spoke Network Infrastructure (10-15 minutes)

**Deploy Azure Core Infrastructure (Spoke)**
```bash
cd ../azure-core-infrastructure

# Get Hub VNet ID from previous deployment
HUB_VNET_ID=$(cd ../azure-networking-global && terraform output -raw hub_virtual_network.id)

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Required Variables:**
```hcl
name_prefix = "mycompany-"
location    = "East US"
enable_hub_peering = true
hub_vnet_id = "<HUB_VNET_ID_FROM_STEP_1>"
```

**Deploy:**
```bash
terraform init
terraform plan
terraform apply
```

**Verification:**
- [ ] Spoke VNet created: `mycompany-vpc-spoke`
- [ ] VNet peering established between Hub and Spoke
- [ ] Private DNS zone created: `dreamcompany.intranet`
- [ ] Subnets created: `subnet-jenkins`, `subnet-appgw`

### Step 3: Jenkins Virtual Machine (20-25 minutes)

**Deploy Jenkins VM**
```bash
cd ../azure-jenkins-vm

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Required Variables:**
```hcl
name_prefix = "mycompany-"
resource_group_name = "mycompany-core-infrastructure-rg"
vnet_name = "mycompany-vpc-spoke"
ssh_public_key = "<YOUR_SSH_PUBLIC_KEY>"
```

**Deploy:**
```bash
terraform init
terraform plan
terraform apply
```

**Verification:**
- [ ] Jenkins VM created and running
- [ ] Data disk attached and mounted at `/jenkins`
- [ ] Jenkins service installed and running
- [ ] VM accessible via Azure Bastion

**Test Jenkins Installation:**
```bash
# Connect via Bastion (use Azure Portal or CLI)
az network bastion ssh --name mycompany-bastion \
  --resource-group mycompany-networking-global-rg \
  --target-resource-id /subscriptions/<sub-id>/resourceGroups/mycompany-core-infrastructure-rg/providers/Microsoft.Compute/virtualMachines/jenkins-server \
  --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/azure_jenkins_key

# Once connected, verify Jenkins
sudo systemctl status jenkins
curl -I http://localhost:8080
sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword
```

### Step 4: Application Gateway (15-20 minutes)

**Deploy Application Gateway**
```bash
cd ../azure-jenkins-appgw

# Get Jenkins VM private IP
JENKINS_IP=$(cd ../azure-jenkins-vm && terraform output -raw jenkins_vm.private_ip_address)

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Required Variables:**
```hcl
name_prefix = "mycompany-"
resource_group_name = "mycompany-core-infrastructure-rg"
vnet_name = "mycompany-vpc-spoke"
jenkins_private_ip = "<JENKINS_IP_FROM_STEP_3>"
```

**Deploy:**
```bash
terraform init
terraform plan
terraform apply
```

**Verification:**
- [ ] Application Gateway created and running
- [ ] Key Vault created with SSL certificate
- [ ] Backend pool configured with Jenkins VM
- [ ] Health probes passing

### Step 5: DNS Configuration (5 minutes)

**Add DNS Record**
```bash
cd ../azure-core-infrastructure

# Add DNS A record for Jenkins
az network private-dns record-set a add-record \
  --resource-group mycompany-core-infrastructure-rg \
  --zone-name dreamcompany.intranet \
  --record-set-name jenkins.np \
  --ipv4-address 192.168.129.50
```

**Verification:**
- [ ] DNS A record created: `jenkins.np.dreamcompany.intranet → 192.168.129.50`
- [ ] DNS resolution working from VMs in VNet

## Post-Deployment Verification

### ✅ Network Connectivity Tests

**From Hub VNet (via Bastion):**
```bash
# Test DNS resolution
nslookup jenkins.np.dreamcompany.intranet

# Test HTTPS connectivity
curl -k https://jenkins.np.dreamcompany.intranet
curl -k https://192.168.129.50
```

**From Spoke VNet (Jenkins VM):**
```bash
# Test outbound connectivity
curl -I https://www.google.com

# Test Jenkins local access
curl -I http://localhost:8080
```

### ✅ Application Gateway Health

**Check Backend Health:**
```bash
az network application-gateway show-backend-health \
  --resource-group mycompany-core-infrastructure-rg \
  --name mycompany-jenkins-appgw
```

**Expected Output:**
- Backend pool status: `Healthy`
- Health probe status: `Up`

### ✅ Jenkins Access Test

**Via Application Gateway:**
1. Connect to a VM in Hub VNet via Bastion
2. Open browser or use curl:
   ```bash
   curl -k https://jenkins.np.dreamcompany.intranet
   curl -k https://192.168.129.50
   ```
3. Should see Jenkins login page

**Initial Setup:**
1. Get initial admin password:
   ```bash
   # Via Bastion to Jenkins VM
   sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword
   ```
2. Access Jenkins UI via HTTPS
3. Complete initial setup wizard

## Security Verification

### ✅ Network Security

**Verify No Public IPs on VMs:**
```bash
az vm list --resource-group mycompany-core-infrastructure-rg \
  --query "[].{Name:name, PublicIP:publicIps}" --output table
```
Expected: No public IPs listed

**Verify NSG Rules:**
```bash
az network nsg rule list \
  --resource-group mycompany-core-infrastructure-rg \
  --nsg-name mycompany-jenkins-nsg \
  --output table
```

**Test External Access (Should Fail):**
```bash
# From external network - should timeout/fail
curl -m 10 https://<any-private-ip>
```

### ✅ Certificate Verification

**Check SSL Certificate:**
```bash
# From within VNet
openssl s_client -connect jenkins.np.dreamcompany.intranet:443 -servername jenkins.np.dreamcompany.intranet
```

## Troubleshooting Common Issues

### 🔧 Deployment Failures

**Terraform State Issues:**
```bash
# If deployment fails, check state
terraform show
terraform refresh

# If needed, import existing resources
terraform import azurerm_resource_group.example /subscriptions/<sub-id>/resourceGroups/<rg-name>
```

**Resource Naming Conflicts:**
```bash
# Check existing resources
az resource list --resource-group <rg-name> --output table

# Clean up if needed
terraform destroy
```

### 🔧 Network Connectivity Issues

**VNet Peering Problems:**
```bash
# Check peering status
az network vnet peering list \
  --resource-group mycompany-core-infrastructure-rg \
  --vnet-name mycompany-vpc-spoke \
  --output table

# Should show "Connected" status
```

**DNS Resolution Issues:**
```bash
# Check DNS zone
az network private-dns zone list \
  --resource-group mycompany-core-infrastructure-rg

# Check DNS records
az network private-dns record-set a list \
  --resource-group mycompany-core-infrastructure-rg \
  --zone-name dreamcompany.intranet
```

### 🔧 Jenkins Issues

**Service Not Starting:**
```bash
# Check Jenkins service
sudo systemctl status jenkins
sudo journalctl -u jenkins -f

# Check disk space
df -h /jenkins

# Check Java process
ps aux | grep java
```

**Port Binding Issues:**
```bash
# Check if port is in use
sudo netstat -tlnp | grep 8080

# Check firewall
sudo firewall-cmd --list-all
```

### 🔧 Application Gateway Issues

**Backend Health Failures:**
```bash
# Check health probe configuration
az network application-gateway probe show \
  --resource-group mycompany-core-infrastructure-rg \
  --gateway-name mycompany-jenkins-appgw \
  --name jenkins-health-probe

# Test health endpoint directly
curl -I http://<jenkins-private-ip>:8080/login
```

**Certificate Issues:**
```bash
# Check Key Vault certificate
az keyvault certificate show \
  --vault-name <key-vault-name> \
  --name jenkins-ssl-cert

# Check Application Gateway certificate
az network application-gateway ssl-cert show \
  --resource-group mycompany-core-infrastructure-rg \
  --gateway-name mycompany-jenkins-appgw \
  --name jenkins-ssl-cert
```

## Performance Optimization

### ✅ VM Performance

**Monitor Resource Usage:**
```bash
# CPU and Memory
top
htop

# Disk I/O
iostat -x 1

# Network
iftop
```

**Jenkins JVM Tuning:**
```bash
# Edit Jenkins service
sudo systemctl edit jenkins

# Add JVM options
[Service]
Environment="JAVA_OPTS=-Xmx4g -Xms2g -XX:+UseG1GC"
```

### ✅ Application Gateway Performance

**Monitor Metrics:**
- Request count
- Response time
- Failed requests
- Backend response time

**Scaling Options:**
- Increase capacity (instance count)
- Upgrade to WAF_v2 SKU
- Enable autoscaling

## Backup and Disaster Recovery

### ✅ Backup Configuration

**VM Backup:**
```bash
# Enable Azure Backup
az backup vault create \
  --resource-group mycompany-core-infrastructure-rg \
  --name mycompany-backup-vault \
  --location "East US"

# Configure VM backup
az backup protection enable-for-vm \
  --resource-group mycompany-core-infrastructure-rg \
  --vault-name mycompany-backup-vault \
  --vm jenkins-server \
  --policy-name DefaultPolicy
```

**Disk Snapshots:**
```bash
# Create snapshot of data disk
az snapshot create \
  --resource-group mycompany-core-infrastructure-rg \
  --name jenkins-data-snapshot-$(date +%Y%m%d) \
  --source /subscriptions/<sub-id>/resourceGroups/mycompany-core-infrastructure-rg/providers/Microsoft.Compute/disks/mycompany-jenkins-data-disk
```

### ✅ Disaster Recovery Test

**Recovery Procedure:**
1. Create new VM from backup/snapshot
2. Attach restored data disk
3. Update Application Gateway backend pool
4. Update DNS records
5. Test connectivity

## Cost Monitoring

### ✅ Cost Analysis

**Check Current Costs:**
```bash
# Get cost analysis
az consumption usage list \
  --start-date 2026-03-01 \
  --end-date 2026-03-10 \
  --output table
```

**Cost Optimization:**
- Use Reserved Instances for VMs
- Right-size VM based on usage
- Use Standard_LRS for non-critical disks
- Schedule VM shutdown for non-production

## Final Checklist

### ✅ Production Readiness

- [ ] All components deployed successfully
- [ ] Network connectivity verified
- [ ] Security controls in place
- [ ] SSL certificates configured
- [ ] DNS resolution working
- [ ] Jenkins accessible via HTTPS
- [ ] Backup configured
- [ ] Monitoring enabled
- [ ] Documentation updated
- [ ] Team access configured

### ✅ Handover Items

- [ ] Terraform state files secured
- [ ] SSH keys distributed to team
- [ ] Jenkins admin credentials shared securely
- [ ] Azure resource access configured
- [ ] Monitoring dashboards created
- [ ] Runbook documentation provided

## Next Steps

1. **Complete Jenkins Setup**: Install plugins, configure jobs
2. **Security Hardening**: Implement additional security measures
3. **Monitoring Setup**: Configure alerts and dashboards
4. **Team Onboarding**: Provide access and training
5. **Production Migration**: Plan migration from existing systems

---

## Support Contacts

**Infrastructure Team**: infrastructure@company.com  
**Azure Support**: [Azure Support Portal](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)  
**Documentation**: [Azure-code/README.md](README.md)

---

**Document**: Azure Deployment Checklist  
**Version**: 1.0  
**Date**: March 10, 2026  
**Status**: Production Ready