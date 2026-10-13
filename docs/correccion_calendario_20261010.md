# Corrección de calendario · 10/10/2026

## Causa reproducida

Al avanzar de la semana 19–25/10/2026, Flutter sumaba `Duration(days: 7)` a un `DateTime` local. Se suman 168 horas y el cambio de horario de octubre introduce una hora adicional en el calendario: en la zona Romance Standard Time el resultado era domingo `2026-10-25 23:00`, por lo que `dateKey` enviaba `start=2026-10-25`.

El backend rechazaba correctamente esa petición: `/menus/week` requiere un lunes. El `200` de `/menus/ensure` pertenece a otra operación y no confirma que el parámetro semanal sea válido. El banner de lectura mostraba datos de la semana anterior porque la consulta nueva fallaba; no era una caída de la API.

## Cambio

Las fechas civiles se representan mediante sus componentes año/mes/día en UTC como representación neutra, sin convertir un instante local a UTC. `calendarDate`, `addCalendarDays` y `mondayOf` en [models.dart](../easyeats/lib/core/models.dart) centralizan esta regla.

- Semana: inicio en lunes, navegación anterior/siguiente y vuelta a esta semana; detección del mes que termina la semana y cálculo de días hasta final de mes.
- Opiniones: consulta de la semana actual y anterior con lunes válidos.
- Configuración: próximo día del calendario elegido y límite mínimo del selector de fecha fijado en mañana.

No se altera el contrato del backend ni los menús guardados.

## Pruebas ejecutadas

Se añadieron [seis regresiones](../easyeats/test/calendar_regression_test.dart). Antes de corregir el código se reprodujeron el domingo 25/10 al avanzar la semana, domingo 22/03 al consultar opiniones y fecha 25/10 en lugar de 26/10 tanto en el selector como en la propuesta del asistente. Las regresiones pasan después del cambio.

Las pruebas cubren navegación 19/10 → 26/10 → 02/11 y regreso; navegación de marzo; opiniones tras el cambio de hora de marzo; los dos mecanismos de fecha de inicio; conservación de componentes civiles, fin de año y febrero bisiesto. El mock rechaza los domingos con el mismo `422` y mensaje de la API.

**35 pruebas de Flutter pasan y Flutter analyze no muestra incidencias.** La reproducción se ejecutó en Windows con zona Romance Standard Time; no se cambió el reloj ni la zona del equipo. Las 45 pruebas de backend de la fase anterior siguen documentadas; en esta corrección no hay cambios de backend.

Se recompilaron correctamente Windows release, web release con recursos locales y Android debug APK con la corrección. La comprobación funcional de este fallo corresponde a las regresiones de widgets en Windows; no se presenta como un recorrido del nuevo ejecutable nativo.

## Usar la corrección

El código nuevo requiere recompilar o reiniciar Flutter. Un ejecutable ya abierto conserva el código anterior. El artefacto Windows actualizado está compilado en `easyeats/build/windows/x64/runner/Release/`; debe conservarse la carpeta completa con sus DLL y `data/`.

En desarrollo, desde `easyeats/`, volver a ejecutar `flutter run -d windows` tras cerrar la app anterior. La API no necesita cambios para esta corrección.
