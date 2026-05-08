# Troubleshooting

## Deploy fails: "InsufficientQuota" on the realtime model deployment

The selected region doesn't have enough TPM units left for `gpt-realtime`.

- In the portal blade, lower **Realtime model capacity** to `1`.
- Or change **Region** to one of the others (Sweden Central, Japan East).
- Or open Azure Portal → AI Foundry → your account → quota → request more.

## Deploy fails: "AuthorizationFailed" on a roleAssignments resource

The principal running the deployment isn't allowed to grant RBAC.

- You need `Owner` on the target RG, or `Contributor` + `User Access Administrator`.
- A subscription Owner can grant `User Access Administrator` scoped to the RG before redeploying.

## Container App is healthy but the avatar never connects

Almost always WebRTC is being blocked.

- Try a different network (mobile hotspot is the fastest test).
- Some corp VPNs and proxies block UDP — disable VPN, or whitelist the Voice Live STUN/TURN endpoints.
- Check `https://<appUrl>/api/diag`. Confirm `endpoint_configured: true` and `model: gpt-realtime` (or whatever you set).

## "Cognitive Services Speech User" role assignment fails to find the principal

The UAMI hasn't propagated yet (Entra eventual consistency). Re-run the same deployment — Bicep is idempotent and the second pass will succeed.

## Stuck on "Connecting…" forever

1. Browser console → look for `WebSocket` or `ICE` errors.
2. Container App revision logs: `az containerapp logs show -n <name> -g <rg> --follow`.
3. Confirm the realtime model deployment exists and is `Succeeded` in the AI Foundry portal.

## App boots but `/api/config` returns blanks

The Container App env vars didn't bind. This usually means the deployment didn't actually update the revision (e.g. `az containerapp update` was run with no change). Force a new revision:

```powershell
az containerapp revision restart -n <name> -g <rg>
```

## Image pulls fail with `unauthorized` against ghcr.io

Most likely you're pointing at a private GHCR namespace. Either:

- Make the GHCR package public (Settings → Packages → tmg-rewind-avatar → Change visibility), **or**
- Override `containerImage` in the portal blade to a public mirror (e.g. push to a public Azure Container Registry and reference it).

## "ModuleNotFoundError: pyaudio" in container logs

This shouldn't happen in the deployed image (the upstream sample lists `pyaudio`, but it's only used when running with `VOICE_ENABLE_LOCAL_PLAYBACK=true` for local dev). If it appears, rebuild the image — base layer caches sometimes lag.

## Build workflow can't push to GHCR

`packages: write` permission isn't granted to the workflow. The provided workflow already sets it; if you copied a snippet without that block, add:

```yaml
permissions:
  contents: read
  packages: write
  id-token: write
```
