# Ilenia Platform - Ecosistema Completo

## Visión General
Plataforma de eventos en vivo con transcripción automática (STT), traducción en tiempo real (MT), y distribución de audio/subtítulos multiidioma. Arquitectura de microservicios con autenticación JWT centralizada y **sistema dual de difusión**:

- **Modo WebSocket** (legacy): Subtítulos vía WebSocket
- **Modo LiveKit** (nuevo): Audio original + traducciones vía WebRTC

## Patrón de Arquitectura Estándar

### PersistenceProvider Pattern (Recomendado)

Todos los servicios del ecosistema deben seguir el patrón **Strategy + Dependency Injection** para la capa de persistencia, permitiendo múltiples backends sin cambiar la lógica de negocio.

**Arquitectura estándar**:
```
┌─────────────────────────────────────────────────────┐
│              FastAPI Application                    │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │   get_handler()                              │  │
│  │   USE_<SERVICE>_MOCK?                        │  │
│  └──────┬───────────────────────────────────────┘  │
│         │                                           │
│    ┌────┴─────┐                                    │
│    │          │                                    │
│  Mock       Prod                                   │
│    │          │                                    │
│    │    ┌─────┴──────────┐                        │
│    │    │ Persistence    │                        │
│    │    │  Provider      │                        │
│    │    │  (injected)    │                        │
│    │    └─────┬──────────┘                        │
│    │          │                                    │
│    │    ┌─────┴──────┐                            │
│    │    │            │                            │
│    │  InMemory   PostgreSQL                       │
│    │    │            │                            │
│    │  storage/*  repositories/*                   │
└────┴────┴────────────┴─────────────────────────────┘
```

### Estructura de Archivos Estándar

```
src/
├── persistence/
│   ├── __init__.py
│   ├── base.py              # PersistenceProvider (ABC)
│   ├── in_memory.py         # PersistenceInMemory
│   └── postgresql.py        # PersistencePostgreSQL
├── api_<service>/runtime/
│   ├── handler_prod.py      # Handler principal (refactorizado con DI)
│   ├── handler_mock.py      # Handler mock para testing
│   ├── handlers.py          # Protocol + get_handler() + get_persistence()
│   └── <service>_server.py  # Carga de implementaciones
├── db/
│   ├── models.py            # SQLAlchemy models
│   ├── database.py          # Async engine y session
│   └── startup.py           # Lifespan y seed
├── repositories/           # Para PostgreSQL (async)
│   ├── <entity>_repo.py
│   └── ...
├── storage/                # Para InMemory (legacy)
│   ├── <entity>_storage.py
│   └── ...
├── services/               # Lógica de negocio (opcional)
└── config.py               # USE_DATABASE + USE_<SERVICE>_MOCK
```

### Variables de Entorno Estándar

```bash
# Handler selection
USE_<SERVICE>_MOCK=false    # true = Mock handler (testing)
                            # false = Prod handler (production)

# Persistence selection (only for Prod handler)
USE_DATABASE=false          # true = PostgreSQL (production)
                            # false = InMemory (development)

# Database configuration
DATABASE_URL=postgresql+asyncpg://user:pass@host:5432/<service>_db
```

### Modos de Operación Estándar

| Modo | USE_<SERVICE>_MOCK | USE_DATABASE | Handler | Persistence | Uso |
|------|-------------------|--------------|---------|-------------|-----|
| **Desarrollo** | false | false | Prod | InMemory | Desarrollo sin PostgreSQL |
| **Producción** | false | true | Prod | PostgreSQL | Producción con persistencia |
| **Testing** | true | - | Mock | - | Tests unitarios |

### Ventajas del Patrón

1. **Separation of Concerns**: Handler (lógica) vs Persistence (datos)
2. **Dependency Injection**: Handler recibe Persistence como parámetro
3. **Strategy Pattern**: Cambiar backend sin cambiar handler
4. **Testabilidad**: Mock handler para tests, Prod para producción
5. **DRY**: Un solo handler de producción, múltiples backends
6. **Flexibilidad**: Fácil agregar Redis, MongoDB, etc.
7. **Consistencia**: Todos los servicios siguen la misma arquitectura

### Servicios que Implementan el Patrón

- ✅ **ilenia-auth-service** (v3.0.0) - Implementación completa con PostgreSQL
- 🚧 **ilenia-events-service** - En proceso de implementación
- ⏳ **ilenia-livekit-provider** - Pendiente de implementar
- ⏳ **ilenia-live-service** - Pendiente de implementar

## Arquitectura del Ecosistema

```
┌───────────────────────────────────────────────────────────────────────┐
│                            Internet                                   │
└──────────────────────────────┬────────────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────────────┐
│                      Nginx Reverse Proxy                              │
│                     (SSL/TLS, Rate Limiting)                          │
│                     ilenia.link3rs.com:443                            │
└───┬──────────┬──────────┬──────────┬──────────┬──────────┬────────────┘
    │          │          │          │          │          │
    │          │          │          │          │          │
┌───▼────┐ ┌───▼─────┐┌───▼─────┐┌───▼─────┐┌───▼─────┐┌───▼─────────┐
│ React  │ │LiveEvent││  Live   ││  Auth   ││ Events  ││  LiveKit    │
│Frontend│ │ Service ││ Service ││ Service ││Service  ││  Provider   │
│  (SPA) │ │WebSocket││LiveKit/ ││  (JWT)  ││(Postgres││  (WebRTC)   │
│        │ │ (LEGACY)││ Agents  ││         ││  CRUD)  ││             │
│  :5173 │ │  :8082  ││  :8092  ││  :8081  ││  :8083  ││   :8086     │
└────────┘ └────┬────┘└────┬────┘└─────────┘└─────────┘└──────┬──────┘
                │          │                                  │
                │          │                                  │
         ┌──────┴──────────┴──────────────┐          ┌────────▼──────┐
         │                                │          │               │
    ┌────▼─────┐                    ┌─────▼──────┐   │  LiveKit      │
    │  Redis   │                    │ HuggingFace│   │  Server       │
    │ (Cache)  │                    │  Endpoints │   │ (WebRTC/SFU)  │
    │  :6379   │                    │ (ASR, MT)  │   │               │
    └──────────┘                    └────────────┘   └───────────────┘

VITE_BROADCAST_LIVEKIT=false → ilenia-live-event-service (WebSocket)
VITE_BROADCAST_LIVEKIT=true  → ilenia-live-service (LiveKit/WebRTC)
```

## Proyectos del Workspace

### 1. Frontend React (`ilenia-react-frontend`)
**Ubicación**: `/Users/link3rs/Developer/JSWorkshop/github.com/link3rs/ilenia-react-frontend`
**Tecnología**: React, TypeScript, Vite, TailwindCSS
**Puerto**: 5173 (dev), 80 (producción vía Nginx)
**Rutas Principales**:
- `/en/speak/{event_id}/{channel_id}` - Vista de speaker
- `/en/listen/{event_id}` - Vista de listener
- `/en/manage/{event_id}` - Vista de manager

**Función**:
- Interfaz de usuario para gestión de eventos
- **Modo WebSocket**: Cliente WebSocket para subtítulos (VITE_BROADCAST_LIVEKIT=false)
- **Modo LiveKit**: Cliente LiveKit para audio/traducciones (VITE_BROADCAST_LIVEKIT=true)
- Dashboard para speakers, listeners y managers
- Creación automática de LiveKit rooms al acceder a speak/listen

### 2. Auth Service (`ilenia-auth-service`)
**Ubicación**: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-auth-service`
**Tecnología**: Python, FastAPI, PostgreSQL 16, JWT (RS256), SQLAlchemy 2.0, Alembic
**Puerto**: 8081
**API version**: v2

**Función**:
- Autenticación y autorización centralizada
- Emisión de JWT con firma RSA (RS256)
- **Modelo híbrido RBAC**: User N:M Role + Custom Permissions (add/remove)
- Roles como templates con permisos por defecto
- Custom permissions: añadir/quitar permisos específicos sobre los del rol
- Auditoría completa (granted_by, granted_at en custom_permissions)
- Refresh tokens con HttpOnly cookies
- **OAuth2 client credentials (S2S)** - Para `ilenia-live-service`
- JWKS endpoint para verificación de tokens: `/v2/.well-known/jwks.json`
- **Migraciones Alembic** como única fuente de verdad

**Arquitectura**: ✅ **PersistenceProvider Pattern implementado**
- Handler de producción con Dependency Injection
- PostgreSQL (producción) + InMemory (desarrollo) + Mock (testing)
- Variables: `USE_AUTH_MOCK=false`, `USE_DATABASE=true`

**Arquitectura RBAC**:
- Usuarios pueden tener múltiples roles
- Roles definen permisos por defecto (templates)
- Custom permissions para añadir/quitar permisos sin cambiar roles
- Flexibilidad total con auditoría completa

**Base de Datos**:
- PostgreSQL 16 con SQLAlchemy 2.0 async
- Migraciones Alembic (única fuente de verdad)
- Flujo: OpenAPI Spec → DTOs → SQLAlchemy Models → Alembic → PostgreSQL

**Estado**: ✅ Operativo (v3.0.0)
 
### 3 Live Event Service - WebSocket (LEGACY) (`ilenia-live-event-service`)
**Ubicación**: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-live-event-service`
**Tecnología**: Python, FastAPI, WebSocket, Redis
**Puerto**: 8082
**Función** (Modo WebSocket Legacy):
- Captura de audio de speakers vía WebSocket
- Transcripción de audio (STT) vía HuggingFace
- Traducción de texto (MT) vía HuggingFace
- Distribución de subtítulos en tiempo real (WebSocket a listeners)
- Grabación de audio

**Estado**: ✅ Operativo - Se mantiene para retrocompatibilidad
**Migración**: CRUD de eventos delegado a `ilenia-events-service`

### 4 Live Service - LiveKit/Agents (NUEVO) (`ilenia-live-service`)
**Ubicación**: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-live-service` (a crear)
**Tecnología**: Python, FastAPI, LiveKit SDK, Agentes
**Puerto**: 8092
**Función** (Modo LiveKit):
- Orquestación de sesión de transcripción/traducción vía LiveKit agents
- Genera token S2S (OAuth2) para autenticarse con otros servicios
- Recupera configuración de evento desde `ilenia-events-service`
- Solicita tokens de LiveKit para agentes (ASR, MT, etc.) a `ilenia-livekit-provider`
- Coordina agentes LiveKit para procesamiento en tiempo real
- Difusión de audio original + traducciones vía LiveKit rooms

**Estado**: 🚧 En desarrollo - Sustituirá a `ilenia-live-event-service`

## 5. Events Service (`ilenia-events-service`)
**Ubicación**: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-events-service`
**Tecnología**: Python, FastAPI, PostgreSQL 16, SQLAlchemy 2.0, Alembic
**Puerto**: 8083
**API version**: v1

**Función**:
- **CRUD persistente de eventos** (PostgreSQL) - Fuente de verdad
- Gestión completa de metadata: título, descripción, fechas, canales
- Asignación de speakers y listeners
- Configuración de idiomas (source/target) por canal
- Gestión de estado del evento (draft, ready, live, ended)
- Templates de eventos para reutilización
- Provee configuración a `ilenia-live-service` y `ilenia-live-event-service`

**Arquitectura**: 🚧 **En proceso de migrar a PersistenceProvider Pattern**
- Modelos SQLAlchemy 2.0 creados
- Migraciones Alembic configuradas
- Pendiente: Refactorizar handlers para usar Dependency Injection
- Variables planificadas: `USE_EVENT_MOCK`, `USE_DATABASE`

**Base de Datos**:
- PostgreSQL 16 con SQLAlchemy 2.0 async
- Migraciones Alembic
- Docker Compose con PostgreSQL configurado

**Estado**: 🚧 En desarrollo activo - CRUD operativo con PostgreSQL

## 6. LiveKit Provider (`ilenia-livekit-provider`)
**Ubicación**: `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-livekit-provider`
**Tecnología**: Python, FastAPI, LiveKit SDK, WebRTC
**Puerto**: 8086
**API version**: v2

**Función**:
- **Gestión de LiveKit rooms** (crear, cerrar)
- **Emisión de tokens de acceso**:
  - Tokens de speaker (publish audio)
  - Tokens de listener (subscribe audio)
  - Tokens de agentes (ASR, MT) - Para `ilenia-live-service`
- Interfaz con LiveKit Server (Cloud o self-hosted)
- NO gestiona datos de eventos (delegado a `ilenia-events-service`)

**Arquitectura**: ⏳ **Pendiente migrar a PersistenceProvider Pattern**
- Actualmente stateless (no persiste datos propios)
- Evaluación pendiente: ¿Necesita persistencia local para logs/auditoría?
- Si sí: Implementar PersistenceProvider con PostgreSQL

**Estado**: 🚧 En desarrollo activo

### 6. Nginx Reverse Proxy (`ilenia-nginx`)
**Ubicación**: `/Users/link3rs/Developer/NginxWorkshop/github.com/link3rs/ilenia-nginx`
**Tecnología**: Nginx, Docker, Let's Encrypt
**Puertos**: 80 (HTTP), 443 (HTTPS)
**Función**:
- Reverse proxy para todos los servicios
- SSL/TLS con Let's Encrypt
- Rate limiting y CORS
- WebSocket upgrade para `/ws/*`
- Orquestación de servicios con Docker Compose

### 7. API Specs (`ilenia-apis-specs`)
**Ubicación**: `/Users/link3rs/Developer/SpecsWorkshop/github.com/link3rs/ilenia-apis-specs`
**Tecnología**: OpenAPI 3.1, AsyncAPI 3.0, Redocly
**Función**:
- **FUENTE DE VERDAD** para todas las APIs del ecosistema
- Especificaciones de todas las APIs REST (OpenAPI 3.1)
- Especificaciones de protocolos WebSocket (AsyncAPI 3.0)
- Generación de SDKs (Python, TypeScript)
- Generación de modelos TypeScript para WebSocket
- Documentación interactiva
- Validación y bundling de specs

**Flujo de Trabajo para APIs**:
1. Editar specs en `ilenia-apis-specs`
2. Validar: `npm run check-{service}`
3. Copiar bundle al servicio correspondiente
4. Generar código: `./scripts/generate-openapi-server.sh`

**Repositorios del Ecosistema**:

| Servicio | Repositorio | Directorio local | Puerto |
|----------|-------------|------------------|--------|
| Auth | ilenia-auth-service | `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-auth-service` | 8081 |
| Events | ilenia-events-service | `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-events-service` | 8083 |
| LiveKit | ilenia-livekit-provider | `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-livekit-provider` | 8086 |
| Live Event (WS) | ilenia-live-event-service | `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-live-event-service` | 8082 |
| Live (LiveKit) | ilenia-live-service | `/Users/link3rs/Developer/PythonWorkshop/github.com/link3rs/ilenia-live-service` | 8092 |
| Frontend | ilenia-react-frontend | `/Users/link3rs/Developer/JSWorkshop/github.com/link3rs/ilenia-react-frontend` | 5173 |
| Nginx | ilenia-nginx | `/Users/link3rs/Developer/NginxWorkshop/github.com/link3rs/ilenia-nginx` | 80/443 |
| API Specs | ilenia-apis-specs | `/Users/link3rs/Developer/SpecsWorkshop/github.com/link3rs/ilenia-apis-specs` | - |

### 8. Redis (Infraestructura)
**Container**: `ilenia-redis`
**Puerto**: 6379 (interno)
**Función**:
- Cache de sesiones en vivo
- Estado de WebSocket connections
- Subtítulos en tiempo real
- Persistencia AOF

### 9. PostgreSQL (Base de Datos)
**Container**: `ilenia-postgres`
**Puerto**: 5432 (interno)
**Tecnología**: PostgreSQL 16, SQLAlchemy 2.0, Alembic

#### Arquitectura de BD (Microservicios)
**Opción implementada**: 1 clúster PostgreSQL, 2 bases de datos, 2 usuarios

**Estructura**:
- Un único contenedor PostgreSQL (un clúster)
- Dos bases de datos independientes:
  - `ilenia_auth` → Usuarios, roles, permisos
  - `ilenia_events` → Eventos, canales, asignaciones
- Un usuario por servicio con permisos solo sobre su DB:
  - `ilenia_auth_user` → DB `ilenia_auth`
  - `ilenia_events_user` → DB `ilenia_events`

**Ventajas**:
- ✅ Aislamiento real (menos acoplamiento invisible que con schemas)
- ✅ Backups/restore por DB independientes
- ✅ Rotación de credenciales por servicio
- ✅ Permisos más limpios y seguros
- ✅ Cada servicio lleva sus migraciones (Alembic) sin pisarse

#### Stack de Persistencia
**ORM y Migraciones**: SQLAlchemy 2.0 + Alembic
- **ORM**: SQLAlchemy 2.0 (estilo tipado `Mapped[]`, `mapped_column`, `DeclarativeBase`)
- **Driver async**: `asyncpg` + `sqlalchemy[asyncio]`
- **Migraciones**: Alembic (cada servicio con su `alembic.ini` y `versions/`)
- **Schemas**: Pydantic v2 para request/response (separados de modelos ORM)

**Beneficios**:
- Control fino de transacciones, constraints, índices, locks
- Migrations maduras (offline/online)
- Fácil separar por servicio
- Estándar de facto en producción Python

#### Preparación para Managed PostgreSQL (Digital Ocean, AWS RDS, etc.)
**Principios de diseño**:
1. ✅ **No acoplar a Postgres local**: Todo por env vars (`host/port/db/user/pass/sslmode`)
2. ✅ **Alembic como única fuente de verdad** del esquema
3. ✅ **Evitar features que rompen en managed**:
   - Extensiones no estándar
   - Funciones que leen/escriben archivos del SO
   - Jobs que asumen acceso al SO del DB server
4. ✅ **Probar dump/restore temprano** para detectar sorpresas

**Variables de entorno**:
```bash
# Auth Service
DATABASE_URL=postgresql+asyncpg://ilenia_auth_user:password@postgres:5432/ilenia_auth

# Events Service
DATABASE_URL=postgresql+asyncpg://ilenia_events_user:password@postgres:5432/ilenia_events
```

## Flujos del Sistema

### Flujo de Autenticación (Usuarios)

```
1. Usuario → Login (Frontend)
2. Frontend → POST /login (Auth Service)
3. Auth Service → Valida credenciales + genera JWT (RS256)
4. Auth Service → Devuelve access_token + refresh cookie (HttpOnly)
5. Frontend → Guarda access_token en memoria
6. Frontend → Requests a servicios con Authorization: Bearer <token>
7. Servicios → Verifican JWT con clave pública de Auth Service (JWKS)
8. Servicios → Autorizan operación según permisos en token
```

### Flujo de Evento en Vivo - Modo WebSocket (LEGACY)

**Variable**: `VITE_BROADCAST_LIVEKIT=false`

```
1. Manager → Crea evento (Events Service - PostgreSQL)
2. Manager → Navega a /en/manage/{event_id}

3. Speaker → Navega a /en/speak/{event_id}/{channel_id}
4. Frontend → Conecta WebSocket a Live Event Service (:8082)
5. Speaker → Envía audio vía WebSocket
6. Live Event Service → STT (HuggingFace ASR)
7. Live Event Service → MT (HuggingFace Translation)
8. Live Event Service → Distribuye subtítulos vía WebSocket

9. Listener → Navega a /en/listen/{event_id}
10. Frontend → Conecta WebSocket a Live Event Service (:8082)
11. Listener → Recibe subtítulos en tiempo real vía WebSocket

12. Manager → Finaliza sesión
13. Live Event Service → Guarda grabación + metadata
```

### Flujo de Evento en Vivo - Modo LiveKit (NUEVO)

**Variable**: `VITE_BROADCAST_LIVEKIT=true`

#### Fase 1: Preparación del Evento

```
1. Manager → Crea evento (Events Service :8083 - PostgreSQL)
   - Define título, descripción, fechas
   - Configura canales (idioma source/target)
   - Asigna speakers y listeners

2. Events Service → Guarda configuración en PostgreSQL
```

#### Fase 2: Speaker se une al evento

```
3. Speaker → Navega a /en/speak/{event_id}/{channel_id}

4. Frontend → POST /rooms/create-or-join (LiveKit Provider :8086)
   - Body: { event_id, channel_id, role: "speaker" }
   - Headers: Authorization: Bearer <user_jwt>

5. LiveKit Provider:
   a. Verifica JWT del speaker
   b. Comprueba si room existe para este event_id/channel_id
   c. Si NO existe → Crea room en LiveKit Server
   d. Genera token de LiveKit para speaker (con permisos publish)
   e. Devuelve: { room_name, livekit_token, livekit_url }

6. Frontend → Se une a room de LiveKit con token
   - Publica audio del speaker a la room

7. Frontend → POST /sessions/start (Live Service :8092)
   - Body: { event_id, channel_id }
   - Headers: Authorization: Bearer <user_jwt>

8. Live Service:
   a. Genera token S2S (OAuth2) → Auth Service (:8081)
      POST /oauth/token (grant_type=client_credentials)

   b. Con token S2S → GET /events/{event_id} (Events Service :8083)
      Recupera configuración: source_lang, target_lang, speakers, etc.

   c. Para cada agente necesario (ASR, MT):
      → POST /agents/token (LiveKit Provider :8086)
      Headers: Authorization: Bearer <s2s_token>
      Body: { event_id, channel_id, agent_type: "asr"/"mt" }

      LiveKit Provider:
      - Verifica token S2S
      - Genera token de LiveKit para agente
      - Devuelve: { livekit_token, livekit_url }

   d. Inicia agentes LiveKit:
      - Agente ASR: Se une a room, subscribe al speaker, transcribe audio
      - Agente MT: Recibe transcripciones, traduce, publica audio traducido

   e. Devuelve: { session_id, status: "active", agents: [...] }
```

#### Fase 3: Listener se une al evento

```
9. Listener → Navega a /en/listen/{event_id}

10. Frontend → POST /rooms/join (LiveKit Provider :8086)
    - Body: { event_id, role: "listener" }
    - Headers: Authorization: Bearer <user_jwt>

11. LiveKit Provider:
    a. Verifica JWT del listener
    b. Comprueba permisos (listener asignado al evento)
    c. Genera token de LiveKit para listener (solo subscribe)
    d. Devuelve: { room_name, livekit_token, livekit_url }

12. Frontend → Se une a room de LiveKit con token
    - Subscribe a tracks de audio:
      * Audio original del speaker
      * Audio traducido (por cada idioma configurado)
```

#### Fase 4: Finalización

```
13. Manager → Finaliza sesión desde /en/manage/{event_id}

14. Frontend → POST /sessions/stop (Live Service :8092)
    - Body: { event_id, session_id }
    - Headers: Authorization: Bearer <user_jwt>

15. Live Service:
    a. Detiene agentes LiveKit (ASR, MT)
    b. Guarda metadata de sesión en Events Service
    c. Opcionalmente: Solicita grabación a LiveKit

16. LiveKit Provider → Cierra room (opcional)
    - Desconecta speakers, listeners y agentes

17. Events Service → Actualiza estado del evento: "completed"
```

### Comparación de Modos

| Aspecto | Modo WebSocket (Legacy) | Modo LiveKit (Nuevo) |
|---------|-------------------------|----------------------|
| **Difusión** | Subtítulos (texto) | Audio original + traducciones |
| **Protocolo** | WebSocket | WebRTC (LiveKit) |
| **Latencia** | ~2-5 segundos | ~200-500 ms |
| **Calidad** | Texto | Audio alta calidad |
| **Backend** | ilenia-live-event-service | ilenia-live-service |
| **Agentes** | Servidor centralizado | LiveKit distributed agents |
| **Escalabilidad** | Limitada | Alta (SFU) |
| **Variable** | VITE_BROADCAST_LIVEKIT=false | VITE_BROADCAST_LIVEKIT=true |

## Gestión del Workspace

### Archivo Workspace
El workspace está definido en:
```
/Users/link3rs/Developer/NginxWorkshop/github.com/link3rs/ilenia-nginx/ilenia.code-workspace
```

### Memoria de Claude Code
Cada proyecto tiene su propio archivo `CLAUDE.md` con:
- Descripción del proyecto
- Archivos clave
- Comandos comunes
- Integración con otros servicios
- Notas de desarrollo

### Abrir el Workspace
```bash
# Desde la terminal
code /Users/link3rs/Developer/NginxWorkshop/github.com/link3rs/ilenia-nginx/ilenia.code-workspace

# O desde VSCode: File → Open Workspace from File
```

## Variables de Entorno Compartidas

### Frontend React (Modo de Operación)
```bash
# Selección de sistema de difusión
VITE_BROADCAST_LIVEKIT=false   # → WebSocket (ilenia-live-event-service)
VITE_BROADCAST_LIVEKIT=true    # → LiveKit (ilenia-live-service)

# URLs de servicios
VITE_BACKEND_URL=https://ilenia.link3rs.com/api/live
VITE_WS_URL=wss://ilenia.link3rs.com/ws/live
VITE_AUTH_URL=https://ilenia.link3rs.com/api/auth
VITE_EVENTS_URL=https://ilenia.link3rs.com/api/events
VITE_LIVEKIT_PROVIDER_URL=https://ilenia.link3rs.com/api/livekit
VITE_LIVE_SERVICE_URL=https://ilenia.link3rs.com/api/live-service
```

### HuggingFace (STT/MT)
```bash
# Usado por ilenia-live-event-service y agentes de ilenia-live-service
HF_ASR_URL=https://your-asr-endpoint.us-east-1.aws.endpoints.huggingface.cloud
HF_ASR_TOKEN=hf_your_token_here
HF_MT_URL=https://your-mt-endpoint.us-east-1.aws.endpoints.huggingface.cloud/v1
HF_MT_TOKEN=hf_your_token_here
```

### Auth Service
```bash
AUTH_ISSUER=https://ilenia.link3rs.com
AUTH_AUDIENCE=event-service,livekit-service,live-service
ACCESS_TTL_SECONDS=3600
REFRESH_TTL_SECONDS=2592000

# OAuth2 S2S para ilenia-live-service
OAUTH_LIVE_SERVICE_CLIENT_ID=live-service
OAUTH_LIVE_SERVICE_CLIENT_SECRET=generated-secret-here
```

### LiveKit Configuration
```bash
# Usado por ilenia-livekit-provider
LIVEKIT_URL=wss://your-livekit-server.com  # o https://cloud.livekit.io
LIVEKIT_API_KEY=your-livekit-api-key
LIVEKIT_API_SECRET=your-livekit-api-secret

# Usado por ilenia-live-service (para agentes)
LIVEKIT_AGENT_URL=wss://your-livekit-server.com
```

### Base de Datos
```bash
# Auth Service
DATABASE_URL=postgresql://user:pass@localhost:5432/ilenia_auth

# Events Service
DATABASE_URL=postgresql://user:pass@localhost:5432/ilenia_events
```

### Redis
```bash
# Usado por ilenia-live-event-service (WebSocket mode)
REDIS_HOST=localhost
REDIS_PORT=6379
```

### Configuración de Servicios
```bash
# ilenia-live-service
LIVE_SERVICE_PORT=8092
EVENTS_SERVICE_URL=http://localhost:8083
LIVEKIT_PROVIDER_URL=http://localhost:8086
AUTH_SERVICE_URL=http://localhost:8081

# ilenia-livekit-provider
LIVEKIT_PROVIDER_PORT=8086
EVENTS_SERVICE_URL=http://localhost:8083

# ilenia-events-service
EVENTS_SERVICE_PORT=8083
```

## Despliegue

### Desarrollo Local

#### Modo WebSocket (Legacy)
```bash
# Terminal 1: Auth Service
cd ilenia-auth-service
PYTHONPATH=src uvicorn src.main:app --reload --port 8081

# Terminal 2: Events Service
cd ilenia-events-service
PYTHONPATH=src uvicorn src.main:app --reload --port 8083

# Terminal 3: Live Event Service (WebSocket)
cd ilenia-live-event-service
python src/main.py  # puerto 8082

# Terminal 4: Frontend
cd ilenia-react-frontend
export VITE_BROADCAST_LIVEKIT=false
npm run dev  # puerto 5173
```

#### Modo LiveKit (Nuevo)
```bash
# Terminal 1: Auth Service
cd ilenia-auth-service
PYTHONPATH=src uvicorn src.main:app --reload --port 8081

# Terminal 2: Events Service
cd ilenia-events-service
PYTHONPATH=src uvicorn src.main:app --reload --port 8083

# Terminal 3: LiveKit Provider
cd ilenia-livekit-provider
PYTHONPATH=src uvicorn src.main:app --reload --port 8086

# Terminal 4: Live Service (LiveKit/Agents)
cd ilenia-live-service
PYTHONPATH=src uvicorn src.main:app --reload --port 8092

# Terminal 5: Frontend
cd ilenia-react-frontend
export VITE_BROADCAST_LIVEKIT=true
npm run dev  # puerto 5173
```

### Docker Compose

#### docker-compose.websocket.yml (Legacy)
```bash
cd ilenia-nginx
docker-compose -f docker-compose.websocket.yml up -d
```

Servicios incluidos:
- Nginx (80/443)
- React Frontend (VITE_BROADCAST_LIVEKIT=false)
- Live Event Service (:8082)
- Auth Service (:8081)
- Events Service (:8083)
- Redis (:6379)

#### docker-compose.livekit.yml (Nuevo)
```bash
cd ilenia-nginx
docker-compose -f docker-compose.livekit.yml up -d
```

Servicios incluidos:
- Nginx (80/443)
- React Frontend (VITE_BROADCAST_LIVEKIT=true)
- Live Service (:8092)
- LiveKit Provider (:8086)
- Auth Service (:8081)
- Events Service (:8083)
- LiveKit Server (externo o container)

### Producción

Despliegue en DigitalOcean Droplet con:
- SSL/TLS vía Let's Encrypt
- Usuario `ilenia` (non-root)
- Docker Compose para orquestación
- Volúmenes para persistencia
- **LiveKit Cloud** o **LiveKit Server self-hosted**

Ver [ilenia-nginx/README.md](README.md) para guía completa.

## Roadmap

### Fase 1 - Sistema WebSocket (Completado) ✅
- ✅ Live Event Service con STT/MT vía WebSocket
- ✅ Auth Service con JWT RS256
- ✅ Frontend React básico (modo WebSocket)
- ✅ Nginx reverse proxy
- ✅ Redis para cache
- ✅ CRUD temporal de eventos (JSON)
- ✅ Distribución de subtítulos en tiempo real

### Fase 2 - Sistema Dual WebSocket/LiveKit (En progreso) 🚧

#### 2.1 Infraestructura Base
- ✅ Auth Service con OAuth2 S2S
- 🚧 Events Service con PostgreSQL (CRUD persistente)
- 🚧 LiveKit Provider (gestión de rooms y tokens)
- 🚧 Migración de CRUD desde Live Event Service a Events Service

#### 2.2 Sistema LiveKit/WebRTC
- 🚧 **ilenia-live-service** (nuevo microservicio :8085)
  - Orquestación de sesión con LiveKit agents
  - Integración OAuth2 S2S con Auth Service
  - Recuperación de configuración desde Events Service
  - Gestión de tokens para agentes LiveKit
- 🚧 **Frontend React - Modo LiveKit**
  - Variable VITE_BROADCAST_LIVEKIT para seleccionar modo
  - Rutas `/en/speak/{event_id}/{channel_id}` y `/en/listen/{event_id}`
  - Creación automática de LiveKit rooms
  - Cliente LiveKit SDK para audio WebRTC
- 🚧 **LiveKit Agents**
  - Agente ASR (transcripción)
  - Agente MT (traducción)
  - Publicación de audio traducido a room

#### 2.3 Coexistencia de Sistemas
- 🚧 Ambos modos operativos simultáneamente
- 🚧 Selección vía variable de entorno en frontend
- 🚧 Live Event Service (WebSocket) mantiene compatibilidad
- 🚧 OpenAPI/AsyncAPI specs completas

### Fase 3 - Migración Completa a LiveKit (Futuro) 📋
- 📋 Deprecar ilenia-live-event-service (WebSocket)
- 📋 ilenia-live-service como único backend de sesiones
- 📋 Grabación automática de eventos vía LiveKit
- 📋 Métricas y analytics de sesiones
- 📋 Escalado horizontal de agentes

### Fase 4 - Características Avanzadas (Futuro) 📋
- 📋 Analytics Service
- 📋 Notificaciones en tiempo real
- 📋 Multi-tenancy completo
- 📋 Dashboard de administración avanzado
- 📋 Integración con plataformas de streaming (YouTube, Twitch)
- 📋 Soporte para múltiples speakers simultáneos

## Documentación

### Por Proyecto
Cada proyecto tiene su `CLAUDE.md` con documentación específica.

### Global
- Este archivo: Visión del ecosistema
- [ilenia-nginx/README.md](README.md): Guía de despliegue completa
- [ilenia-apis-specs/README.md](../../../SpecsWorkshop/github.com/link3rs/ilenia-apis-specs/README.md): Specs y SDKs

## Contacto

- **Repository**: https://github.com/link3rs/ilenia-*
- **Issues**: Reportar en el repositorio correspondiente

## Sistema Dual de Difusión

### ¿Cuándo usar cada modo?

| Criterio | Modo WebSocket | Modo LiveKit |
|----------|----------------|--------------|
| **Caso de uso** | Subtítulos en pantalla | Audio en tiempo real |
| **Latencia** | Aceptable (2-5s) | Crítica (<500ms) |
| **Dispositivo** | Cualquier navegador | Navegadores modernos |
| **Ancho de banda** | Bajo | Medio-Alto |
| **Calidad** | Texto | Audio alta calidad |
| **Escalabilidad** | Limitada | Alta (SFU) |
| **Estado** | Producción | Beta/Testing |

### Migración Gradual

El sistema dual permite:
1. **Mantener servicio actual** (WebSocket) sin interrupciones
2. **Probar nuevo sistema** (LiveKit) en producción con usuarios piloto
3. **Migración gradual** de usuarios al cambiar variable de entorno
4. **Rollback inmediato** si hay problemas con LiveKit
5. **Deprecar WebSocket** cuando LiveKit sea estable al 100%

---

**Última actualización**: 2026-01-30
**Estado del ecosistema**:
- ✅ Fase 1 (WebSocket) operativa
- 🚧 Fase 2.1 (Infraestructura base) en desarrollo
- 🚧 Fase 2.2 (Sistema LiveKit) en desarrollo
