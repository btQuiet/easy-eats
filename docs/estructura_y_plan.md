# Arquitectura implementada de Easy Eats

Actualizada el 10/10/2026. Reglas en [especificación final](decisiones_antes_del_desarrollo.md), [contrato API](contrato_api.md) y [modelo de datos](modelo_datos.md). Arranque en [README](../README.md), evidencia en [validación](validacion_desarrollo.md).

## Organización

```text
easy-eats/
├── data/                       catálogo SQLite, CSV y constructor reproducible
├── docs/                       diseño, contratos, validación y pruebas externas
├── backend/
│   ├── app/
│   │   ├── main.py             entrada ASGI
│   │   ├── config.py           modo, rutas, CORS y reloj Madrid
│   │   ├── security.py         contraseñas, sesiones y provisión
│   │   ├── admin.py            operario y cuentas históricas ficticias
│   │   ├── api/
│   │   │   ├── schemas.py      entradas estrictas y OpenAPI
│   │   │   └── routes.py       HTTP v1, autenticación, respuestas y composición
│   │   ├── domain/             catálogo, fechas, elegibilidad y variedad
│   │   ├── services/           perfil/plan, menús/revisión y entregas
│   │   ├── integrations/       generación determinista y adaptador Groq
│   │   └── storage/            conexiones, transacciones, migraciones y bloqueo
│   ├── migrations/             SQL numerado
│   ├── tests/                  API, concurrencia, dominio, proveedor y demo
│   └── var/                    bases por modo y backups, fuera de Git
└── easyeats/
    ├── lib/
    │   ├── main.dart           arranque
    │   ├── app/                go_router, shell y theme/app_theme.dart
    │   ├── core/               HTTP, almacenamiento por plataforma, modelos,
    │   │                       repositorio y ChangeNotifier
    │   ├── shared/             layouts, estados, detalle, cambios y opiniones
    │   └── features/
    │       ├── auth/           registro, acceso y servidor LAN
    │       ├── onboarding/     asistente y campos de configuración compartidos
    │       ├── menu/           controlador semanal, renovación y polling
    │       ├── catalog/        búsqueda, filtros, paginación y detalle
    │       ├── feedback/       comidas valorables e historial
    │       ├── profile/        restricciones, gustos, calendario, plan y dirección
    │       ├── delivery/       entregas simuladas Pro
    │       └── operator/       cola, propuesta, correcciones y aprobación
    └── test/                   navegación, accesibilidad y recuperación HTTP
```

Se ha aplicado la separación por responsabilidades prevista. Para esta versión pequeña, Flutter comparte modelos y repositorio en core; cada pantalla posee su controlador de carga, y Semana añade un controlador específico. Los cambios de plan forman parte de Perfil. No se crean carpetas data/presentation ni un módulo plans vacío hasta que haya responsabilidades independientes que separar.

## Dependencias y flujo

Flutter inyecta `http.Client` en ApiClient y AppRepository en pantallas/controladores. Los modelos de receta, asignación y perfil son inmutables. Los formularios guardan su borrador en memoria hasta confirmar; el asistente persiste cada paso. ListenableBuilder muestra carga, éxito, datos conservados y error.

go_router verifica sesión, rol y configuración antes de acceder a una pantalla. La shell usa bottom navigation por debajo de 600 px, rail hasta 1023 px y sidebar de 240 px desde 1024. El operario combina cola de 320 px y propuesta en escritorio; en tamaños menores alterna lista y detalle.

HTTP no conoce SQLite. Las rutas verifican sesión/CSRF/rol y delegan reglas en servicios. El dominio filtra catálogo y valida cobertura/variedad; los adaptadores solo proponen códigos. El worker persistido realiza llamadas fuera de una transacción y comprueba versiones al publicar.

## Datos

Catálogo de lectura: `data/catalog.sqlite`. Estado mutable: `backend/var/app_test.sqlite` o `app_ai.sqlite`. Códigos estables conectan archivos mediante validación de servicio.

SQLite utiliza claves foráneas, WAL y busy_timeout de cinco segundos. El bloqueo del sistema operativo impide dos workers sobre la misma base. Migraciones numeradas con backup previo al actualizar datos existentes.

La primera aprobación, sustituciones, correcciones y cambios de plan quedan auditados. Snapshots conservan la ficha histórica y la dirección preparada. El cliente recibe estados y permisos calculados con el reloj Madrid del servidor.

## Continuidad y recuperación

Ensure conserva un ciclo por usuario/mes y un intento activo por ciclo. La primera propuesta permanece privada al cliente. Tras la primera aprobación, las generaciones válidas posteriores se publican automáticamente.

Las operaciones críticas usan UUID de idempotencia y versiones. Ante una respuesta perdida, Flutter consulta operations y conserva la clave si todavía no consigue resolver el resultado. No programa escrituras offline.

Al reiniciar, queued continúa; running pasa a failed/SERVER_RESTARTED. Una generación fallida conserva la propuesta válida. Cambiar inputs cancela una salida que haya quedado desactualizada.

## Validación y trabajo externo

El recorrido local está implementado y probado en modo test; los artefactos web, Android y Windows se han compilado. El adaptador Groq tiene pruebas simuladas; su prueba mensual real requiere una clave. Las pruebas con dos participantes y la comprobación en un teléfono por LAN siguen pendientes y se registrarán cuando ocurran.

Quedan fuera de esta versión pagos, logística real, push, nutrición y certificación alimentaria.
