# Repaso final antes del desarrollo

> Documento histórico redactado antes del visto bueno. El estado actual de la implementación y los comandos de arranque están en [README.md](../README.md).

Fecha: 8 de octubre de 2026. Estado: **listo para empezar cuando el usuario dé el visto bueno**. Este documento consolida la conversación, el catálogo, el flujo inicial, las fotografías de trabajo y el enunciado de la práctica. No registra pruebas con personas ni afirma que la integración de IA ya funcione.

## 1. Decisiones confirmadas

| Tema | Decisión vigente |
| --- | --- |
| Producto | Easy Eats crea menús personalizados a partir de un catálogo de platos. |
| Superficies | Flutter adaptable a web de escritorio y Android; el proyecto existente incluye también Windows. |
| Servidor y datos | FastAPI en un equipo de la LAN; SQLite para catálogo y estado de la aplicación. |
| Calendario | El usuario elige qué días de la semana y qué comidas quiere cada día. Se diseñan desayuno, comida, cena y merienda. |
| Plan Free | Menú, catálogo, sustituciones y opiniones, sin entrega a domicilio. |
| Plan Pro | Todo lo anterior y experiencia de entrega a domicilio; representada de forma simulada en el prototipo. |
| Catálogo | 125 platos y 94 ingredientes, con 14 grupos de alérgenos modelados; datos de demostración no verificados. |
| Perfil | Dieta, alérgenos, ingredientes excluidos y preferencias; no se recogen peso, altura, edad o género sin una función nutricional real. |
| Generación | Planificación mensual; modo local de pruebas ahora y modo IA real activable más adelante. |
| Revisión | El operario revisa y aprueba únicamente la primera propuesta mensual de cada usuario. |
| Cambios | El usuario elige sustituciones futuras del catálogo y asume su revisión; no interviene el operario. |
| Aprendizaje | Las opiniones pueden influir en preferencias futuras, pero no modificar restricciones obligatorias. |
| Entrega digital | Vista semanal para el cliente; el mes existe internamente. |

Cuando el documento inicial `flujo_aplicacion_menus.md` habla de revisión del operario para todos los meses o cambios, prevalece la regla posterior reflejada arriba.

## 2. Inventario de funciones preparado en el diseño

**Cliente:** acceso de prueba, elección/cambio de plan, asistente de perfil, calendario variable, catálogo y detalle de plato, menú semanal, próxima semana, sustitución futura, opiniones, historial, edición de restricciones y preferencias, avisos por cambios de perfil, estado de generación y errores, y entregas simuladas si es Pro.

**Operario:** cola exclusiva de primeras propuestas, ficha relevante del cliente, vista mensual, corrección/regeneración de la primera propuesta y aprobación inicial. No hay cola de cambios posteriores.

**Servidor:** catálogo consultable, elegibilidad previa por reglas, creación de huecos mensuales, generadores intercambiables, validación común, persistencia por modo, primera revisión, gestión de semanas, cambios, feedback, roles y capacidades de plan.

**Variables derivadas clave:** huecos del mes según días/comidas, número de candidatos por comida, alérgenos modelados y dieta de cada plato, puntuación de preferencias, recuento de repeticiones, necesidad de primera revisión, semana vigente, posibilidad de sustituir, asignaciones futuras afectadas por restricciones, capacidad de entrega, origen `test`/`ai` de cada menú y estado de disponibilidad del generador. El detalle está en `docs/estructura_y_plan.md`.

## 3. Arquitectura de generación acordada

`docs/modos_generacion.md` define un mismo contrato y un único validador para los dos modos. `test` selecciona platos de forma local y determinista; no requiere clave ni demuestra IA. `ai` utilizará un proveedor externo configurado en FastAPI, con clave solo en el entorno del servidor. Si falla, muestra error y conserva el último menú aprobado; no se sustituye por el generador local sin avisar. Las bases `app_test.sqlite` y `app_ai.sqlite` estarán separadas para que la revisión de prueba no altere el estado real; los perfiles de prueba no se migrarán solos al modo IA.

La selección del proveedor y del modelo, y la prueba de una llamada real, quedan para cuando se configure la clave. La interfaz mostrará el modo y el origen de cada menú para que la demostración sea honesta.

## 4. Supuestos de diseño tomados para poder avanzar

- El calendario es una plantilla semanal que se expande al mes; los días sin comidas no generan huecos.
- La primera revisión se interpreta **por usuario y por base/modo**. Una aprobación de prueba no aprueba su primer ciclo en modo IA.
- Una vez aprobada la primera propuesta, los siguientes ciclos válidos se aprueban automáticamente; el usuario ve la semana actual y puede preparar cambios de la siguiente.
- La entrega Pro y la dirección son datos ficticios de demostración. No se cobran planes ni se asignan repartidores.
- Las sustituciones muestran ingredientes y advertencias del catálogo, pero se confirman por el propio usuario sin revisión de operario.

Estos supuestos están documentados para que la implementación no dependa de decisiones ocultas.

## 5. Límites y pendientes que no bloquean el inicio

1. **Clave y modelo de IA:** no se ha proporcionado ninguno. El modo de pruebas y la arquitectura común pueden desarrollarse ya. Para afirmar que la IA está integrada en la demo habrá que activar y probar el modo `ai` con una clave local válida.
2. **Datos alimentarios:** el catálogo no contiene fichas de proveedor, cantidades ni contaminación cruzada. Sirve para el prototipo, no para entregar comida real ni certificar compatibilidad con alergias.
3. **Red LAN:** la dirección IP del servidor se configurará al probar con los dispositivos. Android no apuntará a `localhost`.
4. **Pruebas externas:** el enunciado pide dos personas y una mejora basada en lo observado. El protocolo está preparado; no hay resultados todavía.
5. **Comercialización:** precio, pagos, zonas de reparto y logística real no se han definido y no forman parte del recorrido académico prioritario.

## 6. Estado de archivos antes del visto bueno

- `data/catalog.sqlite` y sus CSV/esquema ya existen.
- `easyeats/` contiene el proyecto Flutter mínimo; aún no hay pantallas de Easy Eats implementadas.
- `backend/` y las carpetas funcionales de Flutter están creadas, sin código de aplicación.
- `docs/diseno_producto.md`, `docs/estructura_y_plan.md`, `docs/modos_generacion.md` y `docs/protocolo_pruebas.md` fijan el diseño, la construcción y la validación.

Al recibir el visto bueno, el primer paso de desarrollo será levantar la API del catálogo y el recorrido en **modo de pruebas**, conservando desde el inicio el contrato que usará el adaptador de IA.
