from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import audio
import bluetooth

app = FastAPI(title="ALARI API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class VolumeRequest(BaseModel):
    node_id: int
    volume: float

class MuteRequest(BaseModel):
    node_id: int
    muted: bool

class BluetoothModeRequest(BaseModel):
    mode: str  # "multi-point" or "simultaneous"

@app.get("/api/status")
def get_status():
    status = audio.get_status()
    status["bluetooth_mode"] = bluetooth.get_mode()
    return status

@app.post("/api/playback/toggle")
def toggle_playback():
    audio.toggle_play_pause()
    return {"status": "success"}

@app.post("/api/volume")
def set_volume(req: VolumeRequest):
    if req.volume < 0.0 or req.volume > 1.0:
        raise HTTPException(status_code=400, detail="Volume must be between 0.0 and 1.0")
    audio.set_volume(req.node_id, req.volume)
    return {"status": "success"}

@app.post("/api/mute")
def set_mute(req: MuteRequest):
    audio.set_mute(req.node_id, req.muted)
    return {"status": "success"}

@app.post("/api/bluetooth/mode")
def set_bluetooth_mode(req: BluetoothModeRequest):
    if req.mode not in ["multi-point", "simultaneous"]:
        raise HTTPException(status_code=400, detail="Invalid bluetooth mode")
    return {"status": "success"}

from fastapi.staticfiles import StaticFiles
import os

# Mount the Vite built React app if it exists
if os.path.exists("/opt/alari/webui"):
    app.mount("/", StaticFiles(directory="/opt/alari/webui", html=True), name="static")
