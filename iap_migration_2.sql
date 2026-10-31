-- ============================================================
-- Etapa 2 de Apple In-App Purchase: que la app reciba, junto con
-- cada plan, el producto de Apple (apple_product_id / apple_status).
-- Solo agrega 2 campos al JSON "planes" de obtener_creadores();
-- la firma de la función no cambia, así que nada más se rompe.
-- Corre esto una vez en el SQL Editor de Supabase.
-- ============================================================

CREATE OR REPLACE FUNCTION public.obtener_creadores()
RETURNS TABLE(id_usuario uuid, nombre_usuario text, email text, bio text, categoria text, planes json, publicaciones json)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $function$
  SELECT
    u.id_usuario,
    u.nombre_usuario,
    u.email,
    c.bio,
    cat.nombre AS categoria,

    (
      SELECT json_agg(
        json_build_object(
          'id_plan', p.id_plan,
          'nombre', p.nombre,
          'descripcion', p.descripcion,
          'precio', p.precio,
          'apple_product_id', p.apple_product_id,
          'apple_status', p.apple_status
        )
        ORDER BY p.precio
      )
      FROM plan_suscripcion p
      WHERE p.id_creador = c.id_creador
    ) AS planes,

    (
      SELECT json_agg(row_to_json(p))
      FROM (
        SELECT
          pub.id_publicacion,
          pub.titulo,
          pub.contenido,
          pub.es_publico,
          pub.fecha_publicacion,
          (
            SELECT COUNT(*)
            FROM me_gusta mg
            WHERE mg.id_publicacion = pub.id_publicacion
          ) AS cantidad_likes
        FROM publicacion pub
        WHERE pub.id_creador = c.id_creador
          AND pub.es_publico = true
        ORDER BY pub.fecha_publicacion DESC
      ) p
    ) AS publicaciones

  FROM creador c
  JOIN usuario u
      ON u.id_usuario = c.id_creador
  LEFT JOIN categoria cat
      ON c.id_categoria = cat.id_categoria;
$function$;
