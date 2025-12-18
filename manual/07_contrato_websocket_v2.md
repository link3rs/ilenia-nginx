# 7. Contrato WebSocket (v2) y formato CloudEvents

Este capítulo documenta el **contrato actual** observado en el código del servicio `ilenia-live-event-service`.

## 7.1 Prefijos de ruta (Nginx)

En producción, Nginx enruta y “recorta” el prefijo `/ws/live` hacia el backend.

- Cliente (producción): `wss://<dominio>/ws/live/v2/...`
- Backend (live-service): `ws://live-service:8082/v2/...`

## 7.2 WebSocket de manager (v2) — control de sesión

### URL

- `wss://<dominio>/ws/live/v2/manager/{session_id}?access_token=<JWT>`

### Autenticación

- Se valida un JWT vía `verify_access_token(..., required_role="manager")`.
- Si el token es inválido o no contiene `sub`, el servidor puede cerrar la conexión.
- Si existe una sesión con un `manager_user_id` distinto, el servidor responde:
  - `{"type":"error","error":"manager_mismatch"}`
  - y cierra con código `4403`.

### Mensajes del servidor

- **Sync inicial**
  - `{"type":"session_sync","state": <SessionState>}`

- **Actualización de estado** (broadcast)
  - `{"type":"session_status","status":"open|live|closed"}`

- **Parámetros actualizados** (broadcast)
  - `{"type":"params_updated","params": <dict>}`

- **Listas de acceso** (broadcast a roles)
  - A speakers:
    - `{"type":"allowed_speakers","list":["<user_id>", ...]}`
  - A listeners:
    - `{"type":"allowed_listeners","list":["<user_id>", ...]}`

- **Kick**
  - `{"type":"kicked"}`

- **Heartbeat ack**
  - `{"type":"heartbeat_ack"}`

- **Errores genéricos**
  - `{"type":"error","error":"unknown_type","got":"..."}`
  - `{"type":"error","error":"<exception>"}`

### Mensajes del cliente (manager)

- `{"type":"open"}`
- `{"type":"start_live"}`
- `{"type":"close"}`
- `{"type":"update_params","params":{...}}`
- `{"type":"allow_speaker","user_id":"..."}`
- `{"type":"remove_speaker","user_id":"..."}`
- `{"type":"allow_listener","user_id":"..."}`
- `{"type":"kick","role":"speaker|listener"}`
- `{"type":"heartbeat"}`

## 7.3 WebSocket de speaker (v2) — audio + pipeline STT/MT/TTS

### URL

- `wss://<dominio>/ws/live/v2/speaker/{event_id}/{channel_id}`

### Formato de mensajes: CloudEvents

El speaker v2 usa un sobre **CloudEvent** con `data` conteniendo el mensaje real. Ejemplo de estructura:

```json
{
  "specversion": "1.0",
  "id": "01J...",
  "source": "ilenia-live-event-service",
  "type": "<cloud_event_type>",
  "time": "2025-...Z",
  "subject": "<session_id>",
  "datacontenttype": "application/json",
  "data": {
    "message": "<MessageType>",
    "...": "..."
  }
}
```

Notas:

- En el código, el `type` del CloudEvent se obtiene de un mapping del protocolo generado.
- Para traducciones (`AddTranslation`) se usa explícitamente: `type = "live.translation"`.

### Handshake / estados (secuencia)

1. El cliente se conecta.
2. El cliente envía un CloudEvent con `data.message = "SessionCreate"`.
3. El servidor responde con CloudEvent `SessionCreated` (e incluye flags `enabledSTT/MT/TTS`).
4. El cliente envía `StartRecognition` con configuración del formato de audio y transcripción.
5. El servidor responde `RecognitionStarted`.
6. Streaming:
   - El cliente envía **frames binarios** (`bytes`) con audio.
   - El servidor responde `AudioAdded` (ack de `seq_no`).
   - El servidor envía transcripciones (`AddPartialTranscript` opcional y `AddTranscript` final).
   - El servidor envía traducciones (`AddTranslation`).
7. El cliente envía `EndOfStream` (JSON/CloudEvent).
8. El servidor responde `EndOfTranscript`.
9. El cliente envía `SessionDestroy`.
10. El servidor responde `SessionDestroyed`.

### `SessionCreate` (cliente → servidor)

Campos principales (según modelo Pydantic):

- `eventName` (str)
- `description` (opcional)
- `speakerChannel` (int)
- `channels` (lista de `Channel`)
- `broadcastLiveKit` (bool; previsto, no implementado actualmente)
- `enableSTT` (bool)
- `enableMT` (bool)
- `enableTTS` (bool)
- `hfConfig` (opcional): `{HF_ASR_URL, HF_ASR_TOKEN, HF_MT_URL, HF_MT_TOKEN}`

El servidor genera `session_id` como:

- `{event_id}_{channel_id}_{source_lang}`

El `source_lang` se obtiene del `Channel` cuyo `id == speakerChannel`.

### `StartRecognition` (cliente → servidor)

- `audio_format`:
  - `type: "raw"`
  - `encoding: "pcm_f32le" | "pcm_s16le" | "mulaw"`
  - `sample_rate: <int>`
- `transcription_config`:
  - `language: <str>`
  - `enable_partials: <bool>`
  - `max_delay: <float>`

### Audio binario (cliente → servidor)

- Tras `StartRecognition`, el cliente envía audio en binario por el socket.
- El servidor incrementa `seq_no` a partir de 1.
- Si el encoding es `pcm_f32le`, el servidor convierte a int16 antes de procesar.

### Mensajes del servidor (speaker)

- `SessionCreated` (incluye `enabledSTT/MT/TTS`)
- `RecognitionStarted`
- `AudioAdded`
- `AddPartialTranscript` (si `enable_partials` está activo y hay texto)
- `AddTranscript` (final)
- `AddTranslation` (traducciones por idioma objetivo)
- `EndOfTranscript`
- `SessionDestroyed`

## 7.4 WebSocket de captions (listeners)

### URL (backend)

- `wss://<dominio>/ws/live/v2/captions/{event_id}/{lang_code}`

El canal interno que usa el backend para gestionar listeners se construye como:

- `{event_id}_{lang_code}`

### Keep-alive

- El servidor envía `"ping"` cada ~30s.
- El cliente puede responder `"pong"`.

### Mensajes

- Los listeners reciben los CloudEvents que el speaker produce (al menos `AddTranscript` para `source_lang` y `AddTranslation` para los idiomas objetivo), broadcast a su canal `{event_id}_{lang_code}`.

## 7.5 Inconsistencias conocidas (importante)

Según el `README.md` del reverse proxy, existen rutas documentadas como:

- `/ws/live/v2/captions` (sin path params)
- `/ws/live/v2/speaker/{session_id}`
- `/ws/live/v2/manager/{session_id}`

Pero el **código actual** del `live-event-service` expone:

- `GET/WS /v2/captions/{event_id}/{lang_code}`
- `WS /v2/speaker/{event_id}/{channel_id}`
- `WS /v2/manager/{session_id}`

Este manual toma como “fuente de verdad” el **código actual**. Si quieres, en un siguiente paso puedo:

- actualizar la documentación del repo `ilenia-nginx/README.md` para reflejar las rutas reales, o
- documentar una tabla de compatibilidad entre rutas antiguas y rutas vigentes.
