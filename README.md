# Easy Eats

App de menús personales en Flutter, con API FastAPI y SQLite. Primera versión funcional de demostración; se ha construido desde los archivos presentes, sin recuperar código descartado en Git.

## Qué funciona

Registro y sesión de cliente/operario; configuración en cinco pasos con borrador recuperable; catálogo de 125 platos; generación mensual; primera revisión; semana actual y siguientes; sustituciones compatibles; opiniones editables; calendario y preferencias; cambios Free/Pro; dirección ficticia y entregas simuladas.

Tema Material 3 claro/oscuro y navegación adaptable: móvil, rail y sidebar. El modo `test` funciona sin red externa. El adaptador Groq del modo `ai` está implementado y probado con respuestas simuladas; falta ejecutar una generación real con clave.

Ver [mejoras implementadas](docs/mejoras_20261010.md), [validación de desarrollo](docs/validacion_desarrollo.md) y [auditoría de código, funcionamiento y aspecto visual](docs/auditoria_20261010.md). Las pruebas con personas del [protocolo](docs/protocolo_pruebas.md) siguen pendientes. El catálogo no está verificado para uso alimentario real.

## Arrancar backend

Comandos PowerShell desde la raíz. Entorno verificado: Python 3.14.7, Flutter 3.44.9 / Dart 3.12.2.

```powershell
python -m venv backend/.venv
& backend/.venv/Scripts/python.exe -m pip install -r backend/requirements-lock.txt
$env:GENERATION_MODE = 'test'
Set-Location backend
& .venv/Scripts/python.exe -m app.admin create-operator
& .venv/Scripts/python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

El comando de operario pide alias y contraseña sin mostrarla ni guardarla en un archivo. No existe una contraseña pública por defecto. Usar **un solo proceso**, sin `--workers`; el servidor bloquea una segunda instancia sobre la misma base.

API y OpenAPI: `http://localhost:8000/docs`. Variables en [backend/.env.example](backend/.env.example): se establecen en el entorno; el servidor no carga automáticamente un archivo .env.

## Arrancar frontend

En otra terminal, desde la raíz:

```powershell
Set-Location easyeats
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Abrir `http://localhost:8080`. Crear una cuenta, completar configuración y solicitar el menú. Acceder con el operario para aprobarlo, y volver al cliente.

Para una web compilada, desde la raíz:

```powershell
Set-Location easyeats
flutter build web --no-web-resources-cdn
Set-Location ..
python -m http.server 8080 --directory easyeats/build/web
```

Web y API deben usar **el mismo hostname**. En LAN, antes de arrancar backend, configurar `$env:CORS_ORIGINS = 'http://IP_DEL_EQUIPO:8080'` y abrir la web con esa IP. Se admiten únicamente los orígenes exactos configurados.

Android: compilar `flutter build apk --debug` o usar `flutter run`. En acceso, **Servidor LAN** permite guardar `http://IP_DEL_EQUIPO:8000`; `localhost` en el teléfono apunta al teléfono. También se admite `--dart-define=API_BASE_URL=http://IP_DEL_EQUIPO:8000`. La APK usa HTTP de LAN en esta demo. Windows arranca con `http://localhost:8000` y permite cambiarlo.

Artefactos generados:

- Android: `easyeats/build/app/outputs/flutter-apk/app-debug.apk`.
- Web: `easyeats/build/web/`.
- Windows: `easyeats/build/windows/x64/runner/Debug/`; conservar toda la carpeta junto al ejecutable.

## Preparar historial ficticio

Con el backend detenido y `GENERATION_MODE=test`, desde `backend/`:

```powershell
& .venv/Scripts/python.exe -m app.admin seed-demo --alias demo
```

Pide una contraseña elegida localmente y crea `demo_free`, `demo_pro` y `demo_operator`, con menús históricos ficticios y opiniones. No borra ni reemplaza cuentas existentes. Se usa para probar opiniones sin esperar a que llegue una comida futura. Solo prepara datos: el reloj del servidor LAN sigue siendo real. No está permitido en modo IA.

## Activar IA

Detener el servidor. En su terminal, establecer `GENERATION_MODE=ai`, `GROQ_API_KEY` y, opcionalmente, `GROQ_MODEL`; crear el operario de esa base y arrancar otra vez. La clave nunca se introduce en Flutter.

Los modos utilizan `backend/var/app_test.sqlite` y `app_ai.sqlite` separados. Sin clave, IA permite consultas pero rechaza nueva generación; nunca cambia a test. Detalles en [generadores](docs/modos_generacion.md).

## Comprobaciones

Desde `backend/`: `.venv/Scripts/python.exe -m pytest -q`. Desde `easyeats/`: `flutter analyze` y `flutter test`.

45 pruebas de backend y 29 de Flutter pasan. El análisis de Flutter no muestra incidencias. Se han compilado web, APK Android y Windows. La compilación Android no sustituye una prueba en un teléfono por LAN.

Las migraciones numeradas se aplican al iniciar, con copia SQLite previa para actualizar una base existente. Sesiones, bases y copias locales están excluidas de Git. Detener el servidor antes de reconstruir el catálogo.

## Documentación

[Reglas](docs/decisiones_antes_del_desarrollo.md) · [API](docs/contrato_api.md) · [Datos](docs/modelo_datos.md) · [Arquitectura](docs/estructura_y_plan.md) · [Diseño](docs/diseno_producto.md) · [Frontend](docs/propuesta_frontend.md) · [Catálogo](data/README.md).

`flujo_aplicacion_menus.md` y `docs/repaso_final.md` se mantienen como históricos.
