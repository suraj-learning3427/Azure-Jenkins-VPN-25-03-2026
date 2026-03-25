# Azure VPN-Protected SSO Jenkins Platform
## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                           DEVELOPER WORKSTATION                                   │
│                                                                                   │
│   ┌─────────────┐    git push     ┌──────────────────┐                           │
│   │   VS Code   │ ─────────────►  │  GitHub Repo     │                           │
│   │  Terraform  │                 │  azure/ modules  │                           │
│   │    Code     │                 └────────┬─────────┘                           │
│   └─────────────┘                          │ webhook trigger                     │
│                                            ▼                                     │
│   ┌─────────────┐                 ┌──────────────────┐                           │
│   │  Firezone   │                 │  Terraform Cloud  │                           │
│   │  VPN Client │                 │  Workspace:       │                           │
│   └──────┬──────┘                 │  jenkins-azure    │                           │
│          │ WireGuard tunnel        │  auto plan        │                           │
│          │ (split tunnel)          │  manual approve   │                           │
└──────────┼─────────────────────── │  auto apply       │                           │
           │                        └────────┬──────────┘                           │
           │                                 │ terraform apply                      │
           │                    ┌────────────┴────────────┐                        │
           │                    ▼                         ▼                        │
           │         AZURE PRIMARY (East US)    AZURE SECONDARY (West US)          │
```

---

## Azure Infrastructure

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  AZURE PRIMARY  |  East US  |  VNet: 192.168.0.0/16                                │
│                                                                                     │
│  ┌──────────────────────────┐    ┌──────────────────────────────────────────────┐  │
│  │  subnet-vpn              │    │  NSG Rules                                   │  │
│  │  192.168.3.0/24          │    │  ✅ 51820/UDP  WireGuard (inbound)           │  │
│  │                          │    │  ✅ 22/TCP     SSH (VirtualNetwork only)     │  │
│  │  ┌────────────────────┐  │    │  ✅ 8080/TCP   Firezone VPN clients only     │  │
│  │  │ Firezone Gateway   │  │    │  ❌ 8080/TCP   Internet BLOCKED              │  │
│  │  │ Standard_B2s       │  │    │  ✅ 100.64.0.0/10  Firezone client CIDR     │  │
│  │  │ Public IP          │  │    └──────────────────────────────────────────────┘  │
│  │  │ Port 51820/UDP     │  │                                                     │
│  │  │ Docker + Firezone  │  │    ┌──────────────────────────────────────────────┐  │
│  │  └────────────────────┘  │    │  Traffic Manager                             │  │
│  │  ┌────────────────────┐  │    │  azure-jenkins-firezone-tm                   │  │
│  │  │ Load Balancer      │  │    │  Performance routing · Auto failover         │  │
│  │  │ Standard SKU       │  │    └──────────────────────────────────────────────┘  │
│  │  └────────────────────┘  │                                                     │
│  └──────────────────────────┘                                                     │
│                                                                                     │
│  ┌──────────────────────────┐                                                     │
│  │  subnet-jenkins          │                                                     │
│  │  192.168.0.0/24          │                                                     │
│  │                          │                                                     │
│  │  ┌────────────────────┐  │                                                     │
│  │  │  Jenkins VM        │  │                                                     │
│  │  │  Standard_D2s_v3   │  │                                                     │
│  │  │  NO public IP      │  │                                                     │
│  │  │  Port 8080 (VPN)   │  │                                                     │
│  │  │  SAML SSO          │  │                                                     │
│  │  └────────────────────┘  │                                                     │
│  │  ┌────────────────────┐  │                                                     │
│  │  │  Private DNS       │  │                                                     │
│  │  │  jenkins-az.       │  │                                                     │
│  │  │  learningmyway.space  │  │                                                     │
│  │  └────────────────────┘  │                                                     │
│  └──────────────────────────┘                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│  AZURE SECONDARY  |  West US  |  VNet: 192.169.0.0/16  (same structure as primary) │
│  VNet Peering: 192.168.0.0/16 ↔ 192.169.0.0/16                                    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## End-to-End Flow

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER CI/CD WORKFLOW                                  │
│                                                                                   │
│  1. Dev writes Terraform in VS Code                                               │
│         │                                                                         │
│         ▼                                                                         │
│  2. git push → GitHub (azure/ folder)                                            │
│         │                                                                         │
│         ▼  webhook                                                                │
│  3. Terraform Cloud detects change → runs terraform plan                          │
│         │                                                                         │
│         ▼                                                                         │
│  4. Plan shown in TF Cloud UI → Manual approval required                          │
│         │                                                                         │
│         ▼  approved                                                               │
│  5. Terraform Cloud runs terraform apply → Azure resources deployed               │
│                                                                                   │
└──────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────┐
│                         USER VPN + JENKINS ACCESS FLOW                            │
│                                                                                   │
│  1. User opens Firezone client on laptop                                          │
│         │                                                                         │
│         ▼                                                                         │
│  2. Browser opens → authenticates via Microsoft Entra ID (OIDC)                  │
│         │                                                                         │
│         ▼                                                                         │
│  3. WireGuard tunnel established (split tunnel — internet still works)            │
│         │                                                                         │
│         ▼                                                                         │
│  4. Browse jenkins-az.learningmyway.space:8080                                       │
│         │                                                                         │
│         ▼                                                                         │
│  5. Jenkins redirects to Entra ID SAML login                                     │
│         │                                                                         │
│         ▼                                                                         │
│  6. Already logged in → SAML assertion returned → Jenkins access granted         │
│                                                                                   │
│  ✗ Without VPN: jenkins-az.learningmyway.space → NOT reachable                     │
│  ✓ Split tunnel: internet works normally while VPN is connected                  │
│                                                                                   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## Terraform Cloud Workspace

| Workspace       | Cloud | Trigger          | Variables                                                                 |
|-----------------|-------|------------------|---------------------------------------------------------------------------|
| `jenkins-azure` | Azure | push to `azure/` | `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, `firezone_token`, `firezone_id` |

---

## Key Design Decisions

| Component         | Choice                        | Reason                                      |
|-------------------|-------------------------------|---------------------------------------------|
| Primary IdP       | Microsoft Entra ID            | SAML + OIDC support, Conditional Access     |
| VPN               | Firezone (WireGuard)          | Lightweight, split tunnel, OIDC SSO         |
| Jenkins SSO       | SAML plugin                   | Supported by Entra ID natively              |
| State backend     | Terraform Cloud               | No local tfstate, team collaboration        |
| DNS               | Azure Private DNS             | jenkins-az.learningmyway.space                 |
| Jenkins access    | VPN-only (no public IP)       | Security requirement                        |
| Multi-region      | East US (primary) + West US   | High availability via Traffic Manager       |
| Split tunnel      | Azure CIDRs only via VPN      | Internet not disrupted when VPN connected   |
