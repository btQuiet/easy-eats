# Easy Eats · Flutter

Cliente web, Android y Windows. Arranque y configuración en [README del proyecto](../README.md).

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d web-server --web-port 8080
```

`API_BASE_URL` es la raíz del servidor, sin `/api/v1`. Web usa por defecto el hostname de la página con puerto 8000 y sesión HttpOnly; Android pide dirección LAN si no se ha definido. Nativo guarda el token con flutter_secure_storage.

`lib/app`: tema y rutas por rol. `lib/core`: HTTP inyectable, modelos inmutables, repositorio y controladores. `lib/shared`: estados y detalles. `lib/features`: pantallas de acceso, asistente, semana, catálogo, opiniones, perfil, Pro y operario.

El tema sigue la preferencia del sistema. La aplicación se presenta en es-ES y consulta al servidor para fechas y permisos.
