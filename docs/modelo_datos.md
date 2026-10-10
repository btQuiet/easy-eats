# Modelo de datos de ejecución · Easy Eats v1

Estado: implementado mediante migraciones SQL numeradas en backend/migrations. Reglas en [especificación](decisiones_antes_del_desarrollo.md), campos externos en [contrato API](contrato_api.md), evidencia en [validación](validacion_desarrollo.md).

## Propiedad y almacenamiento

`data/catalog.sqlite` se abre en lectura. `backend/var/app_test.sqlite` y `app_ai.sqlite` almacenan negocios separados; el modo se elige al arrancar. SQLite con claves foráneas habilitadas, WAL y busy_timeout de cinco segundos, por conexión. Una sola instancia de servidor/worker para esta versión LAN.

UUID para entidades de ejecución; códigos estables para referencias al catálogo; timestamps UTC y fechas/meses locales normalizados. Las tablas de revisión, historial y snapshot permiten explicar qué ocurrió sin modificar registros pasados.

## Entidades

| Tabla | Campos principales y restricciones |
| --- | --- |
| users | id, alias_normalized UNIQUE, role CHECK client/operator, password_hash, password_salt, password_parameters, created_at. |
| sessions | id, user_id FK, token_hash UNIQUE, transport, csrf_token nullable, expires_at, revoked_at. CSRF aleatorio ligado a sesión cookie; se conserva entre consultas para permitir varias pestañas. |
| login_attempts | alias_normalized, ip, occurred_at, succeeded; índices para límites por alias/IP. Retención 24 horas. |
| profiles | user_id PK/FK, version, preferences_version, completed, last_completed_step, service_start_date, diet, repetition_tolerance, created_at, updated_at. |
| profile_allergens | user_id FK, allergen_code; PK compuesta. Referencia a catálogo validada en servicio. |
| excluded_ingredients | user_id FK, ingredient_code; PK compuesta. |
| ingredient_preferences | user_id FK, ingredient_code, weight CHECK -1/1; PK compuesta. |
| category_preferences | user_id FK, category; PK compuesta y valor validado en catálogo. |
| weekly_calendars | id, user_id FK, effective_month, revision, created_at; UNIQUE usuario/mes/revisión. Cada edición crea revisión inmutable. |
| weekly_slots | calendar_id FK, weekday CHECK 1-7, meal_slot; PK calendario/día/comida. |
| onboarding_drafts | user_id PK/FK, fields_json, last_completed_step, updated_at; versionado mediante profiles.version. |
| plan_memberships | user_id PK/FK, version, current_plan, pending_plan nullable, effective_date nullable. Pendiente y fecha se rellenan o vacían juntas. |
| plan_events | id, user_id FK, previous_plan, new_plan, effective_date, created_at, event_kind; historial de alta, solicitudes, cambios efectivos y cancelaciones. Las entregas usan eventos initial/effective, conservando aparte scheduled/cancelled. |
| delivery_addresses | user_id PK/FK, version, line1, city, postal_code, notes, updated_at. |
| menu_cycles | id, user_id FK, month, status, version, service_start_date, proposal_generation_id nullable, latest_attempt_id nullable, published_at nullable; UNIQUE usuario/mes. |
| generation_attempts | id, cycle_id FK, actor_id FK, state, origin, provider/model nullable, input_snapshot_json, input_hash, catalog_hash, proposed_items_json nullable, warning_json, error_json nullable, created_at, started_at, finished_at. |
| menu_items | id, cycle_id FK, date, meal_slot, recipe_code, recipe_snapshot_json, version, compatibility, incompatibility_reasons_json, cancelled, cancellation_reason nullable; UNIQUE ciclo/fecha/comida. |
| initial_reviews | id, user_id FK UNIQUE, cycle_id FK UNIQUE, operator_id FK, approved_cycle_version, approved_at. Solo una por usuario en esa base. |
| swaps | id, item_id FK, actor_id FK, old_recipe_code, new_recipe_code, previous_version, resulting_version, created_at. Historial inmutable. |
| operator_corrections | id, cycle_id FK, item_id FK, operator_id FK, previous_code, new_code, created_at, proposal_version. |
| feedback | id, user_id FK, item_id FK UNIQUE, recipe_code, rating CHECK -1/1, comment, version, created_at, updated_at. |
| deliveries | id, user_id FK, week_start, scheduled_date, address_snapshot_json nullable, items_snapshot_json nullable, snapshot_taken_at nullable, cancelled_reason nullable; UNIQUE usuario/semana. Estado calculado por fechas y cancelación. |
| idempotency_operations | user_id FK, operation_name, key, request_hash, state, result_json nullable, expires_at; UNIQUE usuario/clave. Sin secretos de sesión en result_json. |
| schema_migrations | version PK, applied_at. |

Las listas de códigos se normalizan en tablas; JSON se reserva para borradores, snapshots, errores y resultado inmutable de intentos. Se valida su esquema al escribir. Los CHECK de dieta, planes, estados y comidas reflejan los enums del contrato.

El snapshot del plato contiene nombre, ingredientes, alérgenos modelados y etiquetas de dieta. Mantiene legible el histórico si una reconstrucción cambia el catálogo; no convierte sus datos en verificados.

## Selección de versiones e invariantes

- Calendario aplicable: mayor effective_month no posterior al mes del ciclo; dentro de ese mes efectivo, mayor revision.
- profiles.version aumenta con cambios explícitos de perfil, calendario o asistente. preferences_version aumenta con gustos, tolerancia u opiniones.
- Un intento captura ambos contadores, calendar_id, catálogo y cycle.version. Se comparan al publicar. Feedback recibido durante generación puede invalidar esa salida.
- La cycle.version capturada es una guardia previa a publicar, no un input alimentario. Publicar incrementa esa versión; al aprobar se compara la versión actual recibida por el operario y los inputs de perfil/calendario/preferencias/catálogo de la propuesta. No se exige que la versión previa a generación coincida con la versión posterior a publicación.
- proposal_generation_id apunta a la última propuesta validada y define su origen e inputs; latest_attempt_id puede apuntar a un intento fallido. Un error no mueve la referencia de propuesta.
- Editar item incrementa item.version y cycle.version. Recalcular compatibilidad incrementa ambas solo si cambia el resultado. Publicar nueva propuesta incrementa cycle.version y deja auditada la anterior en generation_attempts.
- Cada fecha/comida tiene una asignación por ciclo. Los códigos existen y están activos al asignarse; entre archivos SQLite esta condición la asegura el servicio.
- Una asignación aprobada de fecha pasada o actual no se sustituye. Las opiniones no cambian recipe_code.
- Una primera aprobación necesita al menos un hueco futuro válido y crea initial_reviews en la misma transacción que publica el ciclo.
- Índice UNIQUE parcial de generation_attempts por cycle_id mientras state sea queued/running. Un intento activo máximo por ciclo.
- Solo una primera propuesta vigente por usuario sin initial_reviews; se controla en transacción al crear ciclo o expirar el anterior.
- Direcciones, borradores y menús nunca se escriben en el catálogo.

## Transacciones y worker

Sustitución: comprobar propietario, estado, fecha, versión y candidato → actualizar item con condición de versión → incrementar ciclo → insertar swap → completar operación idempotente → commit. Si falla cualquier paso, rollback.

Aprobación: comprobar rol, versión, ausencia de intento activo e inputs vigentes → cancelar huecos vencidos → validar futuros → insertar initial_reviews → publicar ciclo → preparar entregas aplicables → completar idempotencia → commit.

Generación: guardar solicitud y operación idempotente en transacción corta → devolver 202 → worker captura el intento con actualización condicionada de state → llamada fuera de la transacción → validar → publicar o registrar error en nueva transacción. No mantener SQLite bloqueado durante una llamada IA.

Si el proceso cae después de marcar running, al arrancar se marca failed/SERVER_RESTARTED y se completa la operación con ese resultado. Los queued continúan. Si la publicación llegó a commit, un reintento idempotente devuelve éxito previo.

Para evitar leer dos versiones del catálogo, su reconstrucción se hace con el servidor detenido. Al arrancar se calcula SHA-256 del archivo, se verifica integridad y se recalcula compatibilidad de asignaciones actuales/futuras si cambió. Códigos de perfil ausentes se notifican para revisión; no se eliminan restricciones silenciosamente.

La revisión de compatibilidad de una propuesta pendiente se calcula sin alterar el snapshot de inputs. Toda propuesta cuyos inputs hayan cambiado exige regeneración antes de aprobar; corregir un item por sí solo no actualiza esos inputs.

## Preparación de demo y migraciones

Migraciones numeradas y aplicadas al iniciar, con backup previo si hay datos que conservar. La primera crea este esquema; una base nueva no hereda perfiles ni revisiones del otro modo.

Preparación explícita de cuentas ficticias: cliente Free, cliente Pro y operario, sin contraseñas publicadas ni secretos en Git. Reinicio de demo mediante comando local del servidor, identificado por modo y con destino de base verificado; sin endpoint de borrado público.

Registro crea perfil y membership versión 1, incompletos, dieta omnivore y tolerancia normal. Inicio es nullable hasta completar; completar exige fecha y calendario válidos. El asistente fija perfil, primera revisión de calendario, plan inicial y dirección Pro en una única transacción.

Sesiones expiradas y operaciones idempotentes vencidas se limpian al iniciar y periódicamente al acceder, sin eliminar ciclos, revisiones ni opiniones de la demo.
