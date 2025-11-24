# Habilitar pg_trgm y crear índices en Supabase

Este documento muestra comandos SQL para habilitar la extensión `pg_trgm` y crear índices GIN trigram sobre columnas que vayas a buscar con `ilike '%query%'`.

Por qué: `ilike '%query%'` es fácil de usar pero lento en tablas grandes. `pg_trgm` permite acelerar búsquedas de substring mediante índices GIN/GIN_TRGM.

1) Conéctate a la SQL editor de Supabase (Database -> SQL editor) y ejecuta:

```sql
-- 1. Habilitar la extensión (si no está activa)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Crear índices trigram en las columnas que usarás para búsqueda
-- Usa lower(...) para habilitar búsquedas case-insensitive
CREATE INDEX IF NOT EXISTS idx_creadores_nombre_trgm ON public.creadores USING gin (lower(nombre_usuario) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_creadores_categoria_trgm ON public.creadores USING gin (lower(categoria) gin_trgm_ops);
```

Notas complementarias:
- `lower(...)` en el índice te permite usar consultas `WHERE lower(nombre_usuario) LIKE '%...%'` o `nombre_usuario ILIKE '%...%'` y aprovechar el índice.
- Si usas funciones RPC o vistas, considera crear índices sobre las columnas base o generar una columna `search_text` y crear un índice sobre ella.
- Recomendación: probar tiempos antes y después de crear el índice para confirmar la mejora.

Ejemplo de consulta que puede aprovechar el índice:

```sql
SELECT * FROM public.creadores
WHERE lower(nombre_usuario) LIKE lower('%José%')
LIMIT 20 OFFSET 0;
```

O desde Supabase JS/Dart con ilike:

```dart
// ilike con patrón %query% (asegúrate de usar lower en el índice o crear índice mencionado)
final results = await client
  .from('creadores')
  .select()
  .or('nombre_usuario.ilike.%$query%,categoria.ilike.%$query%')
  .limit(20)
  .range(0, 19);
```

Si necesitas, puedo añadir instrucciones para crear un índice combinado o usar `pg_catalog` para ver cardinalidad y impactos. También puedo proponer un plan para migraciones (si usas supabase migrations o SQL files).
