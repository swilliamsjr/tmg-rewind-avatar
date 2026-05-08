# 🎬 TMG Rewind Avatar

> One-click deploy of the **Project Rewind** real-time avatar demo, productized for TMG Solution Engineers and Specialists.

Talk to a full-duplex video avatar that is fully reskinnable per account — voice, realtime model, background image, and system prompt all settable at deploy time and changeable at runtime.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fswilliamsjr%2Ftmg-rewind-avatar%2Fmain%2Finfra%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fswilliamsjr%2Ftmg-rewind-avatar%2Fmain%2Finfra%2FcreateUiDefinition.json)

[![bicep-validate](https://github.com/swilliamsjr/tmg-rewind-avatar/actions/workflows/bicep-validate.yml/badge.svg)](https://github.com/swilliamsjr/tmg-rewind-avatar/actions/workflows/bicep-validate.yml)
[![build-and-deploy](https://github.com/swilliamsjr/tmg-rewind-avatar/actions/workflows/build-and-deploy.yml/badge.svg)](https://github.com/swilliamsjr/tmg-rewind-avatar/actions/workflows/build-and-deploy.yml)

---

## What you get

A single Azure Container App serving:

- a real-time **photo / vector avatar** that streams full-duplex video over WebRTC,
- a **Voice Live** speech-to-speech pipeline tied to a realtime model deployment (`gpt-realtime` by default),
- an **in-page config panel** so you can change voice, avatar, prompt, and background image without redeploying.

Plus the supporting Azure scaffolding: AI Foundry account + project + realtime model deployment, Speech account, Storage, Key Vault, user-assigned managed identity, and Log Analytics + Application Insights.

## Click the button

The button above launches the Azure portal, lets you pick a subscription / region / resource group, and surfaces a guided form for every customizable setting:

| Field                       | Default                                      |
|-----------------------------|----------------------------------------------|
| Region                      | East US 2 *(also: Sweden Central, Japan East)* |
| Realtime model              | `gpt-realtime` *(2025-08-28)*                |
| Default voice               | `en-US-AvaMultilingualNeural`                |
| Avatar character            | `lisa`                                       |
| Background image URL        | *(empty → bundled background.png)*           |
| System prompt               | MAX content guide persona                    |
| Workload profile            | Consumption                                  |
| Container image             | `ghcr.io/swilliamsjr/tmg-rewind-avatar:latest` |
| Min / max replicas          | `0 / 3`                                      |

Deployment takes roughly **8–12 minutes** (the AI Foundry account + realtime model deployment are the long pole). The Bicep outputs `appUrl` — open it, allow microphone, and start talking.

> **Permissions:** the deploying principal needs `Owner` on the target resource group (or `Contributor` + `User Access Administrator`) so the role assignments module can wire the managed identity to Foundry, Storage, Key Vault, and Speech.
>
> **Quota:** realtime model capacity in shared subscriptions can be tight. The default is `10` TPM units; bump it down to `1` if a `quota exceeded` error appears mid-deploy.

## Re-skin without redeploying

Once running, every SE-facing setting can be changed live via the in-page config panel (model dropdown, voice picker, instructions textarea, custom voice fields, background URL).

For per-account demos:

1. Deploy once with your defaults.
2. Override any setting in the config panel before clicking **Start**.
3. Use the **Reset to deployed defaults** button to revert.

For background images, either:

- paste any public HTTPS URL into the **Background image URL** field, **or**
- upload to the deployed Storage account's `backgrounds` container and reference `https://<storage>.blob.core.windows.net/backgrounds/<file>`.

See [docs/customization.md](docs/customization.md) for screenshots and the full env-var contract.

## Repo layout

```
tmg-rewind-avatar/
├── infra/                  # Bicep + transpiled ARM + portal blade
│   ├── main.bicep
│   ├── main.parameters.json
│   ├── azuredeploy.json    # ← Deploy-to-Azure target (committed)
│   ├── createUiDefinition.json
│   └── modules/            # 9 modules: identity, monitoring, kv, storage,
│                           #            foundry, speech, caEnv, ca, roles
├── app/                    # vendored from microsoft-foundry/voicelive-samples
│   ├── app.py              # FastAPI server
│   ├── voice_handler.py    # Voice Live SDK bridge
│   ├── static/             # browser frontend (in-page config panel)
│   ├── Dockerfile          # non-root, healthcheck, multi-arch ready
│   ├── .env.example        # documents every env var
│   └── UPSTREAM_LICENSE    # MIT — Microsoft Corp.
├── .github/workflows/
│   ├── build-and-deploy.yml
│   └── bicep-validate.yml
├── scripts/
│   ├── bicep-to-arm.ps1
│   └── post-deploy-smoke.ps1
└── docs/
    ├── architecture.md
    ├── quickstart.md
    ├── customization.md
    ├── cost-note.md
    └── troubleshooting.md
```

## Deeper docs

- [`docs/quickstart.md`](docs/quickstart.md) — 5-minute SE deploy guide
- [`docs/architecture.md`](docs/architecture.md) — component diagram, request flow
- [`docs/customization.md`](docs/customization.md) — env-var reference + runtime reskin
- [`docs/cost-note.md`](docs/cost-note.md) — rough $/hr per workload profile
- [`docs/troubleshooting.md`](docs/troubleshooting.md) — common errors + fixes

## Attribution

Application code in `/app` is adapted from Microsoft's [`microsoft-foundry/voicelive-samples`](https://github.com/microsoft-foundry/voicelive-samples) (`python/voice-live-avatar/`), MIT licensed (Copyright © Microsoft Corporation). See [`NOTICE`](NOTICE) and [`app/UPSTREAM_LICENSE`](app/UPSTREAM_LICENSE).

The infrastructure, productization, and documentation are © 2026 Sammy Williams Jr., MIT licensed (see [`LICENSE`](LICENSE)).
