# Rough cost note

Numbers are *estimates* against US-region public pricing. Always confirm with the Azure pricing calculator for your subscription's offer / discounts. This is meant to set expectations for SE demo workloads, **not** for production.

## Hourly idle (Consumption profile, min-replicas=0, no traffic)

| Resource | Notional cost / hr |
|---|---|
| Container App (scaled to zero) | ~$0.00 |
| Container Apps Environment | ~$0.00 (no per-hour charge) |
| AI Foundry account (S0) | ~$0.00 (consumption-based; no idle floor) |
| Realtime model deployment (10 TPM, idle) | ~$0.00 |
| Speech account (S0) | ~$0.00 |
| Storage Account (LRS, ~3 MB sample bg) | < $0.01 |
| Key Vault (standard) | < $0.01 |
| Log Analytics (idle, < 1 GB / day) | < $0.10 |
| App Insights (workspace-based, idle) | < $0.05 |
| **Idle total** | **~$0.20 / day** |

## Active demo (10 minutes of conversation)

| Driver | Approximate cost |
|---|---|
| Realtime model — input + output tokens (~3k tokens / min) | ~$0.40 |
| Voice Live avatar streaming (per-minute video) | ~$0.20 – $0.50 |
| Container App vCPU-seconds (1 replica, 10 min) | ~$0.05 |
| **Per 10-min demo** | **~$0.70 – $1.00** |

## What drives cost up

- **Min replicas ≥ 1** — adds vCPU-seconds 24×7 (~$15–$25 / month for a 0.5 vCPU / 1 GiB replica).
- **Dedicated workload profile (D4 / D8)** — the workload profile itself bills hourly even when no replicas are running. Use only if you need predictable cold-start behavior.
- **Realtime model capacity** — TPM units don't cost money themselves, but higher capacity removes throttling so you'll consume more tokens during longer demos.
- **Background images in storage** — basically free unless someone uploads gigabytes.

## How to keep cost low

- Leave `minReplicas = 0`. Cold start is ~10 s and Henry's audience won't notice.
- Tear down the resource group between customer engagements. The Bicep is fully repeatable; redeploying takes < 12 min.
- Don't over-provision realtime capacity — `10` TPM is fine for back-to-back single-user demos.
