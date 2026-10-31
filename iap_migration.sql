-- ============================================================
-- Etapa 1 de Apple In-App Purchase: columnas para guardar la
-- referencia al producto/grupo creados en App Store Connect.
-- Corre esto una vez en el SQL Editor de Supabase.
-- ============================================================

ALTER TABLE public.plan_suscripcion
  ADD COLUMN IF NOT EXISTS apple_subscription_group_id text,
  ADD COLUMN IF NOT EXISTS apple_product_id text,
  ADD COLUMN IF NOT EXISTS apple_status text; -- 'pending' | 'ready' | 'error'
