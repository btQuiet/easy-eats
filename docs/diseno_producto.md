# Easy Eats: diseño del producto

Estado: diseño previo a la implementación. Decisiones vigentes del equipo y del usuario, 8 de octubre de 2026.

## 1. Objetivo y alcance

Easy Eats permite configurar qué días y qué comidas quiere una persona, crearle un menú mensual a partir de un catálogo de platos y mostrarle cada semana su propuesta. La arquitectura admite un generador local para pruebas y otro conectado a una IA real. La persona puede consultar los platos, opinar y sustituir por sí misma platos futuros. El plan Free ofrece menús; el plan Pro añade la experiencia de entrega a domicilio. Para el prototipo, la entrega se representa con estados simulados, sin cobros ni logística real.

En cada entorno de datos, la primera propuesta mensual de **cada usuario** requiere revisión y aprobación del operario. Ese operario puede cambiar platos o pedir una nueva propuesta inicial. Las sustituciones realizadas después por el usuario no pasan por el operario. Los ciclos mensuales posteriores usan las preferencias acumuladas y se publican sin una nueva revisión ordinaria. Esta interpretación concreta la instrucción «solo revisará el primer menú generado por la IA» y mantiene el mismo recorrido en el modo de pruebas.

Objetivo de la demostración: completar un recorrido real en la app, desde configurar un usuario de prueba hasta obtener una semana aprobada, sustituir un plato futuro y registrar una opinión que influya en el siguiente ciclo. Antes de afirmar que la función de IA está integrada, el recorrido se repetirá con el modo IA activo y una generación mensual real; una salida del modo de pruebas no se presentará como IA.

## 2. Superficies y actores

| Actor | Puede hacer | No necesita hacer |
| --- | --- | --- |
| Visitante | Ver la propuesta del servicio, crear cuenta o entrar en una cuenta de prueba. | Ver menús privados. |
| Cliente Free | Configurar perfil y calendario, consultar menú y catálogo, sustituir platos futuros, valorar platos y gestionar sus preferencias. | Ver entrega a domicilio. |
| Cliente Pro | Todo lo anterior y consultar su dirección y el estado simulado de sus entregas. | Gestionar logística o pagar en el prototipo. |
| Operario | Ver la cola de primeros menús, perfil relevante, propuesta mensual; cambiar, regenerar y aprobar esa primera propuesta. | Aprobar sustituciones del usuario o cada ciclo mensual posterior. |

La interfaz Flutter será adaptable a **web de escritorio y Android**. El proyecto Flutter ya contiene plataforma Windows; la misma interfaz debe poder adaptarse a escritorio nativo, aunque la validación prioritaria será web y Android conectados por LAN.

## 3. Recorridos principales

### Cliente nuevo

1. Bienvenida y acceso con cuenta de demostración o registro local.
2. Elección Free/Pro, con diferencias explicadas sin precios ficticios.
3. Selección de días de la semana y de las comidas de cada día. Se ofrecen desayuno, comida, cena y merienda; puede dejar días vacíos, pero debe seleccionar al menos una comida semanal.
4. Perfil alimentario: dieta, alérgenos declarados, ingredientes que excluye y gustos. Se muestran los límites del catálogo demostrativo.
5. Si elige Pro, dirección de prueba y datos mínimos para representar la entrega.
6. Resumen editable: días, comidas, restricciones y plan.
7. Generación mensual con el modo activo y candidatos previamente filtrados. La propuesta pasa a «pendiente de primera revisión»; se ve si el origen es de pruebas o IA.
8. El operario revisa y aprueba. El cliente ve su semana actual y la próxima semana editable.

### Cliente habitual

- En «Mi semana» ve los días y comidas elegidos, y abre el detalle de un plato con ingredientes, alérgenos modelados y etiquetas de dieta.
- Puede abrir «Próxima semana», seleccionar una comida futura, buscar en el catálogo y confirmar otro plato. La sustitución se guarda directamente con autor y fecha; no se crea tarea para el operario.
- Puede valorar con «me gusta / no me gusta» y comentario opcional. El cambio de preferencias afecta a nuevas propuestas, sin convertir una opinión en una alergia o exclusión obligatoria.
- Puede editar su configuración. Un cambio crítico en alergias, dieta o ingredientes excluidos vuelve a comprobar las asignaciones futuras y muestra las que requieran su atención.

### Operario

- Entra a «Primeras revisiones», abre un cliente y ve la planificación mensual agrupada por semanas, más las restricciones declaradas y el origen demostrativo de los datos.
- Corrige un plato de la propuesta o pide regenerarla y, cuando esté lista, la aprueba una vez. Los clientes que ya tuvieron su primera aprobación dejan de aparecer en esta cola.

## 4. Información que se solicita

| Momento | Campo | Uso real en el prototipo |
| --- | --- | --- |
| Cuenta | Alias y credenciales de prueba | Acceso y separación de perfiles. No se necesita nombre legal. |
| Plan | Free o Pro | Habilita o esconde las vistas de entrega y exige dirección solo para Pro. |
| Calendario | Comidas elegidas por día de lunes a domingo | Crea exactamente los huecos que debe llenar el menú mensual. |
| Restricciones | Dieta omnívora, vegetariana o vegana; alérgenos de la UE; ingredientes excluidos | Filtrado previo de candidatos para la generación. |
| Preferencias | Ingredientes favoritos o evitados por gusto; tipos de plato preferidos; repetición tolerada | Orden y variedad de propuestas, sin tratarse como prohibiciones. |
| Pro | Dirección ficticia y observación de entrega opcional | Vista de entrega simulada. |
| Después del menú | Valoración y comentario | Histórico y prioridades para el mes siguiente. |

No se pedirán género, edad, peso, altura, actividad ni objetivo físico en esta fase. El catálogo carece de cantidades y valores nutricionales, así que esos datos no permitirían calcular un plan nutricional defendible y ampliarían innecesariamente la recogida de información personal. Si se añaden fichas nutricionales verificadas más adelante, se puede replantear esta decisión.

## 5. Navegación y pantallas

| Pantalla | Cliente | Operario | Estado principal |
| --- | --- | --- | --- |
| Bienvenida / acceso | Sí | Sí | Entrar, crear cuenta o usar perfiles de prueba. |
| Elección de plan | Sí | No | Free y Pro con capacidades concretas. |
| Asistente de perfil | Sí | No | Calendario, restricciones, preferencias, entrega Pro, resumen. |
| Inicio | Sí | No | Semana actual, estado de planificación, acceso rápido a próxima semana. |
| Semana | Sí | Lectura en revisión | Tarjetas por día y comida seleccionada. |
| Catálogo / detalle | Sí | Sí | Búsqueda y filtros por momento, ingredientes y dieta; fichas con advertencia de datos demo. |
| Selector de sustitución | Sí | No | Opciones disponibles, detalle y confirmación. |
| Opiniones | Sí | No | Valoraciones propias y comentario opcional. |
| Perfil y calendario | Sí | Consulta | Editar datos y ver efecto de cambios. |
| Entregas | Solo Pro | No | Dirección y estado simulado de cada semana. |
| Cola de revisión | No | Sí | Solo primeros menús pendientes. |
| Revisión mensual | No | Sí | Comparar semanas, sustituir, regenerar, aprobar. |

### Comportamiento adaptable

En escritorio: barra lateral con navegación, resumen visible y calendario semanal ancho; el operario usa lista de clientes y detalle en dos columnas. En Android: barra inferior para Inicio, Semana, Catálogo y Perfil; los días se recorren como tarjetas verticales o pestañas desplazables, y las acciones de sustitución se abren como hoja inferior. Toda acción principal debe poder completarse con teclado en web y con controles táctiles de tamaño cómodo en móvil.

### Dirección visual

- Personalidad: cercana y ordenada, con protagonismo de la comida y de las decisiones del usuario.
- Fondo crema claro `#F8F6F1`, verde profundo `#183D33` para navegación y texto destacado, coral `#E7654E` para acciones principales, verde salvia `#D9E9DA` para superficies suaves, texto oscuro `#22302C`.
- Tipografía sans del sistema; jerarquía clara de título, subtítulo, fecha y plato. Espaciado base de 8 px y bordes redondeados moderados.
- Una tarjeta muestra primero **día + comida + nombre del plato**; después ingredientes y etiquetas. «Cambiar plato» y «Opinar» son acciones separadas.
- Ningún color comunica por sí solo una alergia, error o estado: se acompaña de texto e icono. Contraste y foco visibles, tamaños de texto escalables y etiquetas accesibles.
- Las imágenes de platos son opcionales. El catálogo actual no incluye fotografías verificadas; se priorizan tarjetas tipográficas y pequeños iconos antes que fotos genéricas que puedan representar mal el plato.

### Boceto de composición

```text
ESCRITORIO                              ANDROID
┌────────────┬───────────────────────┐   ┌───────────────────────┐
│ Easy Eats  │ Mi semana · 5-11 oct. │   │ Mi semana · 5-11 oct. │
│ Inicio     │ L  M  X  J  V  S  D   │   │ [ L ] M  X  J ...     │
│ Semana     │                       │   │                       │
│ Catálogo   │ [Comida] [Cena]       │   │ Comida · Arroz...     │
│ Perfil     │ nombre + etiquetas    │   │ ingredientes ...      │
│ Entregas*  │                       │   │ [Detalle] [Opinar]    │
└────────────┴───────────────────────┘   │ Inicio Semana ...     │
                                       └───────────────────────┘
* Solo Pro.
```

## 6. Estados y mensajes que el diseño debe contemplar

- Sin perfil terminado: continuar el asistente desde el último paso.
- Sin comidas elegidas: explicar que hace falta al menos una para crear el menú.
- Modo de pruebas activo: distintivo visible «Generado sin IA» en menú y revisión. En modo IA, distintivo «IA activa» y estado real de la generación.
- Generación en curso: progreso comprensible y posibilidad de volver sin perder la configuración.
- Primer menú pendiente: cliente ve un estado claro, no una semana incompleta.
- Catálogo sin candidatos para una restricción: explicar qué combinación deja cero opciones; nunca retirar una restricción obligatoria en silencio.
- IA no disponible, respuesta incompleta o códigos desconocidos: guardar error, permitir reintento y conservar el último menú aprobado si existe.
- Semana todavía no publicada: mostrar vista previa de la siguiente semana si el plan está aprobado; limitar las sustituciones a fechas futuras.
- Cambio de restricción que afecta platos futuros: destacar asignaciones afectadas para que el usuario las sustituya.
- Catálogo de prueba: cada detalle evita expresiones como «apto para alérgicos» o «sin trazas». Solo indica ingredientes y alérgenos **modelados**; el catálogo no certifica formulaciones reales.
- Pro sin dirección de prueba: pedirla antes de crear el estado de entrega. Free no verá controles de entrega.
- Sin conexión LAN: mensaje de reconexión y acción de reintento, sin simular éxito.

## 7. Límites de la demostración

No habrá pagos, rutas de reparto, notificaciones push reales ni recomendaciones médicas. La entrega Pro será una simulación visible y coherente. Las pruebas con dos personas externas y la mejora resultante se documentarán con observaciones reales; el plan para realizarlas está en `docs/protocolo_pruebas.md`.
