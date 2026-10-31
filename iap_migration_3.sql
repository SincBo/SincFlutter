-- ============================================================
-- Etapa 3 de Apple In-App Purchase: guardar a qué compra de Apple
-- corresponde cada suscripción / transacción.
-- Corre esto una vez en el SQL Editor de Supabase.
-- ============================================================

-- suscripcion: id "original" de Apple (el mismo para todas las renovaciones
-- de una misma compra). Sirve para que una compra de Apple no se pueda
-- reutilizar en otra cuenta de Sinc, y para las renovaciones (Etapa 4).
ALTER TABLE public.suscripcion
  ADD COLUMN IF NOT EXISTS apple_original_transaction_id text,
  ADD COLUMN IF NOT EXISTS apple_product_id text;

CREATE UNIQUE INDEX IF NOT EXISTS suscripcion_apple_original_tx_uidx
  ON public.suscripcion (apple_original_transaction_id)
  WHERE apple_original_transaction_id IS NOT NULL;

-- transaccion: id de cada cobro de Apple (uno por mes). Evita registrar dos
-- veces el mismo pago si la app o Apple reintentan.
ALTER TABLE public.transaccion
  ADD COLUMN IF NOT EXISTS apple_transaction_id text;

CREATE UNIQUE INDEX IF NOT EXISTS transaccion_apple_tx_uidx
  ON public.transaccion (apple_transaction_id)
  WHERE apple_transaction_id IS NOT NULL;
