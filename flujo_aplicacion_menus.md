# Flujo funcional de la aplicación de menús personalizados

> **Nota de actualización (8 de octubre de 2026):** este documento conserva el planteamiento inicial. Las decisiones vigentes están en `docs/diseno_producto.md`, `docs/estructura_y_plan.md` y `docs/modos_generacion.md`: Free solo ofrece menús; Pro añade entrega; el cliente selecciona días y comidas; el menú mensual se genera en modo de pruebas o con IA real; el operario revisa únicamente el primer menú de cada cliente; las sustituciones posteriores corresponden al usuario.

## 1. Objetivo general

La aplicación tiene como objetivo gestionar la creación y entrega de menús personalizados para los clientes de un servicio de menús preparados.

El sistema debe permitir recoger las condiciones y preferencias de cada usuario, generar una planificación mensual adaptada a su perfil, facilitar la revisión del menú por parte de un operario de la empresa y entregar al cliente únicamente el menú correspondiente a cada semana.

El proceso no termina después de la primera planificación. La aplicación debe mantener un ciclo continuo en el que las preferencias del usuario se actualizan a partir de sus opiniones, solicitudes de cambio y comportamiento posterior. De este modo, las siguientes planificaciones pueden adaptarse progresivamente mejor a cada cliente.

---

## 2. Actores principales

### 2.1. Usuario o cliente

Es la persona que contrata el servicio de menús.

Sus principales acciones son:

- Crear una cuenta.
- Elegir un plan.
- Introducir la información necesaria para configurar su perfil.
- Definir restricciones y preferencias alimentarias.
- Recibir el menú correspondiente a cada semana.
- Revisar el menú si lo desea.
- Solicitar cambios para la semana siguiente.
- Dar opiniones sobre los platos recibidos.
- Modificar determinadas preferencias de su perfil.

El usuario no genera directamente el menú final ni tiene que intervenir en cada ciclo si no lo desea.

### 2.2. Operario de la empresa

Es la persona responsable de supervisar las propuestas generadas por el sistema.

Sus principales acciones son:

- Recibir nuevos usuarios pendientes de planificación.
- Consultar el perfil de cada usuario.
- Revisar el menú mensual propuesto por el sistema.
- Detectar posibles problemas o incoherencias.
- Modificar platos si es necesario.
- Validar el menú antes de que pueda ser entregado.
- Revisar solicitudes de cambios realizadas por los usuarios.
- Supervisar las nuevas propuestas generadas en ciclos posteriores.

La decisión final antes de entregar un menú al usuario corresponde al operario.

### 2.3. Sistema de generación y personalización

Es el componente encargado de procesar la información del usuario y crear propuestas de menú.

Puede estar formado por un algoritmo, una IA o una combinación de ambos.

Sus principales funciones son:

- Procesar el perfil del usuario.
- Filtrar platos incompatibles con restricciones obligatorias.
- Seleccionar o priorizar platos compatibles con las preferencias.
- Generar una propuesta de menú para aproximadamente un mes.
- Incorporar la información obtenida del feedback del usuario.
- Actualizar las preferencias aprendidas.
- Utilizar el historial para mejorar futuras propuestas.

---

## 3. Tipos de información del usuario

### 3.1. Datos generales

Durante el alta se pueden solicitar los datos necesarios para el funcionamiento del servicio.

Entre los parámetros contemplados inicialmente se encuentran:

- Edad.
- Género.
- Peso.
- Altura.
- Nivel de actividad física.
- Objetivo físico.

Estos datos solo deberían mantenerse en el prototipo si tienen una función real dentro de la generación o personalización del menú.

### 3.2. Restricciones obligatorias

Son condiciones que el sistema debe respetar siempre.

Por ejemplo:

- Alergias.
- Intolerancias.
- Restricciones alimentarias.
- Alimentos prohibidos.
- Tipo de dieta cuando actúe como restricción, como vegetariana o vegana.

Estas restricciones tienen prioridad sobre las preferencias.

Una preferencia aprendida nunca debe eliminar, ignorar o modificar automáticamente una restricción crítica.

### 3.3. Preferencias

Son condiciones que influyen en la personalización, pero que no tienen carácter obligatorio.

Por ejemplo:

- Alimentos favoritos.
- Alimentos que no gustan.
- Tipos de comida preferidos.
- Preferencia por determinados ingredientes.
- Preferencia por determinados estilos de platos.
- Opiniones sobre platos consumidos anteriormente.

Estas preferencias pueden evolucionar con el tiempo.

---

## 4. Flujo general de la aplicación

El flujo principal queda definido de la siguiente manera:

**Creación de cuenta → Selección de plan → Configuración del perfil → Alta del usuario → Generación del menú mensual → Revisión del operario → Validación → Entrega semanal → Revisión y feedback del usuario → Actualización de preferencias → Siguiente semana → Nuevo ciclo mensual**

Este proceso se repite continuamente mientras el usuario permanezca en el servicio.

---

## 5. Fase 1 — Creación de cuenta

El proceso comienza cuando una persona nueva entra en la aplicación.

El usuario crea una cuenta y pasa a formar parte del sistema.

En esta fase se deben recoger únicamente los datos necesarios para identificar al usuario y permitirle acceder posteriormente a su perfil y a sus menús.

Una vez creada la cuenta, el usuario continúa con la elección del servicio.

---

## 6. Fase 2 — Selección de plan

El usuario selecciona el plan que desea contratar.

El plan determina las condiciones generales del servicio que recibirá.

En el flujo actualmente definido, la selección del plan ocurre antes de completar el perfil alimentario.

El flujo sería:

**Crear cuenta → Elegir plan → Definir parámetros**

La definición detallada de los diferentes planes no forma parte todavía de lo acordado.

---

## 7. Fase 3 — Configuración inicial del perfil

Después de seleccionar el plan, el usuario completa su perfil.

Esta fase puede presentarse mediante varias pantallas consecutivas para evitar mostrar demasiadas preguntas al mismo tiempo.

### Paso 1. Datos generales

El usuario introduce los datos personales necesarios.

### Paso 2. Restricciones

El usuario indica:

- Alergias.
- Intolerancias.
- Alimentos prohibidos.
- Restricciones alimentarias.
- Dieta.

### Paso 3. Preferencias

El usuario puede indicar:

- Alimentos preferidos.
- Alimentos que no le gustan.
- Tipos de platos preferidos.
- Otras preferencias relacionadas con la comida.

### Paso 4. Resumen

Antes de finalizar, el sistema muestra un resumen del perfil configurado.

El usuario puede revisar la información y corregirla.

Una vez confirmado el perfil, el usuario pasa a estar disponible para el proceso de planificación.

---

## 8. Fase 4 — Nuevo usuario pendiente de planificación

Cuando el usuario termina el alta, el operario de la empresa recibe el nuevo cliente.

El panel del operario debe permitir identificar claramente los usuarios que todavía no disponen de una planificación.

Por ejemplo, pueden aparecer en un estado:

**Pendiente de generar menú**

El operario puede abrir el usuario y consultar:

- Datos relevantes.
- Plan contratado.
- Restricciones.
- Preferencias.
- Información adicional necesaria para la planificación.

En este punto se inicia la generación de la propuesta.

---

## 9. Fase 5 — Generación del menú mensual

El sistema genera una propuesta de menú para aproximadamente un mes.

Aunque el usuario recibe los menús semana a semana, internamente la empresa trabaja inicialmente con una planificación mensual.

Esto permite mantener una visión global y controlar aspectos como:

- Variedad.
- Repetición de platos.
- Distribución de los alimentos.
- Coherencia con las preferencias del usuario.
- Continuidad entre semanas.

### 9.1. Separación entre seguridad y personalización

El sistema debe distinguir dos etapas.

#### Etapa A — Filtrado obligatorio

Antes de personalizar el menú, deben eliminarse todos los platos que incumplan una restricción obligatoria.

Ejemplos:

- Un plato contiene un alérgeno del usuario.
- Un plato contiene un alimento prohibido.
- Un plato no cumple la dieta seleccionada.
- Un plato contiene un ingrediente incompatible con una intolerancia.

Esta fase debería funcionar mediante reglas claras y datos verificados.

No debe depender únicamente de una IA generativa.

#### Etapa B — Personalización

Después de obtener el conjunto de platos válidos, el sistema puede seleccionar y ordenar las opciones más adecuadas para el usuario.

Aquí puede intervenir una IA o un algoritmo de recomendación.

Puede tener en cuenta:

- Gustos.
- Historial.
- Opiniones anteriores.
- Alimentos preferidos.
- Alimentos rechazados anteriormente.
- Variedad.
- Repetición de platos.
- Perfil general del usuario.

El resultado es una propuesta de menú mensual.

---

## 10. Fase 6 — Revisión del operario

El menú generado no se entrega directamente al cliente.

Primero debe pasar por una revisión humana.

El operario recibe la propuesta mensual y puede analizarla.

Debe poder:

- Consultar todo el menú.
- Ver los platos asignados a cada semana.
- Consultar la información del usuario.
- Identificar las restricciones relevantes.
- Detectar problemas.
- Sustituir platos.
- Solicitar una nueva propuesta cuando sea necesario.

El sistema puede ayudar al operario, pero no sustituir su validación final.

---

## 11. Fase 7 — Validación del menú

Cuando el operario considera que la propuesta es correcta, valida el menú.

A partir de ese momento, la planificación mensual pasa a estar aprobada.

Posibles estados de una planificación:

- Borrador.
- Pendiente de revisión.
- Validada.
- En entrega.
- Finalizada.

El menú mensual validado sirve como base para las entregas semanales.

---

## 12. Fase 8 — Entrega semanal

Aunque se haya generado una planificación mensual, el usuario no recibe necesariamente todo el mes al mismo tiempo.

El menú se entrega semana a semana.

La entrega se realiza los lunes.

Cada lunes, el usuario recibe el menú correspondiente a esa semana.

La aplicación debe mostrar claramente qué platos corresponden a cada día.

---

## 13. Fase 9 — Revisión por parte del usuario

El usuario puede consultar el menú semanal recibido.

No es obligatorio que realice ninguna acción.

Si el menú es correcto, puede simplemente utilizar el servicio con normalidad.

Puede consultar, según el alcance final del prototipo:

- Nombre del plato.
- Día correspondiente.
- Ingredientes.
- Información relevante.
- Posibles etiquetas.
- Otra información asociada al plato.

---

## 14. Fase 10 — Solicitudes de cambios

El usuario puede pedir modificaciones.

Los cambios solicitados no están pensados principalmente para modificar el menú que ya está siendo entregado durante esa misma semana, sino para influir en la semana siguiente.

Ejemplos:

- No quiero volver a recibir este plato.
- Prefiero más platos con pasta.
- Este ingrediente no me gusta.
- Quiero menos platos de este tipo.
- Este plato me ha gustado mucho.
- Quiero sustituir determinados platos de la semana siguiente.

Las solicitudes pueden ser concretas o expresarse mediante texto libre.

---

## 15. Fase 11 — Feedback del usuario

El usuario puede proporcionar información sobre su experiencia después de recibir los platos.

El feedback puede ser explícito.

Por ejemplo:

- Me gusta.
- No me gusta.
- Valoración.
- Comentario.
- Solicitud de no repetir.
- Solicitud de recibir platos similares.

Esta información se guarda y pasa a formar parte del historial del usuario.

---

## 16. Fase 12 — Actualización de preferencias

Uno de los elementos principales del sistema es que el perfil del usuario no permanezca estático.

Las preferencias se van actualizando a partir de las opiniones posteriores.

Ejemplo:

```text
Estado inicial:
Pescado → preferencia neutral

Después de varias opiniones negativas:
Pescado → preferencia baja
```

Otro ejemplo:

```text
Estado inicial:
Pasta → preferencia normal

Después de varias valoraciones positivas:
Pasta → preferencia alta
```

Estas preferencias aprendidas se utilizarán posteriormente para generar mejores propuestas.

---

## 17. Restricciones que no deben aprenderse automáticamente

Es necesario separar claramente las preferencias adaptativas de las restricciones críticas.

El sistema puede aprender que un usuario prefiere o rechaza determinados alimentos.

Sin embargo, no debe modificar automáticamente elementos como:

- Alergias.
- Intolerancias.
- Restricciones médicas.
- Otras restricciones obligatorias.

Por ejemplo, una alergia no puede eliminarse porque el usuario no la haya mencionado durante varias semanas.

Las restricciones críticas deben modificarse mediante una acción explícita y controlada.

---

## 18. Fase 13 — Preparación de la semana siguiente

Las opiniones y solicitudes realizadas por el usuario pueden afectar a las siguientes semanas todavía no entregadas.

El sistema puede utilizar:

- Perfil actual.
- Restricciones.
- Preferencias iniciales.
- Preferencias aprendidas.
- Feedback.
- Solicitudes de cambio.

Con esta información se ajusta la planificación futura.

Dependiendo del diseño final, estos cambios pueden modificar la planificación mensual existente o generar propuestas de sustitución para determinadas comidas.

El operario mantiene la capacidad de revisar las modificaciones antes de su entrega.

---

## 19. Fase 14 — Nuevo ciclo mensual

Cuando finaliza el periodo planificado, se genera el menú del siguiente mes.

La nueva generación ya no parte únicamente de los datos introducidos durante el registro.

Utiliza:

**Perfil original + restricciones actuales + preferencias actuales + historial + feedback + cambios solicitados**

Esto permite que el sistema mejore progresivamente su conocimiento del usuario.

La nueva propuesta vuelve a pasar por el mismo proceso:

**Generación → Revisión del operario → Validación → Entrega semanal**

El proceso se repite mes a mes.

---

## 20. Ciclo completo

```text
USUARIO NUEVO
    │
    ▼
Crear cuenta
    │
    ▼
Elegir plan
    │
    ▼
Configurar perfil
    │
    ├── Datos generales
    ├── Restricciones
    └── Preferencias
    │
    ▼
Usuario pendiente de planificación
    │
    ▼
Filtrado de platos incompatibles
    │
    ▼
IA / algoritmo de personalización
    │
    ▼
Propuesta de menú mensual
    │
    ▼
Revisión del operario
    │
    ├── Modificar
    ├── Regenerar
    └── Validar
    │
    ▼
Menú mensual aprobado
    │
    ▼
Entrega de la semana
    │
    ▼
Usuario consulta el menú
    │
    ├───────────────┐
    │               │
Sin cambios      Feedback / cambios
    │               │
    │               ▼
    │        Actualizar preferencias
    │               │
    └───────┬───────┘
            │
            ▼
      Siguiente semana
            │
            ▼
        Fin de mes
            │
            ▼
Generar nuevo menú mensual
            │
            └──────────────► se repite el ciclo
```

---

## 21. Flujo específico del usuario

```text
Crear cuenta
    ↓
Elegir plan
    ↓
Configurar perfil
    ↓
Esperar validación del menú
    ↓
Recibir menú semanal
    ↓
Consultar menú
    ↓
Dar feedback o pedir cambios
    ↓
Recibir la siguiente semana
```

El usuario no necesita interactuar con los procesos internos de generación y validación.

---

## 22. Flujo específico del operario

```text
Recibir nuevo usuario
    ↓
Consultar perfil
    ↓
Generar propuesta mensual
    ↓
Revisar propuesta
    ↓
¿Es correcta?
   / \
 NO   SÍ
 ↓     ↓
Editar  Validar
o
regenerar
   \   /
    ↓
Menú aprobado
    ↓
Supervisar cambios y feedback
    ↓
Revisar futuras modificaciones
    ↓
Nuevo ciclo mensual
```

---

## 23. Papel de la IA

La IA no debería plantearse simplemente como un componente que decide qué puede o no comer una persona.

Su función principal es aportar valor en la personalización.

Puede utilizarse para:

- Priorizar platos según las preferencias.
- Interpretar el historial del usuario.
- Detectar patrones en sus valoraciones.
- Adaptar futuras recomendaciones.
- Proponer sustituciones.
- Interpretar peticiones escritas en lenguaje natural.
- Generar una planificación variada entre los platos previamente considerados válidos.

Por ejemplo, un usuario podría escribir:

> “Esta semana ha habido demasiado pescado y me han gustado especialmente los platos de pasta.”

El sistema podría interpretar esta opinión y transformarla en información estructurada como:

```text
Preferencia pescado: disminuir
Preferencia pasta: aumentar
```

Estas preferencias podrían tenerse en cuenta en la siguiente planificación.

---

## 24. Qué no debe delegarse completamente a la IA

Determinadas decisiones deben quedar fuera del control autónomo de la IA.

Principalmente:

- Validación de alergias.
- Validación de intolerancias.
- Cumplimiento de restricciones obligatorias.
- Modificación automática de restricciones críticas.
- Aprobación final de un menú antes de su entrega.

Por ello, el sistema se plantea como una combinación de:

**Reglas verificables + personalización automática + supervisión humana**

---

## 25. Principio de funcionamiento

> El sistema filtra primero qué platos son válidos para cada usuario, utiliza posteriormente una IA o algoritmo para construir una propuesta personalizada y finalmente exige la validación de un operario antes de entregar el menú. Las opiniones del usuario se incorporan progresivamente a su perfil para mejorar las planificaciones futuras.

---

## 26. Alcance del prototipo

Para la práctica no es necesario implementar completamente un sistema comercial real.

El prototipo puede centrarse en demostrar de principio a fin el flujo principal:

1. Crear un usuario.
2. Elegir un plan.
3. Configurar restricciones y preferencias.
4. Generar una propuesta de menú.
5. Mostrarla al operario.
6. Permitir que el operario la valide.
7. Mostrar al usuario su menú semanal.
8. Recoger una opinión o solicitud de cambio.
9. Mostrar cómo esa información modifica las preferencias utilizadas en una futura recomendación.

Este recorrido permite representar el funcionamiento esencial de todo el sistema sin tener que implementar todos los procesos de producción, logística o facturación de una empresa real.
