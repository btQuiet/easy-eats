# Generación mensual: modo de pruebas y modo IA

Implementación disponible, 10/10/2026: generador determinista, adaptador Groq y validador común. Prueba local y transporte simulado comprobados; todavía no se ha generado un mes con una clave real. Reglas en [especificación final](decisiones_antes_del_desarrollo.md), operaciones en [API](contrato_api.md), evidencia en [validación](validacion_desarrollo.md).

## Contrato compartido

Entrada normalizada: huecos exactos con fecha/comida, candidatos filtrados por restricciones para cada momento, puntuaciones de gustos/opiniones, apariciones previas, tolerancia de repetición y versiones de perfil/calendario/catálogo/ciclo.

Salida: `{"items":[{"date":"YYYY-MM-DD","meal_slot":"comida","recipe_code":"..."}]}`. Una asignación por hueco, sin duplicados ni recetas inventadas.

Validador único: cobertura exacta, fecha/comida, código activo y candidato permitido, política secuencial de variedad y versiones vigentes. Cero candidatos se detecta antes de encolar; nunca se retira una restricción.

La generación crea un intento persistido y devuelve 202. Worker y recuperación de reinicio según [modelo de datos](modelo_datos.md). Cerrar Flutter no cancela el trabajo.

## Modo test

Configuración inicial `GENERATION_MODE=test`. Sin red ni clave. Selección determinista por puntuación y código, aplicando los niveles de variedad definidos en la especificación.

Misma entrada normalizada produce la misma salida. Se muestra «Menú de prueba, generado sin IA». Base mutable `backend/var/app_test.sqlite`.

La ruta completa se implementa primero con este modo; no demuestra integración de IA.

## Modo ai

Proveedor seleccionado `groq`, modelo inicial `openai/gpt-oss-120b`, endpoint `https://api.groq.com/openai/v1/chat/completions`. Modelo configurable. Usar `response_format=json_schema` con `strict=true`, sin streaming ni herramientas. [Modelo documentado](https://console.groq.com/docs/models), [soporte de salida estructurada](https://console.groq.com/docs/structured-outputs).

Solo enviar datos alimentarios normalizados y códigos; no enviar alias, dirección, credenciales ni comentarios libres. Los pesos de opiniones se calculan en backend.

Máximo dos llamadas por intento, 45 segundos por llamada, plazo total 120 segundos, máximo 8192 tokens de salida y reasoning_effort low. Una llamada inicial y como máximo una recuperación: corrección de salida inválida o reintento por fallo transitorio. No son dos reintentos adicionales.

Para 429 respetar Retry-After si cabe en el plazo; si no, registrar AI_RATE_LIMITED y retry_after. No fijar una cuota de cuenta como garantizada. [Comportamiento de límites](https://console.groq.com/docs/rate-limits).

Clave ausente: API disponible para consultar, can_generate=false y nueva generación rechazada con AI_NOT_CONFIGURED. Error de credenciales/modelo: sin reintento automático. Fallo de proveedor, salida inválida o inputs modificados: no publicar; preservar última propuesta/menú válido.

El validador de negocio sigue siendo obligatorio aunque el proveedor ajuste la salida al esquema. El modo ai nunca se convierte silenciosamente en test.

## Configuración del servidor

| Variable | Valor y función |
| --- | --- |
| GENERATION_MODE | test por defecto; ai mediante configuración explícita. |
| GROQ_MODEL | openai/gpt-oss-120b por defecto. |
| GROQ_API_KEY | Clave local, solo backend. |
| CORS_ORIGINS | Orígenes exactos de la web LAN, separados por coma. |
| COOKIE_SECURE | false en HTTP de LAN; true en HTTPS. |

Proveedor Groq fijo en esta versión. Provisión de operario mediante `python -m app.admin create-operator`, con contraseña elegida localmente y sin valor público por defecto. Las variables se establecen en el entorno; .env.example es una guía y no se carga automáticamente.

Base IA `backend/var/app_ai.sqlite`. No migrar automáticamente usuarios, perfiles o revisiones entre modos. Cambiar modo exige reinicio; Flutter consulta capabilities.

Se registra origen, proveedor/modelo, hashes de input/catálogo, tiempos, validación y errores sanitizados. No guardar la clave ni payloads con información personal en logs.

## Verificación necesaria

Antes de afirmar integración real: clave configurada localmente, una generación mensual completa válida, restricciones que reduzcan candidatos, rechazo de salida inválida, caso de error y consulta en la app de su origen ai. La selección del proveedor está cerrada; la ejecución y prueba real siguen por hacer.
