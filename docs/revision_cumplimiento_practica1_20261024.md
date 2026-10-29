# Revisión de cumplimiento · Práctica 1

Fecha: 24/10/2026. Documento interno del equipo.

## Dictamen

**Cumplimiento parcial.** Los formatos de los entregables encajan con el enunciado, pero la documentación disponible todavía no acredita todos los requisitos de trabajo ni todos los criterios de la rúbrica. No debe considerarse una entrega final validada.

El enunciado disponible en el repositorio es `01_Enunciat_i_rubrica_Practica1_UdL.docx.pdf`, de dos páginas. Esta revisión utiliza su contenido, no presupone otro archivo Word distinto.

## Qué exige entregar el profesor

| Entregable formal | Requisito del enunciado | Estado del material generado |
| --- | --- | --- |
| Prototipo | Enlace o acceso que permita probar un recorrido completo. | El paquete Windows con servicio remoto es un formato válido. Queda pendiente verificar la compilación definitiva contra el VPS. |
| Apoyo de la demostración | Máximo dos diapositivas. | Cumple: `Soporte_demo_Easy_Eats.pptx` contiene exactamente dos. |
| Uso de IA | Indicar brevemente qué herramientas se han utilizado y para qué; puede aparecer en las diapositivas. | Cumple como declaración de herramientas: la segunda diapositiva identifica Codex para programar, revisar y documentar. Esto no sustituye la función de IA exigida dentro del prototipo. |
| Ficha inicial, Documento 02 | Se realiza a mano; el profesor conserva una fotografía. No se reescribe ni se entrega de nuevo. | No hay que generar una versión nueva ni añadirla como entrega obligatoria. |

El enunciado no exige una aplicación web, un APK, una memoria escrita o entregar el repositorio. Tampoco fija expresamente diez minutos ni cuatro intervenciones: son decisiones organizativas del guion actual. La guía de uso y las instrucciones de administrador son complementos útiles.

## Requisitos del trabajo y rúbrica

| Criterio | Peso | Evidencia actual | Qué falta acreditar o explicar |
| --- | ---: | --- | --- |
| Problema y decisiones | 25 % | El guion describe la dificultad de recoger preferencias y restricciones, la planificación mensual y la revisión inicial por un operario. Hace referencia al trabajo inicial en papel. | Exponer las cuatro alternativas trabajadas, los criterios de elección, qué se descartó y por qué. Separar datos de hipótesis y explicar la evolución desde la ficha inicial. |
| Solución y prototipo | 30 % | Se explica un recorrido completo: perfil → generación → revisión y aprobación → consulta → cambio de un plato futuro. Existe paquete nativo Windows. | Validar ese recorrido con el paquete definitivo y el VPS. Acreditar una función de IA concreta, útil y operativa: la documentación actual reconoce una generación local determinista y una llamada real pendiente. |
| Pruebas y mejora | 25 % | Existe un protocolo con tareas y una plantilla para P1 y P2. | Completar dos pruebas reales con personas externas, registrar observaciones concretas e implementar una mejora significativa directamente vinculada a ellas. El protocolo sigue marcado como planificado y sus registros están pendientes. |
| IA y defensa | 20 % | Se identifica el uso de Codex, la responsabilidad del grupo, la validación de las respuestas y el estado del adaptador del modelo. | Defender qué valor aporta la IA frente al funcionamiento sin ella, cuándo puede fallar, qué decisiones no se delegan y qué propuestas del asistente se modificaron o rechazaron. Preparar a todos los miembros para preguntas individuales sobre el conjunto. |

La obligación de generar cuatro alternativas corresponde a la sesión inicial. Deben recuperarse las que realmente se trabajaron, si existen registros o recuerdos del equipo; las alternativas elaboradas después deben identificarse como posteriores. No corresponde inventar opciones y atribuirlas a la sesión ni reescribir el Documento 02.

## Observaciones sobre los archivos actuales

### Paquete Windows y acceso

- `Easy_Eats_Windows.zip` pasa la comprobación CRC y contiene 13 entradas, incluida la estructura nativa con DLL y `data/`.
- La guía incluida dentro del ZIP coincide byte a byte con `GUIA_US_APP_WINDOWS.pdf` exterior.
- El binario `Easy_Eats/data/app.so` del ZIP contiene `http://localhost:8000`. Por tanto, el paquete actual no acredita el acceso al futuro VPS desde el ordenador del profesor.
- Cuando el equipo incorpore la dirección definitiva y compile, debe empaquetar toda la carpeta Release. Sustituir solamente `easyeats.exe` no actualiza el código Dart compilado en `data/app.so`.
- La cuenta documentada es `operario` / `demo1234`, coherente con la configuración predeterminada del backend. Falta comprobar que esas credenciales son las configuradas en el VPS.

Esta observación es interna: no requiere añadir instrucciones sobre la dirección de la API a los documentos del profesor. Se respeta la indicación de no modificar código.

### Guía de uso

`GUIA_US_APP_WINDOWS.pdf` y `ACCES_PROTOTIP.md` explican extracción completa, apertura de la aplicación, creación del cliente, configuración, generación, acceso de administrador, aprobación, regreso al cliente y cambio de un plato futuro. El acceso de administrador está suficientemente explicado para que el profesor lo pruebe una vez disponible el servicio definitivo.

El manual PDF tiene dos páginas. El límite de dos diapositivas se refiere al apoyo de la demostración, no a este manual.

### Presentación y guion oral

La presentación cumple el número máximo de diapositivas y está adaptada a Windows y servicio remoto. La segunda diapositiva declara pendientes la llamada real al modelo y las pruebas externas: refleja el estado actual, pero no acredita esos requisitos como completados.

El guion explica bien el uso de cliente y operario. Dedica menos espacio a alternativas, criterios de decisión, observaciones de personas externas y aprendizaje, que tienen un peso importante en la evaluación. Conviene redistribuir el contenido de las mismas dos diapositivas y del discurso cuando existan esas evidencias, sin ampliar el número de diapositivas.

El tiempo de diez minutos es una previsión y requiere ensayo con los cambios de cuenta y las acciones de la demostración. Repartir cuatro intervenciones no demuestra por sí mismo que todos puedan defender el proyecto completo.

### IA y pruebas

El backend selecciona `test` por defecto en `backend/app/config.py`; en ese modo utiliza el generador local. Existe un adaptador de modelo y una prueba con un proveedor simulado en `backend/tests/test_flow.py`. Eso acredita implementación y comprobaciones de contrato, pero no una generación real ni su utilidad en el recorrido presentado.

No se exige una marca o proveedor concreto. Sí se exige una función de IA específica y útil dentro del prototipo. El uso de un asistente para programar permite declarar herramientas, pero no basta para cubrir ese requisito funcional.

Las verificaciones técnicas de API, del ZIP o de las pantallas no equivalen a pruebas con dos personas externas. Las mejoras ya realizadas solo servirán como evidencia de este criterio si se puede explicar honestamente su relación directa con observaciones reales.

El protocolo interno todavía menciona LAN y web/Android; debe adaptarse al escenario Windows y API remota antes de utilizarlo. No consta como documento de entrega obligatorio.

## Prioridad antes de la entrega final

1. Validar el paquete definitivo desde un ordenador de evaluación: acceso al VPS, registro, perfil, generación, acceso de operario, aprobación, consulta y sustitución futura.
2. Incorporar y comprobar una función real de IA que aporte valor al recorrido; registrar su contribución y sus límites. No basta con cambiar etiquetas o afirmar una integración no validada.
3. Realizar las dos pruebas externas, conservar observaciones concretas y aplicar una mejora significativa justificada por ellas. Comprobar de nuevo la tarea afectada.
4. Completar el relato de alternativas, elección, evolución, hechos e hipótesis con información real del equipo.
5. Actualizar las dos diapositivas y el guion con los resultados reales y ensayar la defensa conjunta.

No hace falta producir más documentos formales para sustituir estos pendientes: hacen falta funcionamiento verificable, evidencias y una explicación defendible.

## Alcance de esta revisión

Se han contrastado el enunciado, la presentación, el guion oral, la guía de uso, el protocolo de pruebas y el paquete Windows. Se han comprobado el número de diapositivas, la integridad del ZIP, la coincidencia de la guía incluida y la referencia local del binario. No se ha accedido a un VPS ni se han realizado pruebas con participantes externos durante esta revisión.

No se ha cambiado código de la aplicación ni se han modificado los entregables revisados. Este informe es el único archivo creado para esta revisión.
