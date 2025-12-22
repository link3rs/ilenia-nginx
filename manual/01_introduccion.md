# 1. Introducción

Este manual describe el software del sistema **Ilenia** para:

- Transcripción de voz a texto en tiempo real (ASR/STT).
- Traducción en tiempo real (MT).
- Distribución de subtítulos (captions) y control de sesiones en vivo mediante **WebSocket**.

El sistema está pensado para sesiones con:

- **Manager**: controla/configura la sesión (idiomas, endpoints, inicio/fin, etc.).
- **Speaker**: envía audio al sistema para transcribir/traducir.
- **Listeners**: reciben captions (y, si aplica, audio) en tiempo real.

## Estado actual (importante)

- **Transporte tiempo real**: actualmente el sistema opera con **WebSocket**.
- **WebRTC/LiveKit**: está previsto para futuras fases (distribución de audio y captions), pero **no está implementado** en el estado actual.
- **Persistencia/almacenamiento**:
  - En las fases iniciales se contemplaba almacenamiento externo (objetos, S3, etc.).
  - En el estado actual se considera almacenamiento **local en el droplet de DigitalOcean** (volúmenes Docker).

## Alcance de este repo

Este repositorio contiene la parte de **Nginx** como reverse proxy (y su despliegue) dentro del ecosistema Ilenia, y referencia las rutas principales hacia los microservicios.
