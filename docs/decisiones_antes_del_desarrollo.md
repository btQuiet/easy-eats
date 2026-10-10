# Especificación final de Easy Eats · primera versión

Fecha: 10 de octubre de 2026. Estado: **decisiones de diseño cerradas e implementación funcional disponible** por encargo del usuario. Este documento sustituye la revisión de pendientes y prevalece sobre los borradores anteriores. La evidencia ejecutada y sus límites se detallan en [validación](validacion_desarrollo.md).

## 1. Alcance y punto de partida

Primera versión académica para web de escritorio y Android, con FastAPI en LAN. Windows conserva compatibilidad, con validación secundaria. Free incluye menú, catálogo, cambios y opiniones; Pro añade dirección ficticia y entregas simuladas. Quedan fuera pagos, logística real, notificaciones push, nutrición y uso de datos personales reales.

Se partió de catálogo reproducible, proyecto Flutter básico, tema claro/oscuro y propuesta visual. Ahora existe backend, pantallas conectadas, pruebas de negocio e integración y compilaciones web/Android/Windows. El código descartado en Git no se recuperó. La ejecución mensual real de IA y las pruebas externas siguen pendientes.

Fuentes vigentes: este documento para reglas, [contrato API](contrato_api.md), [modelo de datos](modelo_datos.md), [frontend](propuesta_frontend.md), [arquitectura](estructura_y_plan.md) y [generadores](modos_generacion.md). Los documentos históricos no modifican estas reglas.

## 2. Calendario, inicio y renovación

- Zona de servicio única: `Europe/Madrid`. El servidor decide la fecha de hoy; el reloj del cliente no concede permisos.
- Fechas de comida: `YYYY-MM-DD`; mes: `YYYY-MM`; semana ISO de lunes a domingo. Auditoría: fecha/hora UTC.
- Plantilla semanal con días ISO 1-7 y `desayuno`, `comida`, `merienda`, `cena`, en ese orden visual. Mínimo una comida semanal; máximo cuatro por día; sin duplicados.
- Fecha de inicio editable en el resumen del asistente: mínimo mañana, máximo último día del mes siguiente. Valor inicial: primera fecha seleccionada del calendario a partir de mañana.
- Primer ciclo: mes natural de la fecha de inicio, solo con huecos a partir de esa fecha. Los siguientes cubren el mes completo según su plantilla efectiva.
- Existe como máximo un ciclo por usuario y mes. Pedirlo otra vez devuelve el existente o el intento activo; no duplica menús ni llamadas.
- Durante la primera revisión no se muestran asignaciones privadas de la propuesta al cliente. Ve estado y mes previsto.
- Al aprobar, se excluyen las asignaciones con fecha igual o anterior a hoy. El servicio empieza en la primera asignación restante. Las fechas excluidas quedan auditadas como canceladas y no admiten opinión.
- Si no quedan asignaciones futuras, el ciclo inicial pasa a `expired` sin contar como primera aprobación. Se genera el siguiente mes con comidas disponibles y continúa requiriendo revisión.
- Tras la primera aprobación, los ciclos posteriores válidos se aprueban automáticamente. Solo hay una primera aprobación por usuario y base de ejecución.
- Renovación bajo demanda: al abrir Semana, el cliente solicita asegurar el mes necesario; durante los últimos siete días del mes también solicita el siguiente. Abrir Próxima semana asegura los meses que cruzan sus fechas. No se añade un programador de tareas a esta versión.
- Si hay una primera revisión vigente, no se genera otro primer ciclo en paralelo. Al expirar, la solicitud puede iniciar su sustituto.
- Una semana combina fechas de todos sus ciclos aprobados. Un tramo todavía no generado o aprobado se muestra con su estado, sin rellenarlo con platos ficticios.

Ejemplos: alta el 10/10/2026 con lunes y jueves → inicio sugerido 12/10 y ciclo parcial de octubre. Aprobación el 15/10 → se cancelan 12 y 15; primer servicio 19/10. Si el último hueco de octubre ya venció, la propuesta pasa a noviembre y mantiene revisión inicial. La semana 26/10-01/11 combina ambos meses.

## 3. Restricciones y asignaciones

Un candidato debe estar activo, pertenecer al momento de comida, cumplir dieta y no contener ingredientes excluidos ni alérgenos declarados según el catálogo modelado. Ese filtro rige generación, corrección del operario y sustitución. Los gustos nunca permiten saltarlo.

Dieta: `omnivore`, `vegetarian` o `vegan`. Alérgenos e ingredientes usan códigos existentes. Los ingredientes favoritos y poco deseados son conjuntos separados y no pueden solaparse; una restricción tiene prioridad sobre cualquier gusto.

Cliente: cambia una asignación propia de un ciclo aprobado con fecha **posterior a hoy**, incluidos días restantes de la semana actual. También puede corregir un plato futuro marcado incompatible. El selector solo ofrece candidatos compatibles; se revalida al confirmar. Si no hay candidatos, muestra el conflicto sin eliminar restricciones.

Operario: cambia y regenera solo la primera propuesta pendiente. No modifica ciclos aprobados ni sustituciones del cliente. La versión de la propuesta y el perfil se verifican al aprobar.

El catálogo general puede mostrar todos los platos, con su compatibilidad señalada. El selector de cambios siempre está filtrado para la asignación concreta.

## 4. Cambios de perfil y conservación del menú

| Cambio | Vigencia | Efecto |
| --- | --- | --- |
| Restricciones | Inmediata al guardar | Recalcular compatibilidad de hoy y fechas futuras, en cualquier ciclo. |
| Calendario antes de primera aprobación | Próxima generación inicial | Invalidar intentos con la versión anterior; propuesta pendiente necesita actualizarse antes de aprobar. |
| Calendario después de primera aprobación | Primer mes futuro sin ciclo aprobado | Mostrar el mes efectivo antes de guardar; conservar ciclos ya publicados. |
| Gustos y tolerancia a repetición | Nuevos intentos de generación | No reescribir menús publicados. |
| Opinión | Nuevos intentos de generación | Cambiar puntuación futura; mantener asignaciones actuales. |
| Dirección | Entregas todavía programadas | Actualizar dirección de esas entregas; conservar las ya preparadas o completadas. |

Si noviembre ya está aprobado cuando se edita el calendario en octubre, se indica que el cambio empieza en diciembre. Editar otra vez reemplaza la plantilla pendiente para ese mismo mes efectivo.

Un plato incompatible queda `needs_attention` y no se presenta como recomendación vigente. Si corresponde a hoy, se informa del conflicto sin habilitar una sustitución retroactiva. Fechas pasadas mantienen su contexto histórico. Relajar restricciones vuelve a evaluar y puede retirar el aviso.

No hay regeneración masiva de ciclos aprobados en esta versión. Por tanto, cambiar gustos o calendario no borra sustituciones confirmadas. Las propuestas pendientes sí se pueden regenerar; sus correcciones de operario se reemplazan y la interfaz lo avisa.

Cada intento captura versiones de perfil, calendario, preferencias y catálogo. Si cambian durante generación, el resultado se descarta con `INPUT_CHANGED` y se ofrece generar de nuevo. La aprobación inicial exige versiones vigentes.

## 5. Opiniones, puntuación y repetición

Opinión: una por asignación, editable, con `rating=1` o `rating=-1` y comentario opcional de hasta 500 caracteres. Solo sobre asignaciones propias, aprobadas, no canceladas y con fecha actual o pasada. El comentario se almacena; no se interpreta automáticamente.

Se agrega la valoración media de cada plato en comidas de los últimos 90 días. La puntuación por candidato es:

`2 × favoritos presentes (máximo +6) - 2 × ingredientes poco deseados (máximo -6) + 3 si categoría preferida + 4 × media de opiniones - 2 × apariciones en los 14 días anteriores`.

Sin opiniones, la media es cero. Para planificar se incluyen asignaciones aprobadas previas y las ya elegidas dentro del intento; se excluye la propuesta que se está reemplazando. El generador de pruebas ordena por puntuación descendente y, en empate, por código ascendente.

Tolerancia: `low` = objetivo de una aparición del plato por siete días; `normal` = dos; `high` = tres. Por defecto `normal`. El intervalo incluye la fecha elegida y sus seis días anteriores, sumando todas las comidas.

La política común evalúa en orden cronológico:
1. Preferir candidatos sin repetición en el día y por debajo del objetivo semanal.
2. Si no existen, permitir superar el objetivo semanal, sin repetir en el día.
3. Si tampoco existen, permitir repetir en el día.
4. Registrar `VARIETY_RELAXED` cuando se use 2 o 3. Nunca relajar restricciones obligatorias.

La IA usa el mismo conjunto y política. El validador comprueba que no se saltó un nivel disponible. Ejemplo verificable: dos platos con puntuación base cero y sin repeticiones empatan; una opinión positiva eleva uno a +4 y una negativa lo baja a -4, alterando el orden de selección local.

## 6. Estados, generación y concurrencia

Estados de ciclo: `draft`, `pending_review`, `approved`, `expired`. Un ciclo aprobado pasado conserva `approved` y se consulta como histórico. Estados de intento: `queued`, `running`, `succeeded`, `failed`, `cancelled`. Compatibilidad del item: `compatible` o `needs_attention`; cancelación es un campo independiente.

Un intento fallido no sustituye una propuesta válida ni un menú aprobado. Publicación y auditoría ocurren en una transacción, después de validar cobertura exacta y versiones. Una revisión inicial incluye actor, fecha y versión aprobada.

La generación devuelve `202` e identificador de intento. Un worker del proceso FastAPI toma una cola persistida en SQLite; una generación externa activa por servidor. El cliente consulta cada dos segundos mientras la pantalla está visible y deja de consultar al salir. El trabajo continúa en servidor.

Al reiniciar, se retoman intentos `queued`; los que estaban `running` pasan a `failed/SERVER_RESTARTED` y permiten reintento. No se repite una llamada externa incierta automáticamente.

Cada escritura modificable usa `expected_version`. Un conflicto devuelve `409` con versión actual; la pantalla recarga y conserva su elección para una nueva confirmación. No hay última escritura silenciosa.

Generación, sustitución y aprobación usan `Idempotency-Key`. Mismo usuario, operación, clave y contenido devuelve el mismo resultado durante 24 horas; cambiar contenido con la misma clave devuelve `409`. Además se impide otro intento activo para el mismo ciclo aunque cambie la clave.

## 7. Cuenta, sesión y asistente

Alias normalizado en minúsculas, 3-30 caracteres `a-z`, números o guion bajo. Contraseña 8-128 caracteres. El registro crea únicamente clientes; operario se crea desde configuración del servidor. No hay recuperación por correo ni registro público de operarios.

Contraseñas: `hashlib.scrypt` con sal aleatoria de 16 bytes, N=16384, r=8, p=1 y salida de 32 bytes; parámetros almacenados con el hash. Sesión opaca aleatoria de 32 bytes, hash SHA-256 en servidor, caducidad absoluta de siete días y revocación al cerrar sesión. Bloqueo temporal tras diez accesos fallidos en quince minutos por alias o IP.

Web: cookie HttpOnly, SameSite=Strict y Path=/api/v1, con credenciales incluidas en peticiones. En demo HTTP LAN, Secure=false; en HTTPS, Secure=true. Orígenes exactos autorizados y token CSRF de sesión obligatorio en escrituras con cookie. API y web usan el mismo hostname/IP en la LAN, aunque tengan puertos distintos. No almacenar token de sesión en localStorage.

Android/Windows: bearer guardado mediante `flutter_secure_storage`. Al cambiar de servidor se cierra la sesión local; no se envía el token anterior al nuevo host.

API_BASE_URL configura la dirección inicial, sin /api/v1. Por defecto: web usa el hostname de su página con puerto 8000; Windows usa http://localhost:8000; Android solicita la dirección LAN al no tener configuración. En acceso, «Servidor LAN» permite editar esa dirección. En web el hostname debe coincidir con el de la página para la sesión cookie; se indica que debe abrirse la web con ese mismo hostname/IP. Solo http/https, sin credenciales, query o fragmento. Se conserva la dirección elegida como configuración, separada de sesión; en web puede usarse localStorage para esa dirección y un indicador no secreto de cierre local, nunca para tokens. Cerrar sesión sin conexión impide restaurar la cookie anterior al recargar; un acceso nuevo elimina ese indicador. La revocación en servidor se intenta al cerrar y requiere conexión.

Cinco pasos: Plan, Calendario, Restricciones, Gustos, Resumen. Dirección ficticia y fecha de inicio se editan en Resumen. Cada avance guarda el borrador en servidor; volver atrás conserva campos. Reiniciar retoma el último paso confirmado. Guardar el resumen completa el perfil; generar es una acción independiente.

Un fallo de red conserva el formulario en memoria y muestra que no se pudo confirmar el guardado. Se consulta operación o versión antes de repetir una escritura incierta. No se almacenan escrituras de negocio para enviarlas fuera de línea.

## 8. Planes y entregas simuladas

El plan inicial entra en vigor al completar el perfil. Un cambio posterior entra en vigor el lunes siguiente a las 00:00. Hasta entonces rigen las capacidades actuales; se muestra plan pendiente y fecha. Elegir de nuevo el plan vigente cancela el cambio pendiente. Toda comprobación de capacidades calcula primero el plan efectivo de esa fecha, aunque todavía no se haya abierto Perfil.

Pro requiere dirección: `line1`, `city` y `postal_code`; `notes` opcional. Límites respectivos: 150, 80, 12 y 250 caracteres. Se usan datos ficticios. Sin dirección válida, no se confirma Pro. En una subida de Free, dirección y cambio de plan se guardan juntos; no se exige ya ser Pro para introducirla. Al pasar a Free se oculta Entregas desde la fecha efectiva y se cancelan entregas posteriores; el historial se conserva.

Una entrega simulada por usuario y semana, solo con comidas aprobadas compatibles dentro de la vigencia Pro. Su fecha es la primera fecha de comida cubierta; una primera semana parcial no inventa una entrega anterior al alta o aprobación.

Estados derivados de la fecha en Madrid: `scheduled` hasta el día anterior a las 09:00; `preparing` desde entonces; `in_delivery` el día de entrega entre 09:00 y 18:00; `delivered` desde las 18:00. `cancelled` si antes de preparación desaparecen todas las comidas cubiertas, o si cesa Pro antes de entrar en reparto. El cambio de plan puede cancelar una entrega preparada, conservando su snapshot.

Una subida pendiente a Pro conserva las entregas de su vigencia futura; no se cancela por seguir siendo Free hoy. Si se restaura el plan o vuelven a existir comidas compatibles antes de preparación, una entrega futura cancelada y sin snapshot vuelve a programarse con el mismo identificador. Una captura preparada o pasada conserva su historial.

La dirección y comidas se capturan al entrar en preparación. Después no se reescribe ese historial. La entrega no impide cambiar un menú futuro: es una representación de demo, no una operación logística. Todos sus estados llevan el distintivo «Entrega simulada» y no se envían avisos reales.

## 9. Arquitectura Flutter y diseño cerrado

Estado: controladores por funcionalidad con `ChangeNotifier` y vistas con `ListenableBuilder`; modelos inmutables y repositorios inyectados por constructor. No añadir otro gestor de estado a la primera versión.

Rutas con `go_router`, shell por rol y redirecciones según sesión/perfil. Red con `http.Client` inyectable; fábricas web/nativa. Flutter nunca consulta SQLite de negocio ni llama directamente al proveedor IA. Versiones de paquetes se resuelven contra el SDK al implementarlos y quedan en `pubspec.lock`.

Selección técnica basada en las interfaces documentadas de [go_router](https://pub.dev/packages/go_router), [http](https://pub.dev/packages/http) y [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage). Los paquetes están añadidos con lockfile; web utiliza cookie y nativo almacenamiento seguro.

Navegación cliente: Mi semana, Catálogo, Opiniones y Perfil. Entregas en Semana/Perfil para Pro y en lateral de escritorio. Operario: Primeras revisiones y Catálogo. Semana conserva día y fechas al entrar/salir de detalle.

Anchos: menos de 600 px, barra inferior y una columna; 600-1023 px, NavigationRail; desde 1024 px, lateral de 240 px. Contenido máximo 1200 px, margen 16/24/32 según tamaño. Operario en dos columnas desde 1024 px, cola de 320 px; por debajo, lista y detalle separados.

Detalle: hoja inferior de hasta 90% de alto en móvil; panel modal de máximo 640 px y nunca mayor que el ancho disponible menos 32 px en tamaños mayores. Scroll interno, área segura y teclado contemplados. Atrás cierra primero el detalle. Un formulario editado avisa antes de descartar; una sustitución siempre muestra confirmación con plato anterior y nuevo.

Se mantiene `AppTheme`: crema, bosque, salvia, coral, controles de radio 12, tarjetas 20 y paneles 24. Serif del sistema para titulares (Georgia con alternativas), sans nativa para cuerpo; se acepta variación tipográfica entre plataformas en esta versión. Iconos Material outlined, marca tipográfica «easy eats.» y sin fotografías genéricas.

Tema según sistema. Animaciones breves de 180 ms que respetan movimiento reducido. Carga, vacío, pendiente, incompatible, error y desconexión usan texto e icono. Foco visible, navegación por teclado, controles de al menos 48 px y comprobación con texto al 200%.

Ruta sin conexión: datos ya cargados quedan en lectura con aviso de antigüedad; no se confirman escrituras. En inicio sin sesión comprobable se muestra reconexión. Un `401` obliga a acceder de nuevo; un `403` muestra falta de permiso.

Tiempo de espera HTTP ordinario: 15 segundos; ninguna escritura se reintenta automáticamente con una operación nueva. Idioma inicial español, fechas es-ES y formato horario de 24 horas. El API cliente conserva errores estructurados para que cada pantalla explique la acción pendiente.

## 10. Generadores y proveedor de IA

Modo por defecto `test`, local determinista. Modo `ai` elegido al arrancar servidor, con bases separadas, sin migración automática de cuentas.

Adaptador elegido: Groq, modelo `openai/gpt-oss-120b`, Chat Completions y `json_schema` estricto, sin herramientas ni streaming. El proveedor documenta ese modelo y soporte estructurado: [modelos](https://console.groq.com/docs/models), [salidas estructuradas](https://console.groq.com/docs/structured-outputs). El adaptador está implementado y probado con transporte simulado; falta verificar una generación mensual real.

Solo se envían huecos, candidatos, preferencias normalizadas y política de variedad; sin alias, dirección, credenciales ni comentarios libres. Respuesta: un array `items` con `date`, `meal_slot` y `recipe_code`; ninguna receta inventada.

Máximo dos llamadas por intento, 45 segundos por llamada, plazo total 120 segundos y máximo 8192 tokens de salida por llamada. Una respuesta inválida permite una corrección con errores de validación; fallo transitorio permite un reintento dentro del mismo límite de dos llamadas. Un `429` respeta Retry-After si cabe en el plazo; si no, devuelve error y momento de reintento. La cuota de la cuenta debe permitir el tamaño de petición; no se presupone una tarifa o cuota gratuita concreta. [Límites del proveedor](https://console.groq.com/docs/rate-limits).

Sin clave: consultas disponibles y `can_generate=false`. Sin respuesta válida: error visible y último menú preservado. Nunca pasar silenciosamente de IA a pruebas. Proveedor/modelo siguen configurables sin cambiar el contrato.

## 11. Validación y orden de desarrollo

1. Contrato, migración inicial, sesión, perfil y catálogo por LAN.
2. Shell Flutter y recorrido local: configuración → generación → primera revisión → semana.
3. Sustitución, opinión, perfiles/versiones, renovación y Pro.
4. Adaptador IA y prueba real; casos de errores y concurrencia.
5. Validación web/Android, dos personas externas y una mejora observada.

Casos obligatorios: mes parcial; primera revisión vencida; semana entre meses; cero candidatos; variedad insuficiente; segundo ciclo sin revisión; acceso a datos ajenos; sustitución repetida; conflicto de versión; restricción modificada durante generación; pérdida de respuesta después de guardar; servidor reiniciado; cambio de plan; IA inválida o no disponible. Los tests de dominio usan reloj inyectable; la LAN usa fecha real. Las tareas externas de opinión usan un perfil con histórico preparado para respetar el bloqueo de opiniones futuras.

Criterio de terminado: una cuenta nueva completa el recorrido, sus cambios persisten y una opinión influye en la puntuación del siguiente intento. Free no accede a entregas; el cliente no actúa como operario. La IA solo se considera verificada tras una generación mensual real válida. Las pruebas externas y la mejora se registran cuando sucedan.

Las decisiones quedan cerradas y la primera implementación está disponible. Permanecen como tareas de validación configurar una clave local, ejecutar IA real, preparar dispositivos y realizar las pruebas externas; no son nuevas decisiones de producto.
