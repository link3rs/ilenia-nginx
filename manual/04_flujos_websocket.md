# 4. Flujos y roles (manager / speaker / listeners) por WebSocket

## 4.1 Roles

- **Manager**: crea/gestiona una sesión y su configuración en vivo.
- **Speaker**: envía audio para transcribir/traducir.
- **Listener**: consume captions (y, en el futuro, audio) del evento.

## 4.2 Endpoints WebSocket (fase 1)

- `wss://<dominio>/ws/live/v2/manager/{session_id}`
- `wss://<dominio>/ws/live/v2/speaker/{session_id}`
- `wss://<dominio>/ws/live/v2/captions`

## 4.3 Flujo típico (alto nivel)

1. El **manager** abre la UI y crea o selecciona un evento/sesión.
2. La UI establece WebSocket a `.../manager/{session_id}`.
3. El **speaker** se conecta a `.../speaker/{session_id}` y comienza a enviar audio.
4. `live-service` procesa el audio:
   - ASR → texto
   - MT → textos por canal/idioma
5. Los **listeners** se conectan para recibir captions (p. ej. `.../captions`).

## 4.4 Consideraciones operativas

- Nginx debe incluir cabeceras `Upgrade` / `Connection` y mantener `proxy_read_timeout` alto para no cortar sesiones largas.
- En caso de reconexión de cliente, el backend debe ser capaz de restaurar/continuar la sesión en base a `session_id` (estado en Redis).
