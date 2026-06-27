import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Play, Pause, Volume2, VolumeX, Settings2, Bluetooth } from 'lucide-react';

const API_URL = `/api`;

function App() {
  const [status, setStatus] = useState(null);
  
  const fetchStatus = async () => {
    try {
      const res = await axios.get(`${API_URL}/status`);
      setStatus(res.data);
    } catch (e) {
      console.error("Failed to fetch status", e);
    }
  };

  useEffect(() => {
    fetchStatus();
    const interval = setInterval(fetchStatus, 2000);
    return () => clearInterval(interval);
  }, []);

  const togglePlayback = async () => {
    await axios.post(`${API_URL}/playback/toggle`);
    fetchStatus();
  };

  const setVolume = async (nodeId, volume) => {
    await axios.post(`${API_URL}/volume`, { node_id: nodeId, volume });
    fetchStatus();
  };

  const toggleMute = async (nodeId, currentMuted) => {
    await axios.post(`${API_URL}/mute`, { node_id: nodeId, muted: !currentMuted });
    fetchStatus();
  };

  const setBluetoothMode = async (mode) => {
    await axios.post(`${API_URL}/bluetooth/mode`, { mode });
    fetchStatus();
  };

  if (!status) {
    return <div className="glass-panel" style={{textAlign: 'center'}}>Connecting to ALARI...</div>;
  }

  return (
    <div className="glass-panel">
      <div className="header">
        <h1>ALARI</h1>
        <p style={{color: 'var(--text-muted)', margin: '0.5rem 0 0'}}>Arch Linux Audio Receiver</p>
      </div>

      <div className="media-info">
        <div className="album-art"></div>
        <h2>{status.media.title}</h2>
        <p style={{color: 'var(--text-muted)'}}>{status.media.artist}</p>
      </div>

      <div className="controls">
        <button className="btn" onClick={togglePlayback}>
          {status.media.state === 'playing' ? <Pause size={24} /> : <Play size={24} />}
        </button>
      </div>

      <div className="section">
        <h3>Inputs / Sources</h3>
        {status.sources.map(src => (
          <div key={src.id} className="list-item">
            <span>{src.name}</span>
            <div style={{display: 'flex', alignItems: 'center', gap: '1rem'}}>
              <button 
                className={`btn ${src.muted ? 'danger' : ''}`} 
                style={{width: '36px', height: '36px'}}
                onClick={() => toggleMute(src.id, src.muted)}
              >
                {src.muted ? <VolumeX size={16} /> : <Volume2 size={16} />}
              </button>
              <input 
                type="range" 
                className="volume-slider"
                min="0" max="1" step="0.01" 
                value={src.volume}
                onChange={(e) => setVolume(src.id, parseFloat(e.target.value))}
              />
            </div>
          </div>
        ))}
      </div>

      <div className="section">
        <h3>Outputs / Sinks</h3>
        {status.outputs.map(out => (
          <div key={out.id} className="list-item">
            <span>{out.name}</span>
            <div style={{display: 'flex', alignItems: 'center', gap: '1rem'}}>
              <button 
                className={`btn ${out.muted ? 'danger' : ''}`} 
                style={{width: '36px', height: '36px'}}
                onClick={() => toggleMute(out.id, out.muted)}
              >
                {out.muted ? <VolumeX size={16} /> : <Volume2 size={16} />}
              </button>
              <input 
                type="range" 
                className="volume-slider"
                min="0" max="1" step="0.01" 
                value={out.volume}
                onChange={(e) => setVolume(out.id, parseFloat(e.target.value))}
              />
            </div>
          </div>
        ))}
      </div>

      <div className="section">
        <h3 style={{display: 'flex', alignItems: 'center', gap: '0.5rem'}}>
          <Bluetooth size={18} /> Bluetooth Mode
        </h3>
        <div className="mode-toggle">
          <button 
            className={`mode-btn ${status.bluetooth_mode === 'multi-point' ? 'active' : ''}`}
            onClick={() => setBluetoothMode('multi-point')}
          >
            Multi-Point (Switching)
          </button>
          <button 
            className={`mode-btn ${status.bluetooth_mode === 'simultaneous' ? 'active' : ''}`}
            onClick={() => setBluetoothMode('simultaneous')}
          >
            Simultaneous Mixer
          </button>
        </div>
      </div>
    </div>
  );
}

export default App;
