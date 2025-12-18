# 99. Roadmap y funcionalidades previstas

## 99.1 WebRTC y LiveKit (pendiente)

Objetivo previsto:

- Distribución de audio y captions con menor latencia y mejor escalabilidad.
- Uso de LiveKit como SFU/infraestructura de tiempo real.

Estado:

- No implementado en el sistema actual.
- El transporte principal es WebSocket.

## 99.2 Persistencia externa (pendiente)

Objetivo previsto:

- Almacenar audios grabados y artefactos (texto, SRT) fuera del droplet.
- Facilitar backups, retención y distribución.

Estado actual:

- Se considera almacenamiento local mediante volúmenes Docker.

## 99.3 Separación event-service / live-service (pendiente)

Arquitectura prevista:

- `event-service` + PostgreSQL como fuente de verdad (eventos, canales, estado).
- `live-service` como runtime de streaming, consumiendo configuración del event-service y usando Redis para estado efímero.

Estado:

- Objetivo operativo alineado con el diagrama (Fase 2).
- Migración en curso desde persistencia JSON en `live-service` hacia PostgreSQL vía `event-service`.

## 99.4 auth-service (pendiente)

- Centralización de autenticación/autorización (tokens, roles).
- Protección de endpoints de manager/speaker y acciones sensibles.

Estado:

- Objetivo operativo alineado con el diagrama (Fase 2).
