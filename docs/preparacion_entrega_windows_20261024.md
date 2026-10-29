# Preparación de la entrega Windows · 24/10/2026

Documento interno del equipo. El material destinado al profesor está en `entrega_practica1/`.

## Archivos preparados

| Archivo | Contenido |
| --- | --- |
| `Easy_Eats_Windows.zip` | Carpeta nativa Windows x64 completa: ejecutable, DLL de Flutter y `data/`, más instrucciones iniciales y guía PDF. |
| `GUIA_US_APP_WINDOWS.pdf` | Dos páginas con apertura, cuenta de cliente, menú, cuenta de administrador, aprobación y ayuda. |
| `ACCES_PROTOTIP.md` | Versión editable de las instrucciones de uso. |
| `Soporte_demo_Easy_Eats.pptx` | Dos diapositivas adaptadas a app Windows y servicio remoto. Se conserva el diseño y se sustituye la captura antigua por instrucciones de primer acceso. |
| `Guio_presentacio_10_min_4_persones.md` | Guion de cuatro intervenciones con demostración desde el ejecutable y cambio de cliente a operario. |

El profesor no recibe un backend que tenga que arrancar, una web ni herramientas de desarrollo. La documentación de uso asume el servicio remoto ya preparado por el equipo. No contiene instrucciones para configurar una URL, una IP ni un servidor local.

Las credenciales de evaluación documentadas son `operario` / `demo1234`, coherentes con la configuración predeterminada del backend actual. Deben coincidir con las que se establezcan en el VPS; no se ha accedido al VPS ni comprobado sus cuentas.

## Verificación realizada

- ZIP íntegro: CRC correcto, 13 entradas, 12.465.159 bytes en esta revisión. Se compararon los hashes de los archivos nativos empaquetados con la carpeta Release.
- Arquitectura del ejecutable: Windows x64. Se incluye toda la carpeta Release y se explica el requisito de Visual C++ si falta el runtime en el equipo receptor.
- PDF: dos páginas, contenido extraído y ambas páginas renderizadas e inspeccionadas. Contiene credenciales y recorrido de administrador.
- PowerPoint: dos diapositivas, estructura válida, fuentes Arial conservadas y validación de geometría sin incidencias. Ambas diapositivas renderizadas e inspeccionadas. No se ha afirmado una revisión con Microsoft PowerPoint.
- Sin referencias a navegación web o arranque local en los documentos de uso y guion actualizados.
- La revisión previa del ZIP anterior verificó 15 peticiones API y acceso, consulta semanal y detalle en navegador sobre una copia aislada. Estas comprobaciones son técnicas; no equivalen a pruebas con personas ni validan el nuevo VPS.

## Antes de enviar el paquete definitivo

El usuario ha indicado que la URL remota irá incorporada en el ejecutable y ha pedido no modificar el código. Se ha respetado esa instrucción y se ha empaquetado el Release disponible. Ese binario todavía contiene la referencia local `http://localhost:8000`; por tanto, este ZIP no acredita una conexión funcional al futuro VPS.

Cuando el equipo incorpore la URL definitiva y genere su Release, debe sustituir el contenido del ZIP por esa compilación y volver a verificar el recorrido real contra el VPS. No basta con sustituir solo `easyeats.exe`: el código Dart compilado de Release también está en `data/app.so`. El helper interno `easyeats/build/revision_entrega_20261024/package_windows.py` permite reconstruir el ZIP desde la carpeta Release actual, sin cambiar el código.

Comprobar también que la cuenta de operario funciona con las credenciales de la guía. Si se cambian en el VPS, actualizar la guía, el PDF, las instrucciones incluidas en el ZIP y el guion antes de enviarlos.

El enunciado exige una función de IA concreta y útil, dos pruebas con personas externas y una mejora derivada. La documentación actual mantiene pendientes la validación real del adaptador y las pruebas externas. No se han inventado observaciones ni resultados.

## Material anterior

El paquete web antiguo y las versiones originales de los documentos se conservan en `easyeats/build/revision_entrega_20261024/anteriores/`, fuera de la carpeta de entrega. No se han recuperado archivos descartados en Git ni modificado el código de la app en esta preparación.
