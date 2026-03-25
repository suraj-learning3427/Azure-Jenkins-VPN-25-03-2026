# Demo Checklist — Multi-Cloud Jenkins Platform
# Run through this top-to-bottom before the demo

## PHASE 1: Generate Certificates (run once locally)

```bash
cd certs
bash generate-certs.sh
# Outputs: root-ca/, intermediate-ca/, leaf/ folders
```
- [ ] root-ca/root-ca.cert.pem exists
- [ ] leaf/jenkins-az.cert.pem exists
- [ ] leaf/jenkins-gcp.cert.pem exists
- [ ] leaf/jenkins-az.pfx exists

---

## PHASE 2: Deploy Azure Infrastructure

```bash
# From repo root
terraform init
terraform plan
terraform apply -auto-approve
```

### Azure resources to verify in portal:
- [ ] Resource group: `azure-jenkins-core-infrastructure-rg`
- [ ] VNet: `azure-jenkins-vpc-spoke` (192.168.0.0/16)
- [ ] Subnet: `subnet-jenkins`, `subnet-vpn`
- [ ] Jenkins VM: `jenkins-server` — private IP only, no public IP
- [ ] Firezone VMs: `azure-jenkins-primary-firezone-gateway` + secondary
- [ ] Load Balancers: primary (East US) + secondary (West US)
- [ ] Private DNS zone: `learningmyway.space`
- [ ] DNS A record: `jenkins-az.learningmyway.space` → Jenkins private IP
- [ ] Traffic Manager profile: `azure-jenkins-firezone-tm`

### Get Jenkins private IP:
```bash
terraform output -json jenkins_vm | jq '.jenkins_vm.private_ip_address'
```

---

## PHASE 3: Deploy GCP Infrastructure

```bash
cd gcp
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set project_id, ssh_public_key, firezone_id, firezone_token
terraform init
terraform plan
terraform apply -auto-approve
```

### GCP resources to verify in console:
- [ ] VPC: `jenkins-vpc`
- [ ] Subnets: `jenkins-subnet-jenkins` (10.10.0.0/24), `jenkins-subnet-vpn` (10.10.1.0/24)
- [ ] Firezone VM: `jenkins-firezone-gateway` — has public IP
- [ ] Jenkins VM: `jenkins-jenkins-server` — NO public IP
- [ ] Cloud NAT: `jenkins-nat` (for Jenkins outbound)
- [ ] Cloud DNS zone: `jenkins-internal-dns` (private, learningmyway.space)
- [ ] DNS A record: `jenkins-gcp.learningmyway.space` → Jenkins private IP

### Get GCP outputs:
```bash
terraform output firezone_gateway_external_ip
terraform output jenkins_internal_ip
terraform output jenkins_dns
```

---

## PHASE 4: Verify Firezone Gateways Online

1. Open https://app.firezone.dev
2. Go to Sites → your site
3. Verify gateways show status: **Online**
   - [ ] Azure primary gateway (East US) — Online
   - [ ] Azure secondary gateway (West US) — Online
   - [ ] GCP gateway (us-central1) — Online

### In Firezone, configure Resources:
- [ ] Add resource: `jenkins-az.learningmyway.space` → CIDR `192.168.0.0/24`
- [ ] Add resource: `jenkins-gcp.learningmyway.space` → CIDR `10.10.0.0/24`
- [ ] Assign resources to your user/group policy

---

## PHASE 5: Push Certificates to Cloud Stores

```bash
# Azure Key Vault
cd azure/certs-keyvault
terraform init
terraform apply -auto-approve

# GCP Secret Manager
cd ../../gcp/certs-secretmanager
terraform init
terraform apply -auto-approve
```
- [ ] Azure Key Vault created with all certs
- [ ] GCP Secret Manager has all secrets

---

## PHASE 6: VPN Client Test

1. Install Firezone client on your laptop
2. Connect to your Firezone site
3. Test DNS resolution:
```bash
nslookup jenkins-az.learningmyway.space
nslookup jenkins-gcp.learningmyway.space
```
- [ ] `jenkins-az.learningmyway.space` resolves to Azure Jenkins private IP
- [ ] `jenkins-gcp.learningmyway.space` resolves to GCP Jenkins private IP

4. Test Jenkins reachability:
```bash
curl -I http://jenkins-az.learningmyway.space:8080
curl -I http://jenkins-gcp.learningmyway.space:8080
```
- [ ] Azure Jenkins returns HTTP 200 or 403 (login page)
- [ ] GCP Jenkins returns HTTP 200 or 403 (login page)

5. Test VPN-only enforcement (disconnect VPN):
```bash
curl --connect-timeout 5 http://jenkins-az.learningmyway.space:8080
# Should FAIL / timeout — Jenkins not reachable without VPN
```
- [ ] Jenkins NOT reachable without VPN ✅

---

## PHASE 7: Jenkins Initial Setup

### Azure Jenkins:
```bash
# SSH via Firezone (VPN must be connected)
ssh azureuser@jenkins-az.learningmyway.space
sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword
```
- [ ] Get initial admin password
- [ ] Open http://jenkins-az.learningmyway.space:8080 in browser
- [ ] Complete Jenkins setup wizard
- [ ] Install suggested plugins

### GCP Jenkins:
```bash
# SSH via IAP or Firezone
gcloud compute ssh jenkins-jenkins-server --zone=us-central1-a --tunnel-through-iap
sudo cat /jenkins/jenkins_home/secrets/initialAdminPassword
```
- [ ] Get initial admin password
- [ ] Open http://jenkins-gcp.learningmyway.space:8080 in browser
- [ ] Complete Jenkins setup wizard
- [ ] Install suggested plugins

---

## PHASE 8: SSO / SAML Setup (Microsoft Entra ID)

### Step 1 — Register app in Entra ID (Azure Portal):
1. Azure Portal → Entra ID → App Registrations → New Registration
   - Name: `Jenkins SSO`
   - Redirect URI: `http://jenkins-az.learningmyway.space:8080/securityRealm/finishLogin`
2. Under "Expose an API" → add scope
3. Under "Token configuration" → add groups claim
4. Note down: **Application (client) ID**, **Directory (tenant) ID**
5. Create a client secret → note it down

### Step 2 — Install SAML plugin on Jenkins:
1. Jenkins → Manage Jenkins → Plugins → Available
2. Search: `SAML` → Install "SAML Plugin"
3. Restart Jenkins

### Step 3 — Configure SAML in Jenkins:
1. Jenkins → Manage Jenkins → Security
2. Security Realm → SAML 2.0
3. Fill in:
   - IdP Metadata URL: `https://login.microsoftonline.com/{tenant-id}/federationmetadata/2007-06/federationmetadata.xml`
   - Display Name Attribute: `displayName`
   - Group Attribute: `http://schemas.microsoft.com/ws/2008/06/identity/claims/groups`
   - Username Attribute: `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name`
4. Save

- [ ] Azure Jenkins SSO working — redirects to Microsoft login
- [ ] GCP Jenkins SSO working — same Microsoft login

---

## PHASE 9: Terraform Cloud + GitHub Workflow

### Step 1 — Create GitHub repo:
```bash
git init
git remote add origin https://github.com/YOUR_ORG/jenkins-infra.git
git add .
git commit -m "Initial infrastructure"
git push -u origin main
```

### Step 2 — Create Terraform Cloud workspaces:
1. Go to https://app.terraform.io
2. Create workspace: `jenkins-azure` → connect to GitHub repo → path: `/` (root)
3. Create workspace: `jenkins-gcp` → connect to GitHub repo → path: `gcp/`
4. Set variables in each workspace:
   - `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID` (Azure)
   - `GOOGLE_CREDENTIALS` (GCP service account JSON, mark sensitive)
   - `firezone_id`, `firezone_token` (mark sensitive)
   - `ssh_public_key`

### Step 3 — Test the workflow:
```bash
# Make a small change (e.g. update a tag)
git add . && git commit -m "test: trigger TF Cloud plan" && git push
```
- [ ] Terraform Cloud shows plan triggered automatically
- [ ] Plan shows in TF Cloud UI
- [ ] Approve plan → apply runs
- [ ] State stored in Terraform Cloud (no local tfstate)

---

## PHASE 10: Demo Script (for the presentation)

### Show order:
1. **GitHub push** → show commit in GitHub
2. **Terraform Cloud** → show plan auto-triggered, approve it
3. **Azure Portal** → show Jenkins VM (private IP only), Firezone LBs
4. **GCP Console** → show Jenkins VM (no public IP), Firezone gateway
5. **Firezone UI** → show all 3 gateways Online
6. **Connect VPN** → connect Firezone client on laptop
7. **Browser** → open `http://jenkins-az.learningmyway.space:8080` → Jenkins login
8. **Browser** → open `http://jenkins-gcp.learningmyway.space:8080` → Jenkins login
9. **SSO demo** → click login → redirected to Microsoft → log in → back to Jenkins
10. **Disconnect VPN** → show Jenkins is NOT reachable
11. **Architecture diagram** → open `architecture-diagram.html` in browser

---

## Quick Troubleshooting

| Problem | Fix |
|---|---|
| Firezone gateway Offline | SSH to VM, run `docker logs firezone-gateway` |
| Jenkins not starting | SSH to VM, run `sudo journalctl -u jenkins -n 50` |
| DNS not resolving | Check Firezone resource policy — resource must be assigned to your user |
| VPN connects but can't reach Jenkins | Check NSG/firewall rules allow Firezone client CIDR |
| Terraform Cloud plan fails | Check workspace variables — credentials must be set |
| SAML login fails | Check Entra ID app redirect URI matches Jenkins URL exactly |
