# Propuesta de frontend de Easy Eats

Diseño de frontend fijado para la primera versión, 10 de octubre de 2026. Reglas y medidas definitivas en [especificación final](decisiones_antes_del_desarrollo.md). Las pantallas Flutter y el tema están implementados y conectados a FastAPI; evidencia en [validación](validacion_desarrollo.md). La propuesta interactiva original se conserva como referencia visual.

## Dirección visual

Idea: «Tu semana, a tu manera». Easy Eats se siente como una agenda de comida personal: cálida, tranquila y fácil de consultar. El menú es el centro de la experiencia.

- Fondo crema `#F8F6F1`, texto y navegación verde profundo `#183D33`, superficies salvia `#D9E9DA` y acentos coral `#E7654E`.
- Las acciones rellenas usan coral más oscuro `#B94731` para mantener contraste con el texto claro.
- Títulos con serif editorial del sistema (Georgia con alternativas) y cuerpo sans nativo, como el tema actual. La primera versión acepta variación tipográfica entre plataformas.
- Espaciado de 8 px, tarjetas con radio de 20 px, controles con radio de 12 px y bordes discretos.
- Identidad tipográfica «easy eats.» e iconografía lineal consistente. La referencia visual a vajilla sirve como marca, sin representar platos reales.
- Los platos se presentan con nombre, momento de comida, dieta derivada e ingredientes. No se utilizan fotografías genéricas ni se muestran calorías, macros o puntuaciones de salud.
- Estados con texto e icono, foco de teclado visible, botones cómodos en móvil y adaptación a texto ampliado. La paleta incluye una correspondencia para tema oscuro.

## Navegación del cliente

Se simplifican Inicio y Semana en una pantalla principal: **Mi semana**. Evita repetir la misma información en dos destinos.

| Destino | Contenido y acción principal |
| --- | --- |
| Mi semana | Semana actual/próxima, días elegidos, comidas asignadas, detalle, cambio futuro y opinión sobre comidas actuales/pasadas. |
| Catálogo | Buscar platos y filtrar por momento de comida; detalle de ingredientes, dieta y alérgenos modelados. |
| Opiniones | Valoraciones anteriores, comentario y explicación de su efecto en futuras propuestas. |
| Perfil | Calendario, dieta, exclusiones, gustos y plan. |
| Entregas | Solo Pro: dirección ficticia y estados simulados por semana. |

Escritorio: navegación lateral y contenido ancho. Móvil: navegación inferior con Semana, Catálogo, Opiniones y Perfil; Entregas se abre desde Semana y Perfil en Pro. La barra inferior forma parte del flujo de contenido para evitar tapar acciones.

## Pantallas y recorridos

### Acceso y configuración

Bienvenida breve con «Crear mi menú» y «Ya tengo cuenta». Después del acceso, asistente de cinco pasos:

1. Plan: diferencias Free/Pro, sin precios inventados.
2. Calendario: selección independiente de desayuno, comida, cena y merienda para cada día; mínimo una comida semanal.
3. Restricciones: dieta, alérgenos declarados e ingredientes excluidos.
4. Gustos: favoritos y alimentos menos deseados, separados de las restricciones.
5. Resumen: configuración editable y dirección de demostración cuando sea Pro.

El perfil se conserva al retroceder. Cada paso se guardará en el borrador del servidor y el asistente retomará el último paso confirmado. El resumen incluye fecha de inicio editable y dirección ficticia Pro.

### Mi semana

- Cabecera editorial, intervalo de fechas y distintivo del origen real del menú.
- Selector «Esta semana / Próxima semana» y siete días visibles, con identificación de los días sin comidas.
- En la vista propuesta se selecciona un día y se muestran sus comidas como tarjetas. Es la misma interacción en móvil y escritorio.
- Cada tarjeta muestra momento, nombre completo, etiquetas derivadas y acceso al detalle.
- «Cambiar plato» aparece para fechas futuras en menús aprobados. «Opinar» aparece para fechas actuales/pasadas. Ambas acciones se mantienen separadas.
- El cambio abre un selector, después el detalle del candidato y una confirmación explícita. El resultado se refleja en la tarjeta y en un mensaje de estado.
- El cliente no tiene que interpretar el ciclo mensual interno para usar su semana.

### Detalle y sustitución

En escritorio se presenta como panel superpuesto; en móvil, como hoja inferior. Incluye ingredientes completos, alérgenos modelados, límites del catálogo y acción contextual. El selector ofrece únicamente candidatos compatibles con momento de comida, dieta, alérgenos declarados y exclusiones; el servidor los revalida al confirmar según el contrato API.

El prototipo permite seleccionar y confirmar un plato del catálogo de ejemplo. No verifica restricciones personalizadas ni certifica seguridad alimentaria.

### Opiniones

Dos respuestas claras: «Me gustó» y «No me gustó», más comentario opcional. El usuario entiende que la opinión influye en futuras propuestas. No se presentan comentarios como analizados por IA si ese comportamiento todavía no existe.

### Perfil y entregas

Perfil agrupa configuración y edición. Cambiar restricciones debe mostrar las asignaciones futuras afectadas cuando lo determine la API. Entregas usa una línea de estados y un distintivo permanente «Entrega simulada»; no incluye mapas, pagos ni tiempos de reparto ficticios.

### Operario

Aplicación con el mismo sistema visual y navegación propia: «Primeras revisiones» y «Catálogo». Lista de clientes pendientes a la izquierda, perfil y propuesta a la derecha. En móvil, lista y detalle consecutivos.

La acción dominante es «Aprobar primer menú». «Cambiar plato» y «Regenerar propuesta» son secundarias. La revisión debe permitir recorrer todas las semanas del mes antes de aprobar. Los usuarios ya aprobados salen de esta cola.

## Estados previstos

| Estado | Presentación |
| --- | --- |
| Perfil pendiente | Invitación a continuar el asistente. |
| Generando | Progreso sin porcentaje inventado y consulta posterior del estado. |
| Primera revisión pendiente | Explicación y estado visible; las asignaciones no se presentan como aprobadas. |
| Menú aprobado | Semana y acciones disponibles según fecha. |
| Sin candidatos | Conflicto concreto que permita revisar la configuración. |
| Fallo de IA | Error y reintento; conservar el menú aprobado anterior. |
| Sin conexión | Aviso, reintento y ninguna confirmación de guardado falsa. |
| Restricciones modificadas | Platos futuros afectados destacados cuando lo indique la API. |
| Sin comidas ese día | Estado vacío útil y enlace a calendario. |

## Organización propuesta para Flutter

Se conserva `app`, `core` y `features`. Se añade una carpeta compartida para componentes visuales, de modo que `core` concentre infraestructura.

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│       └── app_theme.dart      Paleta, tipografía y componentes ya centralizados
├── core/
│   ├── network/
│   ├── session/
│   ├── configuration/
│   └── errors/
├── shared/
│   ├── layouts/               Shell adaptable y contenedores
│   └── widgets/               Botones, badges y estados comunes
└── features/
    ├── auth/
    ├── onboarding/
    ├── plans/
    ├── catalog/
    ├── menu/
    ├── feedback/
    ├── delivery/
    ├── profile/
    └── operator/
```

Cada funcionalidad crece con `data/` para modelos y repositorios y `presentation/` para pantallas, estado y widgets propios. No se crean carpetas vacías sin una responsabilidad concreta. Los modelos del catálogo se comparten a través de esa funcionalidad; los componentes específicos de plato se reutilizan sin trasladarlos todos a `shared`.

Estado con controladores ChangeNotifier y ListenableBuilder, navegación go_router y repositorios inyectados. Menos de 600 px: barra inferior; 600-1023: rail; desde 1024: lateral de 240 px. Contenido máximo 1200 px. Modales y casos de carga/error se rigen por la especificación final, no por el estado local del prototipo.

Componentes principales: shell adaptable, selector de semana, selector de día, tarjeta de comida, detalle de plato, selector de sustitución, formulario de opinión, editor de calendario, estado de generación y ficha de primera revisión.

## Alcance de la propuesta interactiva

Incluye navegación del cliente, selección de semana y día, catálogo con búsqueda/filtros, detalles, sustituciones locales, opiniones, plan Free/Pro, calendario editable y recorrido ilustrativo de configuración. La vista de operario permite explorar un mes de ejemplo y aprobar su primera propuesta localmente.

Los controles de diseño permiten revisar cliente/operario, escritorio/móvil y estados del menú. Todo es demostrativo: no hay registro, autenticación, API, generación de IA, persistencia de negocio ni entregas reales. El prototipo no sustituye la implementación Flutter.

Orden propuesto de implementación: tema y shell; semana y catálogo; perfil y asistente; sustitución y opiniones; primeras revisiones; entregas Pro y estados de error. Las pantallas reciben estados y acciones mediante repositorios, para que las mismas vistas funcionen primero con datos de demostración y después con la API.

## Verificación de la propuesta

Se ha revisado la composición en navegador de escritorio y con un viewport de 320 px. En móviles pequeños, los días se distribuyen en dos filas; las comidas y el catálogo se apilan. La comprobación de controles en esa anchura no detectó desbordamiento horizontal.

Se comprobaron selección de día/semana, búsqueda por texto, detalle y confirmación de sustitución, registro de opinión, selección Free/Pro, el asistente de cinco pasos y la aprobación de primera revisión. Son comprobaciones del prototipo visual local; no son pruebas de la aplicación Flutter, de una API ni pruebas con personas externas.
