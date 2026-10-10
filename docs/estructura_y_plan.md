# Estructura y plan de implementación de Easy Eats

> Plan previo a la implementación. Para conocer el código y las funciones ya disponibles, consulta [README.md](../README.md).

Este documento fija la organización del prototipo **antes de añadir código de aplicación**. El comportamiento y las pantallas están en `docs/diseno_producto.md`.

## 1. Punto de partida y criterio de alcance

Ya existen un proyecto Flutter mínimo en `easyeats/` y un catálogo reproducible en `data/` con 125 platos. La API FastAPI y la persistencia de usuarios y menús todavía no existen. El enunciado pide un recorrido completo y una función concreta de IA, así que la construcción empezará por una ruta funcional extremo a extremo. Las funciones de producción quedan documentadas, pero no bloquearán esa ruta.

El archivo `flujo_aplicacion_menus.md` es un borrador previo. Cuando difiera de las decisiones posteriores del usuario, rige este diseño: Free recibe menús; Pro añade entrega; el usuario elige días y comidas; el menú mensual se genera en modo local de pruebas o en modo IA real; el operario revisa solo el primer menú de cada cliente; las sustituciones posteriores son responsabilidad del cliente. Los dos modos se especifican en `docs/modos_generacion.md`.

## 2. Árbol de proyecto

```text
easy-eats/
├── README.md                    visión y acceso a los documentos
├── data/                        catálogo SQLite, esquema y CSV editables (existente)
├── docs/
│   ├── diseno_producto.md       flujos, pantallas y diseño visual
│   ├── estructura_y_plan.md     este documento
│   ├── modos_generacion.md      generadores de prueba e IA, contrato y activación
│   ├── repaso_final.md          decisiones consolidadas y pendientes
│   └── protocolo_pruebas.md     guion y registro vacío para pruebas reales
├── backend/
│   ├── app/
│   │   ├── api/                rutas HTTP y contratos externos
│   │   ├── domain/             reglas de elegibilidad, calendario y estados
│   │   ├── services/           casos de uso: perfiles, menús, cambios y entrega
│   │   ├── integrations/       generador local y adaptadores de IA
│   │   └── storage/            SQLite de ejecución y acceso al catálogo
│   ├── migrations/             evolución del esquema de usuarios y menús
│   ├── tests/                  pruebas de reglas y recorridos de API
│   └── var/                    datos locales de ejecución, no versionados
└── easyeats/                   proyecto Flutter existente
    ├── lib/
    │   ├── app/                arranque, navegación y tema
    │   ├── core/               cliente HTTP, sesión y componentes comunes
    │   └── features/
    │       ├── auth/           acceso y rol
    │       ├── onboarding/     plan, calendario y perfil inicial
    │       ├── plans/          capacidades Free/Pro y cambios de plan
    │       ├── catalog/        búsqueda y detalle de platos
    │       ├── menu/           semana, próximo menú y sustituciones
    │       ├── feedback/       opiniones e historial
    │       ├── delivery/       experiencia Pro simulada
    │       ├── profile/        edición de restricciones y gustos
    │       └── operator/       primera revisión mensual
    └── test/                    pruebas de widgets y navegación crítica
```

Los directorios están creados como estructura vacía; el Flutter existente sigue en `lib/main.dart` hasta la primera fase de implementación. La separación por funciones evita acumular toda la app en ese archivo y permite explicar cada módulo en la defensa de la práctica.

## 3. Datos y propiedad de cada fichero SQLite

`data/catalog.sqlite` contiene ingredientes, alérgenos y platos. Es un catálogo **de lectura** para la API y se reconstruye desde los CSV; nunca guardará allí cuentas o menús. Las futuras bases `backend/var/app_test.sqlite` y `backend/var/app_ai.sqlite` guardarán el estado mutable de cada modo por separado. Esta separación evita que reconstruir el catálogo borre datos de los usuarios y que una aprobación de pruebas cuente como primera aprobación del modo IA.

| Grupo | Entidades previstas | Regla relevante |
| --- | --- | --- |
| Identidad | `users`, `sessions`, `roles` | Acceso separado de cliente y operario; cuentas ficticias para demo. |
| Servicio | `plan_memberships`, `delivery_addresses` | Un plan vigente por usuario; dirección solo para Pro. |
| Perfil | `profiles`, `weekly_slots`, `profile_allergens`, `excluded_ingredients`, `preferences` | Restricciones explícitas separadas de preferencias aprendidas. |
| Menús | `menu_cycles`, `menu_items`, `generation_attempts` | Un ciclo por usuario y mes; cada item se identifica por fecha + comida y referencia `recipes.code`; se guarda su origen `test` o `ai`. |
| Revisión | `initial_reviews` | Solo el primer ciclo exige aprobación del operario; se registra quién y cuándo. |
| Usuario | `swaps`, `feedback` | Sustitución con autor, plato anterior/nuevo y fecha; opinión ligada a plato y asignación. |
| Pro | `deliveries` | Estados simulados por semana, nunca pagos o reparto real. |

Los códigos de recetas e ingredientes deben ser estables y legibles. Las referencias entre las dos bases se comprobarán en servicios de API, ya que SQLite no garantiza claves foráneas entre archivos independientes. Cada ciclo guarda la versión o huella del catálogo con la que se generó, para detectar platos desactivados después.

## 4. Variables de entrada y variables derivadas

### Entradas explícitas

| Grupo | Variables |
| --- | --- |
| Cuenta | alias, credenciales de demostración, rol |
| Plan | Free/Pro, fecha de vigencia |
| Calendario | por cada día de lunes a domingo, conjunto de `desayuno`, `comida`, `cena`, `merienda` |
| Restricciones | dieta, códigos de alérgenos, códigos de ingredientes excluidos |
| Preferencias | ingredientes/tipos preferidos o poco deseados, tolerancia a repeticiones |
| Interacción | sustituciones, valoraciones, comentarios |
| Pro | dirección ficticia y observaciones opcionales |

### Valores calculados, nunca preguntados dos veces

| Variable | Cálculo o fuente | Uso |
| --- | --- | --- |
| `meal_slots_in_month` | Fechas del mes en `Europe/Madrid` × comidas elegidas para cada día de semana | Tamaño exacto de la respuesta que debe producir la IA. |
| `meals_per_week` | Suma de las comidas elegidas en los siete días | Resumen de configuración y estimación de cobertura. |
| `known_recipe_allergens` | Vista `recipe_allergens` del catálogo | Informar y filtrar la generación inicial. |
| `is_vegan`, `is_vegetarian` | Vista `recipe_dietary` del catálogo | Compatibilidad con la dieta declarada. |
| `eligible_recipe_codes(slot)` | Platos activos del momento requerido menos alérgenos modelados, ingredientes excluidos y dieta incompatible | Entrada permitida para la IA. |
| `candidate_count(slot)` | Tamaño del conjunto anterior | Detectar configuraciones imposibles antes de llamar a la IA. |
| `preference_score(recipe)` | Gustos explícitos + valoración histórica + penalización por repeticiones recientes | Priorizar y explicar propuestas; nunca anula restricciones. |
| `repeat_count(recipe, period)` | Apariciones del código en el mes o intervalo | Control de variedad. |
| `requires_initial_review` | Verdadero si el usuario no tiene una primera aprobación registrada | Enrutamiento a la cola del operario. |
| `week_start`, `week_end` | Semana ISO, de lunes a domingo, sobre la fecha local | Vista semanal y liberación de semanas. |
| `can_swap(item)` | Menú aprobado, fecha futura y autorización del usuario propietario | Mostrar sustitución sin paso de operario. |
| `needs_user_attention(item)` | Un cambio explícito de restricción vuelve incompatible una asignación futura según el catálogo | Aviso y sustitución por el usuario. |
| `can_view_delivery` | Plan Pro vigente | Navegación y estado simulado de entrega. |
| `feedback_available(item)` | Fecha del plato ya pasada o actual | Evitar opiniones anticipadas sobre platos no recibidos. |
| `generation_mode` | Configuración de arranque de FastAPI (`test` o `ai`) | Elegir generador y base mutable; informar a Flutter. |
| `generation_origin(cycle)` | Modo persistido al crear el ciclo | Distinguir menús de prueba de menús generados realmente con IA. |

`candidate_count` y `eligible_recipe_codes` se basan en datos de **demostración no verificados**. No pueden convertirse en un certificado de seguridad alimentaria. Los sulfitos, las formulaciones comerciales y la contaminación cruzada requieren datos reales que este catálogo no tiene.

## 5. Reglas de negocio y transiciones

1. El usuario puede elegir cualquier combinación de comidas por día, con mínimo una comida semanal. Una comida elegida crea un hueco por cada fecha correspondiente del mes.
2. El servidor filtra candidatos por restricciones declaradas antes de enviar opciones a la IA. Los gustos solo ordenan o puntúan candidatos. Si algún hueco no tiene opciones, se explica el conflicto y no se omite el hueco.
3. Un contrato único entrega los huecos y códigos candidatos al generador local determinista o al adaptador de IA. Ambos devuelven una lista de `{fecha, comida, recipe_code}`. La API comprueba cobertura exacta, códigos permitidos, estado activo y repeticiones. Una respuesta inválida se reintenta de forma controlada o queda como error visible; el modo IA nunca cambia silenciosamente a pruebas.
4. El primer ciclo va de `generando` a `pendiente_revision` y luego a `aprobado` por un operario. Un rechazo puede provocar corrección manual o nueva generación. Los ciclos posteriores van a `aprobado` cuando pasan las comprobaciones automáticas.
5. El cliente consulta la semana vigente y puede previsualizar la siguiente semana aprobada. Puede sustituir asignaciones futuras desde el catálogo; el evento guarda el plato anterior y el nuevo. Se muestran advertencias de ingredientes/alérgenos modelados y confirmación de responsabilidad, sin crear revisión del operario.
6. Las opiniones cambian pesos de preferencia para una generación posterior. No cambian automáticamente alergias, dieta ni ingredientes excluidos.
7. Si el perfil crítico cambia, se vuelven a evaluar las asignaciones futuras y se señalan al cliente. El usuario resuelve las sustituciones; el operario no recibe una tarea nueva.
8. Pro añade una entrega simulada por semana de menús aprobados. Free no tiene pantalla ni endpoint útil de entregas. Una transición de plan solo afecta a semanas futuras y debe quedar explícita en la interfaz.

### Casos límite previstos

Meses de 28 a 31 días; inicio de mes a mitad de semana; cambio horario; días sin comidas; cuatro comidas en un mismo día; pocas opciones tras filtrar; platos que se desactivan; IA fuera de servicio; cliente sin menú aún; primera revisión sin aprobar; edición de perfil mientras se genera; intentos de cambiar una fecha pasada o de otro usuario; cambio Free/Pro; desconexión del servidor LAN; dos cambios simultáneos sobre el mismo hueco. Las operaciones de sustitución usarán una revisión o versión del item para evitar sobrescribir otro cambio sin aviso.

## 6. Contrato API previsto

El detalle de campos se fijará al empezar la implementación. Las rutas se agrupan por tarea:

| Área | Operaciones previstas |
| --- | --- |
| Sesión | registro/acceso de demo, sesión actual, cierre |
| Perfil y plan | leer/actualizar perfil, calendario, restricciones, preferencias y plan |
| Catálogo | listar por momento de comida, buscar, filtrar, detalle por código |
| Menús | generar ciclo mensual, consultar estado, semana actual y siguiente |
| Sistema | consultar modo y disponibilidad de generación, de solo lectura |
| Operario | listar primeras revisiones, ver propuesta, corregir, regenerar, aprobar |
| Sustituciones | ver candidatos para un hueco, confirmar cambio futuro, historial |
| Opiniones | registrar/consultar valoración y comentario |
| Pro | consultar dirección y entregas simuladas |

La API será el único lugar que lee/escribe SQLite y llama al proveedor de IA. La clave de API vive en variables de entorno del servidor y nunca en Flutter. El modo `test` funciona sin clave; el modo `ai` requiere activación expresa y clave local, según `docs/modos_generacion.md`. Para la demo LAN, el cliente usará la dirección IP del equipo servidor; `localhost` no sirve desde Android. Se configurarán orígenes web permitidos y el modo de desarrollo de red necesarios para las pruebas, sin usar datos personales reales.

## 7. Orden de trabajo y criterios de salida

| Etapa | Entregable | Comprobación para avanzar |
| --- | --- | --- |
| 0. Diseño (actual) | Estructura de carpetas, reglas, pantallas y protocolo de prueba | Las decisiones del usuario y el recorrido completo están trazados. |
| 1. Base funcional | API de catálogo y perfil, cliente Flutter adaptable, cuentas de prueba | Web de escritorio y Android abren el mismo catálogo por LAN. |
| 2. Recorrido central | Calendario, filtro, generador local de pruebas, contrato del adaptador IA, primera revisión, semana del cliente | Un cliente nuevo termina el recorrido en modo de pruebas sin editar la base manualmente. |
| 3. Continuidad | Sustituciones, opiniones, preferencias futuras y siguiente ciclo | Un cambio del usuario persiste y no abre revisión de operario. |
| 4. Planes | Free/Pro, dirección y estados de entrega simulada | Free no muestra entrega; Pro sí; el menú funciona en ambos. |
| 5. Activación de IA | Configuración local de clave y modelo, prueba real del adaptador con el mismo contrato | Un menú mensual completo se genera en modo `ai` y muestra ese origen; depende de contar entonces con clave. |
| 6. Validación | Casos límite, prueba en web/Android por LAN, dos pruebas externas y una mejora observada | Evidencia real registrada, mejora repetida y defendible en la demo. |

Prioridad si hay poco tiempo: etapas 1-3 completas y demostrables antes de ampliar detalles visuales. La etapa 5 es imprescindible antes de presentar el prototipo como una solución con IA real; mientras no haya clave, solo estará verificado el modo de pruebas. Las pruebas externas no se inventarán ni se marcarán como realizadas hasta hacerlas. Quedan fuera del prototipo pagos, logística real, notificaciones push, cálculo nutricional y certificación de alérgenos.

## 8. Preparación de la entrega académica

El acceso al prototipo debe permitir ejecutar una tarea completa durante la demostración. El soporte de la demo tendrá como máximo dos diapositivas e indicará qué herramientas de IA se utilizaron y para qué. Se conservará la fotografía de la ficha inicial como evidencia de las primeras alternativas, sin reescribirla como si fuera un resultado posterior. La defensa explicará qué aporta la generación mensual por IA, qué comprueba la API y cómo se comporta la aplicación cuando la IA falla. Las dos pruebas externas y la mejora posterior se documentarán solo cuando hayan sucedido realmente.
