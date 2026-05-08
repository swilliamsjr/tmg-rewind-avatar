# Quickstart — Deploy in ≤10 minutes

You'll need:

- An Azure subscription where you are **Owner** (or Contributor + User Access Administrator).
- The subscription must be in a region that hosts Voice Live realtime models. At time of writing: **East US 2, Sweden Central, Japan East**.
- Realtime model quota of at least **10 TPM units**. (The portal will surface a warning mid-deploy if you don't.)

## 1. Click the button

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fswilliamsjr%2Ftmg-rewind-avatar%2Fmain%2Finfra%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fswilliamsjr%2Ftmg-rewind-avatar%2Fmain%2Finfra%2FcreateUiDefinition.json)

## 2. Fill in the blade

The form has three sections:

| Step | What to set | Notes |
|---|---|---|
| **Basics** | Subscription, resource group (create new), region, resource prefix | Prefix is 3–10 lowercase chars; everything else gets named after it. |
| **Avatar branding** | Realtime model + version, capacity, voice, character, background URL, system prompt | All become *defaults* — your audience can override at runtime. |
| **Sizing & image** | Workload profile, container image, replicas | Leave defaults unless you have a reason to change them. |

## 3. Wait for "Deployment succeeded"

Roughly 8–12 minutes. The slow steps are:

- Provisioning the AI Foundry (AIServices) account + project (~3 min).
- Creating the realtime model deployment (~2–3 min, longer if quota is tight).
- Pulling the container image and warming the first revision (~1–2 min).

When done, the **Outputs** tab gives you `appUrl`. That's your demo URL.

## 4. Open the demo

1. Open `appUrl` in Chrome or Edge.
2. Allow microphone access.
3. Confirm the in-page config panel shows your deployed defaults (voice, model, system prompt).
4. Click **Start** and start talking.

## 5. Optional — Run the smoke test

```powershell
git clone https://github.com/swilliamsjr/tmg-rewind-avatar
cd tmg-rewind-avatar
./scripts/post-deploy-smoke.ps1 -AppUrl "<your appUrl>"
```

This polls `/health` and prints `/api/config` + `/api/diag` so you can verify all env vars are wired exactly as the portal blade said.

## 6. Reskin per account

For each customer demo:

- Open the in-page config panel.
- Change voice / character / instructions / background URL to match the account.
- (Optional) Upload custom backgrounds into the deployed Storage account's `backgrounds` container — the URL pattern is `https://<storage>.blob.core.windows.net/backgrounds/<file>`.
- Click **Reset to deployed defaults** to revert at the end of the demo.

No redeploy needed — see [customization.md](customization.md) for the full runtime contract.
