# Easy Eats: diseño del producto

Diseño cerrado para la primera versión, 10 de octubre de 2026. Reglas detalladas en [especificación final](decisiones_antes_del_desarrollo.md); pantallas en [frontend](propuesta_frontend.md). No describe funciones ya implementadas.

## Objetivo y alcance

Configurar días y comidas, generar una planificación mensual desde el catálogo y consultar cada semana. Personalización por restricciones y gustos, con un generador local verificable y un adaptador de IA. Primera revisión por operario; sustituciones posteriores por el cliente.

Prototipo académico en web de escritorio y Android por LAN. Free ofrece menús, catálogo, sustituciones y opiniones. Pro añade una dirección ficticia y entregas simuladas. No incluye pagos, reparto real, notificaciones push, cálculo nutricional ni datos personales reales.

## Actores

| Actor | Responsabilidad |
| --- | --- |
| Visitante | Bienvenida, registro y acceso. |
| Cliente | Perfil, calendario, menú aprobado, cambio futuro y opinión. |
| Cliente Pro | Además, dirección y consulta de entrega simulada. |
| Operario | Primera propuesta: consultar perfil, corregir, regenerar y aprobar. |

El operario no tramita sustituciones ni revisa los ciclos siguientes. El servidor comprueba rol, propiedad y capacidades.

## Recorrido del cliente

1. Registrar alias y contraseña o acceder; el rol no se elige en la interfaz.
2. Completar cinco pasos: Plan, Calendario, Restricciones, Gustos y Resumen.
3. En Resumen, confirmar fecha de inicio y dirección si Pro.
4. Guardar perfil y solicitar generación. El modo activo se informa claramente.
5. Esperar la primera revisión; todavía no se presentan platos como aprobados.
6. Consultar Mi semana y Próxima semana cuando corresponda.
7. Cambiar un plato futuro entre candidatos compatibles y confirmar.
8. Opinar sobre una comida de fecha actual/pasada; el efecto se aplica a nuevas generaciones.
9. Editar perfil con información de efecto inmediato o mes efectivo.

Cada paso guarda borrador en servidor. La opinión no altera restricciones. Una edición del calendario no borra menús publicados.

## Recorrido del operario

Cola exclusiva de primeras propuestas válidas pendientes. Vista del perfil actual y de los datos utilizados al generar, mes agrupado por semanas, corrección, regeneración y aprobación versionada.

Si los inputs cambiaron, se regenera antes de aprobar. Si el mes venció, se inicia el siguiente primer ciclo; no se registra una aprobación vacía. Tras aprobar, el cliente deja de estar en esta cola.

## Navegación y presentación

Cliente: Mi semana, Catálogo, Opiniones y Perfil. Entregas aparece para Pro en la navegación de escritorio y desde Semana/Perfil en móvil. Operario: Primeras revisiones y Catálogo.

Móvil con barra inferior; anchura intermedia con rail; escritorio con lateral. La composición, medidas, modales y accesibilidad están fijados en la sección 9 de la especificación final.

Paleta crema, verde bosque, salvia y coral; títulos serif y cuerpo sans del sistema. El archivo `easyeats/lib/app/theme/app_theme.dart` ya implementa los temas. Se usan tarjetas tipográficas e iconos, sin fotografías genéricas ni valores nutricionales inventados.

## Datos y estados

Se solicitan alias, calendario, dieta, alérgenos declarados, ingredientes excluidos, gustos y tolerancia a repetición. Dirección ficticia solo para Pro. No se solicitan edad, género, peso, altura o actividad.

Se distinguen carga, borrador, generación, primera revisión pendiente, aprobado, incompatible, vacío y error. Estado del intento separado del ciclo; una caída de IA preserva lo aprobado. Sin conexión, lectura de lo ya cargado y formularios en memoria sin confirmar guardados.

El catálogo describe ingredientes y alérgenos modelados, no certifica ausencia de trazas ni seguridad alimentaria. La presentación conserva ese alcance.

## Validación del producto

Una cuenta completa la ruta hasta semana aprobada, sustitución y opinión persistente. El siguiente ciclo usa las preferencias y no crea revisión ordinaria. Validar roles, fechas, mes parcial, restricciones, concurrencia, red y fallo de IA.

Dos personas externas, una en Android y otra en web de escritorio, prueban el recorrido según [protocolo](protocolo_pruebas.md). Sus observaciones y la mejora se registran cuando se realicen.
