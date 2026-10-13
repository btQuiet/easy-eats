# Auditoría de Easy Eats · 10/10/2026

Se revisaron el código presente, las reglas de negocio, los fallos de red y concurrencia, los formularios y la presentación adaptable. Se corrigieron los fallos encontrados y se añadieron regresiones. Tras las [mejoras de producto](mejoras_20261010.md) y la [corrección de calendario](correccion_calendario_20261010.md), **45 pruebas de backend y 35 de Flutter pasan; Flutter analyze no muestra incidencias**. Los artefactos y validaciones por fase se detallan abajo y en los documentos enlazados.

No se recuperó código descartado en Git. Los recorridos de esta auditoría usaron una base SQLite independiente y cuentas ficticias; no se alteraron las cuentas de la base habitual para preparar pruebas. El catálogo original se conservó.

## Fallos reproducidos y correcciones

P1 identifica un fallo de funcionamiento que bloquea un flujo o compromete la confirmación de una operación. P2 identifica pérdidas de edición, errores de recuperación, problemas de presentación o entradas que no se manejaban correctamente.

| Prioridad | Fallo y condición | Corrección y evidencia |
| --- | --- | --- |
| P1 | Una subida Free → Pro pendiente creaba entregas futuras y las cancelaba durante la misma sincronización porque el plan de hoy seguía siendo Free. | La agrupación y la cancelación usan la misma vigencia futura. La regresión `test_pending_pro_deliveries_survive_until_plan_becomes_effective` falló antes del cambio y pasa ahora. |
| P1 | Cancelar y volver a solicitar Pro dejaba entregas futuras canceladas permanentemente. Relajar restricciones tampoco recuperaba una entrega sin comidas válidas. | Se recuperan únicamente entregas futuras sin captura, antes de preparación y con plan/comidas elegibles, conservando sus identificadores. Dos regresiones verifican plan y restricciones; las capturas históricas se conservan. |
| P1 | El timeout del cliente empezaba después de recibir cabeceras: un servidor que no respondía podía dejar la pantalla esperando indefinidamente. | El límite de 15 segundos cubre envío, cabeceras y cuerpo. Prueba con cliente que no entrega cabeceras. |
| P1 | Una respuesta JSON malformada o de estructura inesperada podía escapar del tratamiento de errores. En escrituras no se preservaba correctamente el estado de confirmación incierta. | Validación de envelope, metadatos, errores y resultado recuperado. Una respuesta inválida de escritura mantiene la clave idempotente; las pruebas comprueban recuperación y ausencia de una nueva escritura duplicada. Un 401 también expira la sesión aunque su cuerpo no sea JSON. |
| P2 | Cerrar sesión sin conexión permitía que una recarga restaurara la cookie anterior. | Indicador local no secreto de cierre, comprobado antes de restaurar. El nuevo login lo elimina. La revocación en servidor se intenta al cerrar; el cierre sin conexión protege la restauración local, sin afirmar que haya revocado una cookie remota. Regresión con backend caído y acceso posterior. |
| P2 | Un conflicto de versión dejaba sustitución u opinión intentando guardar otra vez con una versión antigua. | La sustitución recarga comida y candidatos; la opinión permite comprobar la versión y conservar su formulario. El usuario confirma de nuevo. Las pruebas verifican escrituras con versiones 1 y 2 y comentario conservado. La cola del operario también se actualiza ante conflicto o propuesta vencida. |
| P2 | Arrastrar una hoja móvil podía cerrar el formulario saltándose la confirmación de descarte. Un editor podía cerrarse mientras guardaba. | Se desactiva el arrastre de cierre y se protege el cierre durante escrituras. Cerrar/Atrás siguen usando la confirmación. Regresión de selección editada, arrastre y cancelación del descarte; confirmación de opinión comprobada en navegador. |
| P2 | Cerrar una opinión durante su carga podía completar después sobre un controlador de texto destruido. Algo equivalente podía ocurrir con la restauración de sesión. | Guardas de montaje/destrucción y desconexión del callback de sesión. Pruebas que completan respuestas después del cierre. Las respuestas antiguas tampoco reemplazan datos más recientes. |
| P2 | Una forma de datos incorrecta en el repositorio podía romper la carga en lugar de mostrar un error controlado. | Validación de respuestas objeto/lista; la prueba comprueba que termina la carga, conserva datos anteriores y presenta el fallo. |
| P2 | Un banner de desconexión con texto al 200% desbordaba una vista de 320 × 220. | Error inicial desplazable y banner sobre datos guardados con altura limitada y scroll. La regresión reprodujo un desbordamiento de 754 px antes del cambio y pasa ahora. |
| P2 | Tarjetas de perfil, opiniones, candidatos, operario y entregas quedaban pegadas. El aviso de restricciones retiradas se repetía en cada tarjeta del perfil. | Márgenes entre tarjetas y un único aviso de perfil. Se comprobó la presentación en móvil y escritorio; se corrigió también el solapamiento del check con el icono de valoración. |
| P2 | Etiquetas informativas se anunciaban como casillas desmarcadas; buscar «atun» no encontraba «Atún» en el selector de ingredientes. | Semántica de etiqueta estática y búsqueda normalizada sin tildes. Regresiones de semántica y búsqueda, más comprobación real de búsqueda y guardado de preferencias. |
| P2 | Una semana próxima al límite del tipo fecha podía provocar un 500 al sumar sus siete días. | Validación controlada de fecha/semana y respuesta 422. Pruebas parametrizadas de fecha inválida, lunes incorrecto y límite de año. |
| P2 | Groq con `choices` vacío u otras respuestas malformadas no siempre llegaba a la reparación controlada. El timeout de transporte no imponía por sí solo un plazo total de llamada. | Validación del objeto `items`, tratamiento de respuesta malformada y límite total de 45 segundos por llamada. Transporte simulado verifica reparación limitada, rechazo y recuperación de un fallo transitorio; no se cambia a generación local. |
| Menor | El panel mostraba «1 propuestas». | Concordancia singular/plural corregida y artefactos recompilados. |
| P1 | Avanzar desde el lunes 19/10/2026 enviaba domingo 25/10 al cruzar el cambio de hora. Opiniones en marzo y fechas de inicio en octubre compartían la misma aritmética de periodos de 24 horas. | Operaciones de fechas civiles independientes del horario local. La regresión reproduce el domingo antes del cambio y verifica lunes 26/10 después; también comprueba navegación en marzo, opiniones, selector y propuesta de inicio. |

## Revisión del código

Se revisaron sesión/roles/cookies/CSRF, propiedad de recursos, versiones e idempotencia, migraciones y transacciones, generación y publicación, calendario, restricciones, planes/entregas y el adaptador externo. En Flutter se revisaron routing por rol, cliente HTTP, repositorios, controladores, ciclo de vida, carga/errores, formularios, detalles y pantallas por funcionalidad.

Las pruebas existentes verifican, entre otros casos, acceso a datos ajenos, cliente intentando actuar como operario, dos sustituciones concurrentes, cambio de inputs durante generación, reinicio del worker, fallo que conserva la propuesta, cancelación de fechas vencidas, publicación entre meses y snapshots de entregas. La auditoría añadió **29 casos ejecutados** sobre los 35 existentes, las mejoras de producto otros diez y la corrección de calendario otros seis; las parametrizaciones se incluyen en ese recuento.

Código principal de las correcciones:

- [Entregas](../backend/app/services/deliveries.py), [menús](../backend/app/services/menus.py) y [generación](../backend/app/integrations/generation.py).
- [HTTP](../easyeats/lib/core/api_client.dart), [repositorio](../easyeats/lib/core/repository.dart), [controladores](../easyeats/lib/core/controllers.dart) y [almacenamiento web](../easyeats/lib/core/platform_client_web.dart).
- [Carga, etiquetas y detalles](../easyeats/lib/shared/widgets.dart), [sustitución/opinión](../easyeats/lib/shared/meal_detail.dart), [perfil](../easyeats/lib/features/profile/profile_screen.dart) y [operario](../easyeats/lib/features/operator/operator_screen.dart).
- [Pruebas backend](../backend/tests/test_app.py), [proveedor](../backend/tests/test_generation.py), [HTTP Flutter](../easyeats/test/api_client_test.dart), [controladores](../easyeats/test/controllers_test.dart) y [regresiones visuales/formularios](../easyeats/test/audit_widget_test.dart).

## Resultados ejecutados

| Comprobación | Resultado |
| --- | --- |
| Backend, pytest | 45 pasan. Un aviso de deprecación de Starlette/httpx en el transporte de pruebas. |
| Flutter test | 35 pasan. |
| Flutter analyze | Sin incidencias. |
| Web release con recursos locales | Compilación correcta. |
| Android debug APK | Compilación correcta. |
| Windows release, corrección de calendario | Compilación correcta. |
| Consola del recorrido auditado en navegador | Sin mensajes de error ni warning capturados. |

Las dos regresiones de subida pendiente/recuperación de Pro y la de desbordamiento se ejecutaron primero contra el comportamiento defectuoso. Sus fallos quedaron resueltos por los cambios de código, no por relajar las expectativas.

Pruebas de widgets: acceso, navegación, tema oscuro y texto al 200%; los cinco editores de perfil a 320 px; operario a 320, 768 y 1440 px con texto grande; detalle cerrado durante carga; conflicto de sustitución y de opinión; hoja móvil editada; semántica y banner de red.

## Recorrido real de navegador

Web compilada en `http://127.0.0.1:8280`, API actual en `http://127.0.0.1:8281`, modo `test`, fecha real del servidor y base `backend/var/audit_20261010.sqlite` excluida de Git. La generación se ejecutó en el worker real; las cuentas y sus datos eran ficticios. Las contraseñas de auditoría no forman parte de este documento ni del código.

1. Configuración de servidor, acceso de cliente Pro y restauración de sesión tras recarga.
2. Semana parcial y completa, navegación entre semanas y disposición móvil/escritorio.
3. Opinión histórica: edición, Cerrar → Cancelar conserva el texto, guardar y aparición en el historial.
4. Preferencias: «atun» encuentra «Atún», selección y guardado; reabrir muestra el ingrediente persistido.
5. Catálogo: «atun» devuelve tres platos; el detalle muestra ingredientes, compatibilidad y alérgenos modelados.
6. Entregas Pro: semanas programadas, preparación y entregadas; dirección capturada visible en el historial.
7. Operario: propuesta vegana, corrección confirmada de Lentejas con verduras y arroz a Alubias rojas con arroz y maíz; aprobación y salida de la cola.
8. Cliente Free: ve el plato publicado, sustituye por Arroz con berenjena y tahini con confirmación, el cambio aparece en la semana; la siguiente semana muestra 14 comidas. No aparece navegación a Entregas.

Para este recorrido se preparó el asistente de la cuenta pendiente mediante solicitudes a la API. No se contabiliza como una repetición en navegador de los cinco pasos, que sí constan en la validación anterior. Las nuevas pantallas claras se revisaron a **390 × 844** y **1440 × 960**; los tests de widgets completan los anchos intermedios, texto grande y tema oscuro.

Capturas:

- [Opinión guardada en móvil](capturas/auditoria-opiniones-movil.jpg).
- [Entregas en escritorio](capturas/auditoria-entregas-escritorio.jpg).
- [Operario tras corregir el plato](capturas/auditoria-operario.jpg).
- [Semana completa del cliente](capturas/auditoria-semana-escritorio.jpg).

## Contraste del tema

Se calculó contraste relativo para ocho pares principales del [tema](../easyeats/lib/app/theme/app_theme.dart), sin cambiar la paleta. Todos superan 4,5:1 para texto normal en esos pares. Esta comprobación no certifica accesibilidad de todas las combinaciones, estados, controles ni lectores de pantalla.

| Par de colores | Contraste |
| --- | ---: |
| Bosque / papel | 11,86:1 |
| Texto secundario / crema | 4,65:1 |
| Papel / coral de acción | 5,19:1 |
| Texto del lateral / bosque | 10,77:1 |
| Texto secundario del lateral / bosque | 6,77:1 |
| Texto oscuro / papel oscuro | 12,01:1 |
| Texto secundario oscuro / fondo oscuro | 8,91:1 |
| Texto sobre coral oscuro / coral oscuro | 7,56:1 |

## Validaciones que siguen pendientes

- Ejecutar la APK en un teléfono mediante LAN y recorrer el ejecutable Windows. Las compilaciones no demuestran su funcionamiento en esos dispositivos.
- Ejecutar una generación mensual real de Groq con una clave local. Las pruebas actuales utilizan transporte simulado.
- Realizar las pruebas con participantes y registrar la mejora observada del [protocolo](protocolo_pruebas.md).
- El catálogo conserva su carácter de demostración sin validación para consumo real.

La evidencia completa se relaciona con [validación de desarrollo](validacion_desarrollo.md). Se arrancó el backend con el código actualizado y se recompilaron los artefactos. Los nuevos resúmenes y pantallas se documentan en [mejoras de producto](mejoras_20261010.md).
