# Catálogo de platos de Easy Eats

`catalog.sqlite` es una base de datos SQLite lista para consultar desde FastAPI. Contiene **125 platos de ejemplo**, **94 ingredientes** y los **14 grupos de alérgenos de declaración obligatoria en la UE**. Los platos son propuestas originales para el prototipo; no proceden de una cocina, proveedor ni ficha técnica validada.

## Estructura

| Tabla o vista | Contenido |
| --- | --- |
| `recipes` | Platos con código estable, nombre, categoría, cocina y estado de validación. |
| `ingredients` | Ingredientes reutilizables y su origen vegetal o animal. |
| `recipe_ingredients` | Ingredientes asociados a cada plato y orden de presentación. |
| `meal_slots`, `recipe_meal_slots` | Desayuno, comida, cena y merienda; un plato puede pertenecer a varios momentos. |
| `allergens`, `ingredient_allergens` | Los 14 grupos y su asociación con los ingredientes modelados. |
| `recipe_allergens` | Vista que deduce los alérgenos conocidos de cada plato. |
| `recipe_dietary` | Vista que deduce si el plato es vegano o vegetariano a partir de sus ingredientes. |
| `catalog_info` | Procedencia y estado general del catálogo. |

Las relaciones usan claves foráneas. Para el intercambio entre la app, la API y la IA, conviene usar `recipes.code` y `ingredients.code`, que se mantienen estables al reconstruir el fichero. Los IDs numéricos son internos de SQLite.

## Reconstruir el catálogo

Los CSV en este directorio son la fuente editable. Tras cambiar un plato o ingrediente:

```powershell
python data/build_catalog.py
```

El script comprueba referencias, duplicados, cobertura de momentos de comida, representación de los 14 grupos y la integridad de SQLite antes de sustituir `catalog.sqlite`. Solo usa la biblioteca estándar de Python.

## Consultas de ejemplo

Platos de cena veganos sin **alérgenos modelados** de gluten o leche:

```sql
SELECT r.code, r.name_es
FROM recipes AS r
JOIN recipe_meal_slots AS rms ON rms.recipe_id = r.id
JOIN recipe_dietary AS rd ON rd.recipe_id = r.id
WHERE r.is_active = 1
  AND rms.meal_slot_code = 'cena'
  AND rd.is_vegan = 1
  AND NOT EXISTS (
      SELECT 1 FROM recipe_allergens AS ra
      WHERE ra.recipe_id = r.id
        AND ra.allergen_code IN ('gluten', 'leche')
  )
ORDER BY r.name_es;
```

Para excluir un ingrediente concreto del perfil, se puede añadir otro `NOT EXISTS` sobre `recipe_ingredients` unido a `ingredients.code`. La IA puede recibir los códigos de los platos ya filtrados y devolver solo códigos de ese conjunto; la API debe comprobar que los códigos existen antes de guardar un menú.

## Alcance de los datos

Todos los platos se crean con `validation_status = 'demo_unverified'`. Cada fila describe un **concepto de plato**, no una receta completa: no hay cantidades, porciones, valores nutricionales, método de elaboración ni fichas de proveedor. Las etiquetas vegano/vegetariano solo reflejan los ingredientes enumerados.

La vista de alérgenos indica **presencia según los ingredientes modelados**. Una ausencia no demuestra que un plato real esté libre de ese alérgeno: faltan formulaciones comerciales, trazas y contaminación cruzada. Para servir comida, especialmente a personas con alergias, hay que verificar ingredientes y procesos reales. En el caso de sulfitos, el umbral legal se aplica a la concentración en el producto listo para consumo, algo que este catálogo no mide.

Referencia para los 14 grupos: [Comisión Europea, información sobre alergias alimentarias](https://food.ec.europa.eu/food-safety/campaign-2026/allergies_en) y [anexo II del Reglamento (UE) 1169/2011](https://eur-lex.europa.eu/legal-content/ES/ALL/?uri=CELEX%3A32011R1169).
