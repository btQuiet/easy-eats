# Protocolo de pruebas del prototipo

Estado: **pruebas externas planificadas, aún no realizadas**. Este documento es un guion y una plantilla; no representa observaciones de participantes. Las comprobaciones automáticas y de navegador están en [validación de desarrollo](validacion_desarrollo.md).

El enunciado exige probar con dos personas externas al equipo e introducir al menos una mejora significativa basada en lo observado. No se recogerán datos sensibles ni se presentarán respuestas de IA como si fueran pruebas con personas.

## Preparación

- Dos participantes externos: P1 en Android con Free; P2 en web de escritorio con Pro. Selección y participación aún pendientes de ejecución.
- Servidor FastAPI en LAN y app abierta en web de escritorio o Android.
- Anotar el modo activo (`test` o `ai`) en cada sesión; no llamar IA a una propuesta del modo de pruebas.
- Cuentas y direcciones ficticias preparadas; catálogo marcado como demostrativo.
- Un cliente Free y uno Pro, y una cuenta de operario.
- Una pauta de observación con tiempo, pasos, errores y frases literales breves solo si la persona autoriza anotarlas.
- Un perfil preparado con comidas aprobadas de fecha actual/pasada para la tarea de opinión. Un alta nueva empieza en fechas futuras y no permite opinar anticipadamente; por eso esa tarea se realiza con el perfil preparado.
- Realizar las tareas 1-5 con una cuenta nueva, la 6 con ese perfil de historial y la 7 en la cuenta Pro. Explicar el cambio de cuenta sin indicar dónde están los controles.

## Tareas sin instrucciones de interfaz

1. Configurar un cliente con dos días y un número distinto de comidas en cada día.
2. Declarar una restricción alimentaria y generar el menú mensual.
3. Desde el rol de operario, revisar y aprobar el primer menú.
4. Volver al cliente, encontrar el plato de una semana y consultar sus ingredientes.
5. Sustituir una comida futura por un plato del catálogo sin pedir intervención al operario.
6. Registrar una opinión y explicar dónde espera ver su efecto.
7. En una cuenta Pro, localizar el estado de entrega simulado. En Free, comprobar qué entiende que incluye su plan.

## Qué observar

- Dónde duda la persona, qué términos no entiende y cuántos intentos necesita.
- Si distingue restricciones obligatorias de gustos y si comprende que el catálogo no certifica ausencia real de alérgenos.
- Si comprende el estado «pendiente de primera revisión» y que las sustituciones futuras son su responsabilidad.
- Si encuentra día, comida, detalle y acción de cambio en móvil y escritorio.
- Si percibe claramente la diferencia Free/Pro y el carácter simulado de la entrega.
- Si la función de IA parece útil y explicable dentro de la tarea completa.

## Registro por participante

| Campo | P1 | P2 |
| --- | --- | --- |
| Fecha y dispositivo | Pendiente | Pendiente |
| Modo de generación activo | Pendiente | Pendiente |
| Tareas completadas sin ayuda | Pendiente | Pendiente |
| Dudas o errores observados | Pendiente | Pendiente |
| Tiempo aproximado | Pendiente | Pendiente |
| Comentarios autorizados | Pendiente | Pendiente |
| Propuesta de mejora | Pendiente | Pendiente |

## Mejora y comprobación

Después de las dos pruebas, elegir un problema observado que afecte al recorrido principal. Registrar: evidencia concreta, cambio aplicado, por qué se eligió frente a otras opciones y una repetición breve de la tarea afectada. Esta sección seguirá pendiente hasta que existan observaciones reales.

## Comprobación automatizada complementaria

El dominio tendrá un reloj inyectable para comprobar en tests el alta, aprobación, paso de días y opinión de la misma cuenta, sin esperas reales. En la demo LAN el servidor usa el reloj real; el cliente no puede cambiarlo. Los tests con reloj controlado no sustituyen las pruebas con participantes.
