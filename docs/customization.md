# Customization

Two layers of customization:

1. **Deploy-time defaults** — set in the portal blade or `infra/main.parameters.json`; baked into Container App env vars.
2. **Runtime overrides** — changed in the in-page config panel; persisted in browser `localStorage`.

## Environment variable contract

The container reads these at startup. The frontend fetches them via `GET /api/config` and uses them as the initial values for every form field.

| Env var | Bicep parameter | Frontend field | Notes |
|---|---|---|---|
| `AZURE_VOICELIVE_ENDPOINT`              | (foundry output)            | endpoint                 | Foundry account endpoint |
| `AZURE_CLIENT_ID`                       | (UAMI output)               | —                        | Used by `DefaultAzureCredential` to pick the right managed identity |
| `VOICELIVE_MODEL`                       | `voiceLiveModel`            | Model dropdown           | `gpt-realtime`, `gpt-4o-mini-realtime`, or legacy preview names |
| `VOICELIVE_VOICE`                       | `defaultVoice`              | Voice                    | Any Azure Speech voice short name |
| `VOICELIVE_VOICE_TYPE`                  | (`standard`)                | Voice type               | `standard` / `custom` / `personal` |
| `VOICELIVE_INSTRUCTIONS`                | `defaultSystemPrompt`       | Model instructions       | Multi-line OK |
| `VOICELIVE_AVATAR_ENABLED`              | (`true`)                    | Avatar toggle            | |
| `VOICELIVE_AVATAR_CHARACTER`            | `defaultAvatarCharacter`    | Character dropdown       | `lisa`, `harry`, `layla` |
| `VOICELIVE_AVATAR_OUTPUT_MODE`          | (`webrtc`)                  | —                        | Don't change unless you know why |
| `VOICELIVE_IS_PHOTO_AVATAR`             | (`false`)                   | Photo avatar toggle      | |
| `VOICELIVE_IS_CUSTOM_AVATAR`            | (`false`)                   | Custom avatar toggle     | |
| `VOICELIVE_AVATAR_BG_URL`               | `defaultBackgroundImageUrl` | Background URL           | Empty falls back to `static/background.png` |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | (monitoring output)         | —                        | Telemetry sink |

The complete reference (including tuning vars) lives in `app/.env.example`.

## Re-skinning a deployment per customer

You almost never need to redeploy. From the demo browser:

1. Open the **Configuration** panel (left side).
2. Change voice, character, instructions, and background URL to match the customer.
3. *(Optional)* Upload a custom background to the deployed Storage account's `backgrounds` container, then paste its blob URL.
4. Click **Start** and run the demo.
5. After the demo, click **Reset to deployed defaults** to revert.

Browser `localStorage` keys are scoped per origin, so each SE's machine can hold their own overrides without affecting the deployed defaults.

## Uploading background images

The Bicep provisions a public-read blob container called `backgrounds` on the deployed storage account.

```powershell
$rg     = "rg-tmg-rewind-demo"
$st     = (az group show -n $rg --query 'tags.storageAccountName' -o tsv)
az storage blob upload `
    --account-name $st `
    --container-name backgrounds `
    --name dish-night.png `
    --file ./assets/dish-night.png `
    --auth-mode login
```

The URL is then `https://<st>.blob.core.windows.net/backgrounds/dish-night.png`.

> Switch the storage container to `private` and use a SAS token if you don't want backgrounds publicly fetchable.

## Switching realtime models

Change in the portal blade at deploy time, or after deploy:

```powershell
az containerapp update `
    --name <containerAppName> `
    --resource-group <rg> `
    --set-env-vars VOICELIVE_MODEL=gpt-4o-mini-realtime
```

Make sure the Foundry deployment of the new model exists — easiest is to redeploy with the desired `voiceLiveModel` parameter, or add a deployment via the AI Foundry portal.

## Forking the image

Default image is `ghcr.io/swilliamsjr/tmg-rewind-avatar:latest` (anonymous public pull).

To use your own:

1. Fork this repo.
2. Push to `main` — the `build-and-deploy` workflow will publish to your GHCR namespace.
3. Override `containerImage` in the portal blade with your image reference.
