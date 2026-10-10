# Validación de desarrollo · 10/10/2026

Resultados ejecutados sobre la implementación actual. No representan pruebas con participantes externos ni una generación real de IA.

## Automática

| Comprobación | Resultado |
| --- | --- |
| Backend, pytest | 45 pruebas pasan. |
| Flutter, analyze | Sin incidencias. |
| Flutter, test | 29 pruebas pasan. |
| Web release | Compilación correcta, recursos web locales. |
| Android debug APK | Compilación correcta. |
| Windows debug | Compilación correcta. |

Backend: registro/sesión/cookie/CSRF, roles, límite de acceso, asistente, revisión privada, aprobación y fechas vencidas, renovación entre meses, sustitución auditada/idempotente, dos sustituciones concurrentes, propiedad, restricciones, opinión editable, calendario diferido, generación invalidada por cambio de inputs, recuperación de reinicio, fallo que conserva propuesta, Free/Pro, dirección atómica, captura de entrega y cancelación de cambio pendiente. Las restricciones retiradas del catálogo se conservan hasta una corrección explícita y bloquean las comidas mientras requieren atención.

Generación: determinismo, cobertura, dieta, variedad y relajación, puntuación, rechazo de códigos/cobertura/tipos incorrectos. Groq con transporte simulado: esquema estricto, reparación limitada a dos llamadas, exclusión de alias/dirección y 429 sin fallback.

Flutter: acceso y errores de validación a 320 px; navegación Semana/Catálogo/Perfil y detalle; sidebar y tema oscuro; 320 px con texto al 200%; recuperación de respuesta perdida con la misma clave; conflicto de versión y validación de URL. Semana y Operario suspenden las consultas periódicas en segundo plano y refrescan al volver.

Preparación local de demo: crea Free/Pro/operario con historial y opinión ficticios; prueba con base temporal. No modifica el reloj del servidor LAN.

La auditoría amplió la cobertura con regresiones de entregas pendientes Pro y recuperación de entregas futuras; fechas límite; respuestas Groq malformadas y fallos transitorios; timeout HTTP desde el envío; envelopes inválidos y recuperación idempotente; cierre de sesión sin conexión; respuestas después de destruir controladores; formularios móviles protegidos; recuperación de conflictos de sustitución/opinión; búsqueda sin tildes; semántica de etiquetas; y errores de red en vistas bajas con texto al 200%. Los fallos reproducidos y las correcciones se detallan en [auditoría](auditoria_20261010.md).

El entorno Python emite un aviso de deprecación de Starlette sobre su transporte httpx de pruebas. No hay fallos de ejecución; la integración real de Groq usa httpx directamente.

La fase de [mejoras de producto](mejoras_20261010.md) añade siete casos de backend y tres de widgets: resumen de revisión coherente con la publicación, rechazo por perfil/plato/generación, retirada de propuestas vencidas, búsqueda literal por alias con paginación y control de rol, resumen semanal sin filtración de propuesta privada, perfil adaptable con favoritos reales, comida destacada incompatible y botón de aprobación bloqueado por el servidor. El test de ciclo de vida usa las transiciones reales inactive → hidden → paused y hidden → inactive → resumed, incluyendo ahora el buscador del operario.

## Recorrido real en navegador

En localhost se realizó registro con cuenta ficticia, cinco pasos de configuración, dieta vegana e ingrediente favorito; generación en el worker real de modo test; entrada de operario, revisión y aprobación; acceso de cliente, semana completa y sustitución confirmada entre candidatos compatibles. La asignación modificada quedó visible después de guardar.

Las sesiones web funcionaron con cookie HttpOnly y CSRF. Se revisaron visualmente tema oscuro y disposición de escritorio. Se añadió un pie fijo al selector de ingredientes para mantener visible Aplicar sin recorrer toda la lista.

Capturas de la app compilada: [semana de escritorio](capturas/semana.jpg) y [semana móvil](capturas/semana-movil.jpg).

En la auditoría posterior se utilizó una base SQLite independiente con cuentas ficticias, web en 127.0.0.1:8280 y API en 127.0.0.1:8281. Se verificaron acceso y restauración de sesión, opiniones con confirmación de descarte y guardado, preferencias persistidas, búsqueda de «atun», detalle de catálogo, entregas con estados e historial, corrección y aprobación por operario y publicación para cliente. Se revisó la presentación clara a 390 × 844 y 1440 × 960. El asistente de la cuenta de revisión se preparó mediante la API; su recorrido en navegador corresponde a la validación anterior.

Evidencia de esta auditoría: [opiniones móvil](capturas/auditoria-opiniones-movil.jpg), [entregas escritorio](capturas/auditoria-entregas-escritorio.jpg) y [operario](capturas/auditoria-operario.jpg).

## Límites de lo comprobado

- La APK se compiló; todavía no se ha ejecutado en un teléfono por LAN.
- Windows se compiló; no se ha realizado un recorrido en su ejecutable.
- Groq solo se comprobó mediante respuestas simuladas. Falta clave local y generación mensual real.
- No se han realizado las dos pruebas externas del [protocolo](protocolo_pruebas.md).
- El catálogo sigue siendo una demostración sin validación para consumo real.
