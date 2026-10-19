# SSH и VPN access flow

Схема доступа к WireGuard-шлюзу: административный SSH только с разрешённых
CIDR, клиентский трафик — по UDP, всё остальное явно запрещено.

## Сетевой поток

```mermaid
flowchart TD
    Admin["Admin workstation<br/>allowed SSH CIDR"] -->|"TCP 22"| FWSSH["Firewall allow-ssh<br/>priority 1000<br/>logging on"]
    Admin -->|"ICMP"| FWICMP["Firewall allow-icmp<br/>priority 1000"]
    Client["WireGuard client<br/>10.66.66.0/24"] -->|"UDP 51820"| FWVPN["Firewall allow-wireguard<br/>priority 1000"]
    FWSSH --> VM["GCE VM vpn-gw-vm<br/>OS Login only<br/>Shielded VM"]
    FWICMP --> VM
    FWVPN --> VM
    VM -->|"MASQUERADE"| Egress["Internet egress"]
    FWSSH --> Deny["Firewall deny-all-ingress<br/>priority 65534"]
    FWICMP --> Deny
    FWVPN --> Deny
    Deny --> Drop["Dropped"]
```

## Последовательность первого запуска

```mermaid
sequenceDiagram
    participant TF as Terraform
    participant GCP as GCP APIs
    participant VM as WireGuard VM
    participant SM as Secret Manager
    participant AD as Admin

    TF->>GCP: create VPC, subnet, static IP, firewall
    TF->>GCP: create service account and IAM bindings
    TF->>GCP: create Secret Manager secret
    TF->>GCP: create VM with startup script
    GCP->>VM: boot and run startup script
    VM->>VM: install wireguard-tools
    VM->>VM: generate server and client keys
    VM->>VM: configure wg0 and NAT
    VM->>SM: add client config version via REST
    AD->>GCP: gcloud compute ssh from allowed CIDR
    AD->>SM: read client config
    AD->>VM: wg handshake over UDP
```

## Правила, которые видны на схеме

- SSH и WireGuard — единственные ingress-правила с priority 1000, плюс
  ICMP-диагностика с тех же административных диапазонов.
- Явный deny на priority 65534 делает отказ видимым в логах.
- У VM нет project-wide SSH keys: доступ только через OS Login.
- Клиентские приватные ключи не проходят через Terraform.
- Исходящий трафик клиентов уходит через внешний IP шлюза.
