# Project Cost Estimate
## Multi-Cloud Jenkins Platform (Azure + GCP)
### Prices as of 2025 — US East/Central regions — Pay-as-you-go (no reservations)

---

## AZURE RESOURCES

### VMs
| Resource | Size | vCPU | RAM | Hourly | Daily | Monthly |
|---|---|---|---|---|---|---|
| Jenkins VM (East US) | Standard_D2s_v3 | 2 | 8GB | $0.096 | $2.30 | $70.08 |
| Firezone GW Primary (East US) | Standard_B2s | 2 | 4GB | $0.0416 | $1.00 | $30.37 |
| Firezone GW Secondary (West US) | Standard_B2s | 2 | 4GB | $0.0416 | $1.00 | $30.37 |

### Disks
| Resource | Type | Size | Hourly | Daily | Monthly |
|---|---|---|---|---|---|
| Jenkins OS Disk (Premium SSD) | Premium_LRS | 64GB | $0.0068 | $0.163 | $4.96 |
| Jenkins Data Disk (Premium SSD) | Premium_LRS | 100GB | $0.0102 | $0.245 | $7.44 |
| Firezone GW Primary OS Disk | Premium_LRS | 32GB | $0.0034 | $0.082 | $2.48 |
| Firezone GW Secondary OS Disk | Premium_LRS | 32GB | $0.0034 | $0.082 | $2.48 |

### Networking
| Resource | Details | Hourly | Daily | Monthly |
|---|---|---|---|---|
| Public IP - LB Primary (Static Standard) | East US | $0.005 | $0.12 | $3.65 |
| Public IP - LB Secondary (Static Standard) | West US | $0.005 | $0.12 | $3.65 |
| Load Balancer Primary (Standard) | East US | $0.025 | $0.60 | $18.25 |
| Load Balancer Secondary (Standard) | West US | $0.025 | $0.60 | $18.25 |
| Traffic Manager | Per DNS query (est. low) | $0.0001 | $0.002 | $0.06 |
| VNet Peering (Hub↔Spoke) | Per GB processed ~5GB/mo | $0.0001 | $0.003 | $0.10 |
| Outbound Bandwidth (est. 10GB/mo) | First 5GB free | $0.0001 | $0.003 | $0.087 |

### Other Azure Services
| Resource | Details | Hourly | Daily | Monthly |
|---|---|---|---|---|
| Azure Key Vault (Standard) | Secrets + Certs | $0.0001 | $0.003 | $0.10 |
| Private DNS Zone | learningmyway.space | $0.0001 | $0.003 | $0.10 |
| Azure Monitor (basic) | Logs + Metrics | $0.0003 | $0.007 | $0.20 |

### AZURE SUBTOTAL
| Period | Cost |
|---|---|
| **Hourly** | **$0.2106** |
| **Daily** | **$5.05** |
| **Monthly** | **$191.91** |

---

## GCP RESOURCES (Planned — not yet deployed)

### VMs
| Resource | Size | vCPU | RAM | Hourly | Daily | Monthly |
|---|---|---|---|---|---|---|
| Jenkins VM (us-central1) | e2-standard-2 | 2 | 8GB | $0.0670 | $1.608 | $48.91 |
| Firezone GW (us-central1) | e2-medium | 2 | 4GB | $0.0335 | $0.804 | $24.46 |

### Disks
| Resource | Type | Size | Hourly | Daily | Monthly |
|---|---|---|---|---|---|
| Jenkins OS Disk (SSD PD) | pd-ssd | 50GB | $0.0012 | $0.029 | $0.85 |
| Jenkins Data Disk (SSD PD) | pd-ssd | 100GB | $0.0023 | $0.055 | $1.70 |
| Firezone GW OS Disk (SSD PD) | pd-ssd | 30GB | $0.0007 | $0.017 | $0.51 |

### Networking
| Resource | Details | Hourly | Daily | Monthly |
|---|---|---|---|---|
| Static External IP (Firezone GW) | us-central1 | $0.004 | $0.096 | $2.92 |
| Cloud NAT (Jenkins egress) | Per VM + data | $0.0014 | $0.034 | $1.03 |
| VPC Firewall Rules | No charge | $0.00 | $0.00 | $0.00 |
| Cloud DNS Private Zone | learningmyway.space | $0.0001 | $0.002 | $0.06 |
| Outbound Bandwidth (est. 10GB/mo) | First 1GB free | $0.0001 | $0.003 | $0.09 |

### Other GCP Services
| Resource | Details | Hourly | Daily | Monthly |
|---|---|---|---|---|
| Secret Manager | 6 secrets, low access | $0.00003 | $0.0007 | $0.02 |
| Cloud Monitoring | Basic free tier | $0.00 | $0.00 | $0.00 |
| IAM / WIF | No charge | $0.00 | $0.00 | $0.00 |

### GCP SUBTOTAL
| Period | Cost |
|---|---|
| **Hourly** | **$0.1083** |
| **Daily** | **$2.60** |
| **Monthly** | **$80.55** |

---

## SHARED / SAAS SERVICES

| Service | Plan | Hourly | Daily | Monthly |
|---|---|---|---|---|
| Firezone SaaS | Starter (free up to 6 users) | $0.00 | $0.00 | $0.00 |
| Firezone SaaS | Team plan (if >6 users) | $0.0068 | $0.164 | $5.00 |
| Terraform Cloud | Free (up to 500 resources) | $0.00 | $0.00 | $0.00 |
| GitHub | Free (public) / Team $4/user | $0.00 | $0.00 | $0.00 |
| Microsoft Entra ID | Free tier (SSO basic) | $0.00 | $0.00 | $0.00 |
| Microsoft Entra ID | P1 (Conditional Access) | $0.0008 | $0.02 | $0.60/user |

---

## TOTAL PROJECT COST SUMMARY

### Current State (Azure only — infrastructure destroyed)
| Period | Cost |
|---|---|
| Hourly | $0.00 (destroyed) |
| Daily | $0.00 (destroyed) |
| Monthly | $0.00 (destroyed) |

### Full Deployment (Azure + GCP — everything running 24/7)

| Component | Hourly | Daily | Monthly |
|---|---|---|---|
| Azure Infrastructure | $0.2106 | $5.05 | $191.91 |
| GCP Infrastructure | $0.1083 | $2.60 | $80.55 |
| Firezone SaaS (free tier) | $0.00 | $0.00 | $0.00 |
| Terraform Cloud (free tier) | $0.00 | $0.00 | $0.00 |
| Entra ID (free tier) | $0.00 | $0.00 | $0.00 |
| **TOTAL** | **$0.319** | **$7.65** | **$272.46** |

---

## COST OPTIMIZATION OPTIONS

### Option A: Shut down VMs nights/weekends (12hrs/day, 5 days/week)
- Running hours: ~260hrs/month instead of 730hrs
- Savings: ~64% on VM compute
- **Estimated monthly: ~$130**

### Option B: Use Reserved Instances (1-year commitment)
- Azure Reserved: ~40% discount on VMs
- GCP Committed Use: ~37% discount on VMs
- **Estimated monthly: ~$185**

### Option C: Downsize Firezone GWs to Standard_B1s / e2-micro
- Firezone is lightweight — B1s ($7.59/mo) works fine for dev/test
- **Estimated monthly: ~$240**

### Option D: Single region (remove secondary Azure region)
- Remove: Firezone GW Secondary + LB Secondary + Traffic Manager
- Savings: ~$52/month
- **Estimated monthly: ~$220**

### Option E: All optimizations combined (dev/test environment)
- Single region + smaller VMs + scheduled shutdown
- **Estimated monthly: ~$80-100**

---

## COST BY RESOURCE TYPE (Full deployment)

| Category | Monthly | % of Total |
|---|---|---|
| Virtual Machines (compute) | $203.73 | 74.8% |
| Managed Disks (storage) | $19.92 | 7.3% |
| Load Balancers | $36.50 | 13.4% |
| Public IPs | $13.14 | 4.8% |
| DNS + Networking | $4.45 | 1.6% |
| Other (KV, Secrets, Monitor) | $0.32 | 0.1% |
| **TOTAL** | **$272.46** | **100%** |

---

> ⚠️ Note: All prices are approximate pay-as-you-go rates.
> Actual costs may vary based on bandwidth usage, disk IOPS, and region pricing.
> Use Azure Pricing Calculator and GCP Pricing Calculator for exact quotes.
