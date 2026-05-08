"""
TMG Rewind Avatar — Python Backend
=================================
FastAPI server that bridges browser WebSocket with the Azure Voice Live SDK.
Avatar video streams via WebRTC directly to the browser; audio and events
are relayed through this server.

Vendored and adapted from microsoft-foundry/voicelive-samples
(python/voice-live-avatar) under MIT license — see app/UPSTREAM_LICENSE.

Modifications vs. upstream:
  - Added /api/diag endpoint for SE troubleshooting (echoes non-secret config).
  - Container-Apps-friendly Dockerfile (non-root, healthcheck) lives alongside.
"""

import asyncio
import json
import logging
import os
from contextlib import asynccontextmanager
from typing import Dict

import uvicorn
from azure.identity.aio import DefaultAzureCredential
from dotenv import load_dotenv
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.staticfiles import StaticFiles

from voice_handler import VoiceSessionHandler

load_dotenv()

# Logging with color
class ColorFormatter(logging.Formatter):
    """Custom formatter that adds ANSI color codes to log output."""
    COLORS = {
        logging.DEBUG:    "\033[36m",     # Cyan
        logging.INFO:     "\033[32m",     # Green
        logging.WARNING:  "\033[33m",     # Yellow
        logging.ERROR:    "\033[31m",     # Red
        logging.CRITICAL: "\033[1;31m",   # Bold Red
    }
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    WHITE = "\033[97m"

    def format(self, record):
        color = self.COLORS.get(record.levelno, self.RESET)
        # Timestamp in dim, level in color+bold, name in dim, message in white
        timestamp = self.formatTime(record, self.datefmt)
        return (
            f"{self.DIM}{timestamp}{self.RESET} "
            f"{color}{self.BOLD}{record.levelname:<8}{self.RESET} "
            f"{self.DIM}{record.name}{self.RESET} "
            f"{self.WHITE}{record.getMessage()}{self.RESET}"
        )

handler = logging.StreamHandler()
handler.setFormatter(ColorFormatter())
logging.basicConfig(
    level=logging.INFO,
    handlers=[handler],
)
logger = logging.getLogger(__name__)

# Track active sessions per client
active_sessions: Dict[str, VoiceSessionHandler] = {}
active_tasks: Dict[str, asyncio.Task] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Voice Live Avatar server starting...")
    yield
    # Cleanup all sessions on shutdown
    for client_id in list(active_sessions.keys()):
        handler = active_sessions.get(client_id)
        if handler:
            await handler.stop()
    active_sessions.clear()
    active_tasks.clear()
    logger.info("Voice Live Avatar server stopped.")


app = FastAPI(
    title="Voice Live Avatar",
    description="Python backend for Azure Voice Live with Avatar support",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def no_cache_static(request, call_next):
    """Disable caching for static assets during development."""
    response = await call_next(request)
    path = request.url.path
    if path.endswith((".js", ".css", ".html")) or path == "/":
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "tmg-rewind-avatar"}


@app.get("/api/diag")
async def diag():
    """
    Lightweight diagnostics for SEs. Returns non-secret configuration so
    a Solution Engineer can confirm the deployed defaults are wired
    without needing portal access. Never returns tokens or connection
    strings — only their presence is reported.
    """
    endpoint = os.getenv("AZURE_VOICELIVE_ENDPOINT", "")
    appi_conn = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING", "")
    return {
        "service": "tmg-rewind-avatar",
        "endpoint_configured": bool(endpoint),
        "endpoint_host": endpoint.split("//", 1)[-1].split("/", 1)[0] if endpoint else "",
        "model": os.getenv("VOICELIVE_MODEL", ""),
        "voice": os.getenv("VOICELIVE_VOICE", ""),
        "voice_type": os.getenv("VOICELIVE_VOICE_TYPE", ""),
        "avatar_enabled": os.getenv("VOICELIVE_AVATAR_ENABLED", ""),
        "avatar_character": os.getenv("VOICELIVE_AVATAR_CHARACTER", ""),
        "background_url_set": bool(os.getenv("VOICELIVE_AVATAR_BG_URL", "")),
        "instructions_chars": len(os.getenv("VOICELIVE_INSTRUCTIONS", "")),
        "app_insights_configured": bool(appi_conn),
        "active_sessions": len(active_sessions),
    }


@app.get("/api/config")
async def get_config():
    """Return default configuration to the frontend."""
    return {
        "model": os.getenv("VOICELIVE_MODEL", "gpt-4o-realtime"),
        "voice": os.getenv("VOICELIVE_VOICE", "en-US-AvaMultilingualNeural"),
        "endpoint": os.getenv("AZURE_VOICELIVE_ENDPOINT", ""),
        "entraToken": True,
        "useNS": os.getenv("VOICELIVE_USE_NS", ""),
        "useEC": os.getenv("VOICELIVE_USE_EC", ""),
        "turnDetectionType": os.getenv("VOICELIVE_TURN_DETECTION", ""),
        "removeFillerWords": os.getenv("VOICELIVE_REMOVE_FILLER_WORDS", ""),
        "instructions": os.getenv("VOICELIVE_INSTRUCTIONS", ""),
        "enableProactive": os.getenv("VOICELIVE_ENABLE_PROACTIVE", ""),
        "temperature": os.getenv("VOICELIVE_TEMPERATURE", ""),
        "voiceType": os.getenv("VOICELIVE_VOICE_TYPE", ""),
        "voiceTemperature": os.getenv("VOICELIVE_VOICE_TEMPERATURE", ""),
        "voiceSpeed": os.getenv("VOICELIVE_VOICE_SPEED", ""),
        "avatarEnabled": os.getenv("VOICELIVE_AVATAR_ENABLED", ""),
        "avatarOutputMode": os.getenv("VOICELIVE_AVATAR_OUTPUT_MODE", ""),
        "isPhotoAvatar": os.getenv("VOICELIVE_IS_PHOTO_AVATAR", ""),
        "isCustomAvatar": os.getenv("VOICELIVE_IS_CUSTOM_AVATAR", ""),
        "avatarName": os.getenv("VOICELIVE_AVATAR_CHARACTER", ""),
        "avatarBackgroundImageUrl": os.getenv("VOICELIVE_AVATAR_BG_URL", ""),
    }


@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    """Main WebSocket endpoint for voice session communication."""
    await websocket.accept()
    logger.info(f"Client {client_id} connected")

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            await handle_message(client_id, message, websocket)
    except WebSocketDisconnect:
        logger.info(f"Client {client_id} disconnected")
    except Exception as e:
        logger.error(f"WebSocket error for {client_id}: {e}")
    finally:
        await cleanup_client(client_id)


async def handle_message(client_id: str, message: dict, websocket: WebSocket):
    """Route incoming WebSocket messages."""
    msg_type = message.get("type")

    if msg_type == "start_session":
        await start_session(client_id, message.get("config", {}), websocket)

    elif msg_type == "stop_session":
        await stop_session(client_id)

    elif msg_type == "audio_chunk":
        handler = active_sessions.get(client_id)
        if handler:
            await handler.send_audio(message.get("data", ""))

    elif msg_type == "send_text":
        handler = active_sessions.get(client_id)
        if handler:
            await handler.send_text_message(message.get("text", ""))

    elif msg_type == "avatar_sdp_offer":
        handler = active_sessions.get(client_id)
        if handler:
            await handler.send_avatar_sdp_offer(message.get("clientSdp", ""))

    elif msg_type == "interrupt":
        handler = active_sessions.get(client_id)
        if handler:
            await handler.interrupt()

    elif msg_type == "update_scene":
        handler = active_sessions.get(client_id)
        if handler:
            await handler.update_avatar_scene(message.get("avatar", {}))

    else:
        logger.warning(f"Unknown message type: {msg_type}")


async def start_session(client_id: str, config: dict, websocket: WebSocket):
    """Start a new Voice Live session for a client."""
    # Clean up any existing session
    await cleanup_client(client_id)

    # Prefer endpoint from frontend config, fall back to env var
    endpoint = config.get("endpoint", "").strip() or os.getenv("AZURE_VOICELIVE_ENDPOINT", "")
    entra_token = config.get("entraToken", "").strip()

    if not endpoint:
        await send_ws_message(websocket, {
            "type": "session_error",
            "error": "Azure AI Services Endpoint is required. Provide it in the UI or set AZURE_VOICELIVE_ENDPOINT.",
        })
        return

    # Create credential: prefer Entra token (for agent modes), otherwise Managed Identity
    if entra_token:
        from azure.core.credentials import AccessToken
        import time

        class _StaticTokenCredential:
            """Wraps a raw token string as an async TokenCredential."""
            def __init__(self, token: str):
                self._token = token
            async def get_token(self, *scopes, **kwargs):
                return AccessToken(self._token, int(time.time()) + 3600)
            async def close(self): pass
            async def __aenter__(self): return self
            async def __aexit__(self, *args): pass

        credential = _StaticTokenCredential(entra_token)
    else:
        credential = DefaultAzureCredential()

    async def send_message(msg: dict):
        try:
            await websocket.send_text(json.dumps(msg))
        except Exception as e:
            logger.error(f"Error sending to {client_id}: {e}")

    handler = VoiceSessionHandler(
        client_id=client_id,
        endpoint=endpoint,
        credential=credential,
        send_message=send_message,
        config=config,
    )
    active_sessions[client_id] = handler

    # Run session in background task
    task = asyncio.create_task(handler.start())
    active_tasks[client_id] = task
    logger.info(f"Session started for {client_id}")


async def stop_session(client_id: str):
    """Stop an active session."""
    await cleanup_client(client_id)


async def cleanup_client(client_id: str):
    """Clean up session and task for a client."""
    handler = active_sessions.pop(client_id, None)
    if handler:
        await handler.stop()

    task = active_tasks.pop(client_id, None)
    if task and not task.done():
        task.cancel()
        try:
            await task
        except (asyncio.CancelledError, Exception):
            pass


async def send_ws_message(websocket: WebSocket, message: dict):
    """Send a JSON message via WebSocket."""
    try:
        await websocket.send_text(json.dumps(message))
    except Exception as e:
        logger.error(f"Error sending WebSocket message: {e}")


# Mount static files (frontend)
static_path = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_path):
    app.mount("/", StaticFiles(directory=static_path, html=True), name="static")
else:
    @app.get("/")
    async def root():
        return {"message": "Voice Live Avatar - static files not found. Place frontend in ./static/"}


if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=3000, reload=True, log_level="info")
