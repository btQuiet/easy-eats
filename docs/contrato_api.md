# Contrato API de Easy Eats · v1

Estado: contrato implementado, 10/10/2026. Reglas en [especificación final](decisiones_antes_del_desarrollo.md), evidencia en [validación](validacion_desarrollo.md). OpenAPI disponible en /docs al arrancar el servidor.

## Convenciones

Prefijo `/api/v1`, JSON UTF-8, nombres de campos en inglés. IDs UUID salvo códigos del catálogo. Fecha `YYYY-MM-DD`, mes `YYYY-MM` y timestamp UTC RFC 3339. Valores monetarios no forman parte del contrato.

Éxito: `{"data": objeto_o_lista, "meta": {"request_id": "...", "server_today": "2026-10-10", "generation_mode": "test"}}`. Listas añaden `total`, `limit` y `offset` a meta; límite por defecto 25, máximo 100.

Error: `{"error": {"code": "...", "message": "...", "details": {}}, "meta": {"request_id": "...", "server_today": "...", "generation_mode": "test"}}`. No devolver claves, stack traces ni respuesta bruta del proveedor.

Lecturas `200`; creación `201`; trabajo en cola `202`; logout `204`. `401` sesión inválida, `403` rol/capacidad/CSRF, `404` recurso inexistente o de otro cliente, `409` versión/estado/conflicto, `422` entrada o restricciones imposibles, `429` límite temporal y `503` generación no disponible.

Toda modificación de un recurso con versión lleva `expected_version` en cuerpo. Versión 0 solo para recursos todavía inexistentes: opinión y dirección. La respuesta devuelve nueva versión. Los conflictos incluyen `current_version`.

`Idempotency-Key` es obligatorio en ensure, sustitución, regeneración y aprobación; UUID creado por cliente y conservado hasta resolver la respuesta. Recuperación con `GET /operations/{key}`: operación de ese usuario, `pending|completed` y resultado almacenado; `404` si no existe. La clave es única por usuario; reutilizarla para otra operación devuelve IDEMPOTENCY_CONFLICT. Se aplica la política de 24 horas de la especificación. No reintentar una escritura incierta con una clave nueva.

Autenticación por cookie web o `Authorization: Bearer ...` nativo. Escrituras con cookie requieren `X-CSRF-Token` y origen permitido. No pasar credenciales ni tokens en URLs. CORS admite credenciales y esos dos headers solo para orígenes configurados.

## Sesión y sistema

| Método y ruta | Entrada | Resultado / permiso |
| --- | --- | --- |
| GET /system/capabilities | Sin cuerpo | Público: modo, disponibilidad, zona, fecha, versión de API y advertencia de catálogo. |
| POST /auth/register | alias, password, transport=cookie o bearer | Cliente creado y Session; 201. Alias ocupado: ALIAS_TAKEN. |
| POST /auth/login | alias, password, transport | Session; 200. Fallo genérico INVALID_CREDENTIALS. |
| GET /auth/session | Sesión | Session sin reenviar bearer; incluye CSRF en transporte cookie. |
| POST /auth/logout | Sesión; CSRF en web | Revoca sesión y elimina cookie; 204. |
| GET /operations/{key} | Sesión | Solo operaciones del usuario autenticado. |

`Session`: `user{id,alias,role}, expires_at, onboarding_completed, csrf_token` para cookie; `access_token` solo al crear sesión bearer. Nunca retornar hash/sal. Cookie nombrada `easy_eats_session`.

`Capabilities`: `api_version="1", generation_mode, can_generate, generation_unavailable_reason, timezone="Europe/Madrid", server_today, catalog_hash, catalog_validation_status="demo_unverified"`. No consulta externa automática al abrir la app; disponibilidad de clave/configuración y último estado conocido.

## Perfil, borrador y plan

| Método y ruta | Entrada | Resultado / permiso |
| --- | --- | --- |
| GET /profile | Cliente | Profile completo o borrador. |
| PUT /onboarding/draft | expected_version, step, fields | Guarda paso; devuelve borrador y versión. Solo perfil no completado. |
| POST /onboarding/complete | expected_version | Valida todos los campos y fija inicio/plan; devuelve Profile. No genera menú. |
| PATCH /profile | expected_version y restricciones/gustos modificados | Profile y affected_items de hoy/futuro; solo cliente completado. |
| PUT /profile/calendar | expected_version, weekly_slots | Profile con calendar_effective_month calculado. |
| GET /plan | Cliente | Plan vigente, versión y cambio pendiente. |
| PUT /plan | expected_version, plan=free o pro, address opcional y expected_address_version si se envía | Plan y fecha efectiva; elegir vigente cancela pendiente. |
| GET /delivery/address | Cliente completado | Dirección propia o null; también disponible al preparar la subida a Pro. |
| PUT /delivery/address | expected_version, line1, city, postal_code, notes | Dirección versionada; cliente completado con Pro vigente o pendiente. |

`Profile`: `version, preferences_version, completed, last_completed_step, service_start_date, diet, allergen_codes[], excluded_ingredient_codes[], liked_ingredient_codes[], disliked_ingredient_codes[], preferred_categories[], repetition_tolerance, weekly_slots[], calendar_revision, calendar_effective_month, next_calendar_effective_month, initial_review_completed`. El mes de la próxima edición permite mostrar su vigencia antes de guardar.

Cada `weekly_slot` contiene `weekday` ISO 1-7 y `meal_slots[]` de los cuatro códigos. Se envían los siete días, pudiendo dejar arrays vacíos. Se rechazan códigos desconocidos, duplicados, solapamiento de gustos y calendario sin comidas. `step`: `plan|calendar|restrictions|preferences|summary`. `fields` solo admite campos del paso; el resumen incluye dirección Pro y fecha inicial. El borrador se valida por paso y complete valida todo.

PATCH no permite editar rol, revisión inicial, fecha de inicio fijada al completar el asistente ni cambiar plan/calendario por vías indirectas. Preferencias alimentarias son las listas de gustos/categorías y tolerancia; restricciones son dieta, alérgenos y exclusiones. Cambiar opiniones incrementa preferences_version aunque no cambie version. La dirección del asistente se guarda en el borrador y se publica junto con el perfil al completar.

Para pasar de Free a Pro sin dirección, PUT /plan acepta address con los campos de dirección y expected_address_version=0. Si se modifica una existente, exige su versión vigente. Dirección y cambio de plan se guardan en una sola transacción. Así no se exige ser Pro antes de poder preparar su dirección. Si ya hay dirección válida puede omitirse; al elegir Free no se acepta address.

`Plan`: `version, current_plan, pending_plan|null, effective_date|null, can_view_delivery, address_required`. GET aplica transiciones vencidas antes de responder.

## Catálogo

| Método y ruta | Entrada | Resultado |
| --- | --- | --- |
| GET /catalog/recipes | q, meal_slot, diet, compatible_only=false, limit, offset | Recipes; cliente u operario autenticados. |
| GET /catalog/recipes/{code} | Código | Recipe completo. |
| GET /catalog/options | Sin cuerpo | Ingredientes, alérgenos, categorías y momentos disponibles. |

`Recipe`: `code, name, category, cuisine, meal_slots[], ingredients[{code,name}], allergens[{code,name}], is_vegan, is_vegetarian, is_active, validation_status, compatible|null, incompatibility_reasons[]`. La compatibilidad es con el perfil del cliente autenticado; operario usa candidatos de una propuesta concreta para valorar otro usuario. Búsqueda por nombre/ingrediente, sin distinguir mayúsculas ni acentos, orden por nombre y código. Campos de ingredientes/alérgenos completos en detalle; lista puede devolver resumen.

## Menús, sustituciones y opiniones

| Método y ruta | Entrada | Resultado / regla |
| --- | --- | --- |
| POST /menus/ensure | month; Idempotency-Key | Cycle existente 200 o GenerationAttempt nuevo/activo 202. |
| GET /menus/cycles/{id} | Cliente propietario | Cycle con estado/resumen, sin items mientras pendiente. |
| GET /menus/generations/{id} | Cliente propietario | GenerationAttempt, incluidos fallo y resultado. |
| GET /menus/week | start, lunes YYYY-MM-DD | Week con siete días y tramos de ciclo. |
| GET /menus/items/{id} | Cliente propietario | MenuItem con ficha del plato y permisos. |
| GET /menus/items/{id}/candidates | q, limit, offset | Solo compatibles para ese hueco editable. |
| PUT /menus/items/{id}/substitution | expected_version, recipe_code; Idempotency-Key | MenuItem y swap_id; transacción única. |
| PUT /menus/items/{id}/feedback | expected_version de Feedback, rating, comment | Feedback nuevo o editado; 200. |
| GET /feedback | limit, offset | Opiniones propias, orden por actualización descendente. |

Ensure admite el mes actual o siguiente, respetando inicio y primera revisión. Un mes anterior al inicio devuelve INVALID_INPUT con suggested_month. Si el mes no tiene huecos futuros y todavía no existe primera aprobación, devuelve `CYCLE_EXPIRED` y `suggested_month`. Nunca genera huecos anteriores al inicio. Una primera propuesta vigente en otro mes devuelve `INITIAL_REVIEW_PENDING`. Un ciclo aprobado existente se devuelve sin regenerar, incluso si la IA no está configurada.

`Cycle`: `id, month, status, version, service_start_date, requires_initial_review, published_at|null, generation_origin, latest_generation_id, input_versions, warnings[], item_count, cancelled_count`.

`GenerationAttempt`: `id, cycle_id, state, origin, provider|null, model|null, created_at, started_at|null, finished_at|null, error|null, retry_after|null`. Sin porcentaje estimado. Una modificación de inputs mientras se genera termina en cancelled/INPUT_CHANGED.

`MenuItem`: `id, cycle_id, date, meal_slot, recipe_code, recipe_snapshot, version, compatibility, incompatibility_reasons[], cancelled, can_swap, can_feedback`. Fecha actual o pasada no admite swap. Pendiente de revisión no devuelve items al cliente. Cancelados no se muestran como comidas recibidas ni admiten opinión.

`Week`: `start, end, days[{date,scheduled_slots[],items[]}], cycle_segments[{month,status,cycle_id|null}], pending_generation_ids[], pending_initial_review, can_view_delivery, summary`. Diferenciar día sin comidas, tramo sin ciclo y tramo pendiente. Todos los permisos usan fecha del servidor.

`Week.summary`: `published_item_count, today_item_count, future_item_count, attention_item_count, next_item_id|null`. Se calcula exclusivamente sobre asignaciones publicadas y visibles en esa semana. Atención cuenta incompatibilidades de hoy y futuras; next_item_id identifica la primera comida de hoy o posterior por fecha/momento, sin inferir una hora de consumo. Una propuesta privada no aporta platos ni identificadores a este resumen.

`Feedback`: `id, item_id, recipe_code, rating, comment, version, created_at, updated_at`. rating solo -1 o 1; comentario hasta 500 caracteres. Una opinión no añade restricciones.

La lista añade recipe_name desde el snapshot histórico. El detalle del operario añade latest_generation, input_snapshot, requires_refresh, profile, user, items, review_summary y profile_labels; el intento permite consultar fallos de regeneración sin perder la propuesta anterior.

`review_summary`: `future_item_count, elapsed_item_count, first_future_date|null, can_approve, blocking_reasons[]`. Usa la misma comprobación de negocio que la transacción de aprobación, que vuelve a ejecutarla antes de publicar. Cada bloqueo lleva code, message y details. No sustituye expected_version ni concede un permiso permanente; el estado puede cambiar después de consultar.

`profile_labels`: listas `allergens, excluded_ingredients, liked_ingredients, disliked_ingredients` con `code, name, known`. Los códigos retirados se conservan con known=false. No se incluye dirección en este resumen de etiquetas.

## Operario y entregas

| Método y ruta | Entrada | Resultado / regla |
| --- | --- | --- |
| GET /operator/reviews | q opcional (hasta 80 caracteres), limit, offset | Primeras propuestas pendientes; sin ciclos expirados o ya aprobados. q busca una subcadena literal del alias, normalizada sin distinguir mayúsculas/tildes; meta.total corresponde al filtro. |
| GET /operator/cycles/{id} | Ciclo de revisión | Mes completo, perfil actual y snapshot, versiones, avisos y requires_refresh. |
| GET /operator/items/{id}/candidates | q, limit, offset | Candidatos compatibles con perfil actual y comida. |
| PUT /operator/items/{id} | expected_version, recipe_code | Item actualizado y nueva cycle_version. |
| POST /operator/cycles/{id}/regenerate | expected_version; Idempotency-Key | Intento 202; conserva propuesta anterior hasta validar nueva. |
| POST /operator/cycles/{id}/approve | expected_version; Idempotency-Key | Cycle aprobado; registra primera revisión. |
| GET /deliveries | start opcional, limit, offset | Solo cliente Pro vigente; entregas propias simuladas. |

Operario no puede editar un ciclo aprobado. Con generación activa, approve devuelve `GENERATION_IN_PROGRESS`. Con inputs antiguos, `INPUT_CHANGED`. Si el mes inicial venció, regenerate devuelve `CYCLE_EXPIRED`; cliente/operario puede solicitar el siguiente primer ciclo mediante la misma operación de ensure autorizada para ese usuario: `POST /operator/users/{user_id}/menus/ensure` con month e Idempotency-Key. Solo si no existe primera aprobación.

`Delivery`: `id, week_start, scheduled_date, status, simulated=true, address_snapshot|null, meal_count, cancelled_reason|null`. Estados y captura según especificación. No endpoints de pago, ubicación de repartidor o simulación manual.

## Errores de negocio estables

`INVALID_INPUT, ALIAS_TAKEN, INVALID_CREDENTIALS, AUTH_REQUIRED, FORBIDDEN, NOT_FOUND, PROFILE_INCOMPLETE, PROFILE_ALREADY_COMPLETED, NO_CANDIDATES, RECIPE_INCOMPATIBLE, ITEM_NOT_EDITABLE, VERSION_CONFLICT, IDEMPOTENCY_CONFLICT, GENERATION_IN_PROGRESS, INITIAL_REVIEW_PENDING, CYCLE_EXPIRED, INPUT_CHANGED, AI_NOT_CONFIGURED, AI_RATE_LIMITED, AI_UNAVAILABLE, AI_INVALID_OUTPUT, SERVER_RESTARTED, INTERNAL_ERROR`.

INTERNAL_ERROR usa HTTP 500, mensaje genérico e identificador de petición para diagnóstico local. No envía detalles internos. La comprobación de permisos siempre resuelve primero las transiciones de plan que ya sean efectivas.

NO_CANDIDATES incluye comidas afectadas y causas detectables; no afirma una causa única si varios filtros eliminan opciones. Errores de IA durante un trabajo se guardan en GenerationAttempt y no convierten su consulta GET en una respuesta HTTP fallida.

## Ejemplos de payload

```json
{
  "month": "2026-10"
}
```

```json
{
  "expected_version": 3,
  "recipe_code": "des001"
}
```

```json
{
  "expected_version": 0,
  "rating": -1,
  "comment": "Prefiero menos repeticiones."
}
```

Las asignaciones de ejemplo no garantizan compatibilidad con un perfil; el servidor decide candidatos y permisos. OpenAPI se publicará desde los modelos de FastAPI al implementarlos, manteniendo este contrato.
