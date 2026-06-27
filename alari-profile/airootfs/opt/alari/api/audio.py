import subprocess
import json
import re

def get_status():
    # Simple mock-like structure, but ideally would parse `pw-dump`
    # In a real scenario, we parse `pw-dump` which outputs JSON
    try:
        res = subprocess.run(['pw-dump'], capture_output=True, text=True, check=True)
        data = json.loads(res.stdout)
        
        # This is a highly simplified parser for pw-dump
        # We will extract nodes that are Audio/Sink and Audio/Source
        sinks = []
        sources = []
        
        for item in data:
            if item.get('type') == 'PipeWire:Interface:Node':
                info = item.get('info', {})
                props = info.get('props', {})
                media_class = props.get('media.class', '')
                
                node = {
                    'id': item.get('id'),
                    'name': props.get('node.description', props.get('node.name', f"Node {item.get('id')}")),
                    'volume': 0.5, # We'd parse this from props if available
                    'muted': False
                }
                
                if 'Audio/Sink' in media_class:
                    sinks.append(node)
                elif 'Audio/Source' in media_class:
                    sources.append(node)
                    
        return {
            'media': {
                'title': 'Unknown Title',
                'artist': 'Unknown Artist',
                'state': 'playing'
            },
            'sources': sources if sources else [{'id': 1, 'name': 'Dummy Source', 'volume': 0.8, 'muted': False}],
            'outputs': sinks if sinks else [{'id': 2, 'name': 'Dummy Output', 'volume': 0.5, 'muted': False}]
        }
    except Exception as e:
        # Fallback if pw-dump fails (e.g. running outside pipewire environment)
        return {
            'media': {
                'title': 'No Audio Server',
                'artist': 'Check Pipewire',
                'state': 'paused'
            },
            'sources': [{'id': 1, 'name': 'Dummy Source', 'volume': 0.8, 'muted': False}],
            'outputs': [{'id': 2, 'name': 'Dummy Output', 'volume': 0.5, 'muted': False}]
        }

def set_volume(node_id: int, volume: float):
    # wpctl set-volume <id> <volume>
    subprocess.run(['wpctl', 'set-volume', str(node_id), str(volume)])

def set_mute(node_id: int, mute: bool):
    # wpctl set-mute <id> 1/0
    val = "1" if mute else "0"
    subprocess.run(['wpctl', 'set-mute', str(node_id), val])

def toggle_play_pause():
    # Example using playerctl if available, or just mocking
    subprocess.run(['playerctl', 'play-pause'], check=False)
