
-- ================================================================
-- MODULE COMPTABILITÉ - SYSCOHADA Dynamique + Paiements Structurés
-- ================================================================

-- 1) TABLE payment_categories (catégories de paiement niveau 1)
CREATE TABLE IF NOT EXISTS public.payment_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  -- Champs requis pour cette catégorie (JSON)
  required_fields JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Trigger updated_at
CREATE TRIGGER update_payment_categories_updated_at
  BEFORE UPDATE ON public.payment_categories
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- RLS pour payment_categories
ALTER TABLE public.payment_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Tous voient les catégories actives"
  ON public.payment_categories
  FOR SELECT
  USING (is_active = true OR is_admin(auth.uid()));

CREATE POLICY "Admin peut gérer catégories paiement"
  ON public.payment_categories
  FOR ALL
  USING (is_admin(auth.uid()))
  WITH CHECK (is_admin(auth.uid()));

-- 2) Ajouter category_id à payment_methods
ALTER TABLE public.payment_methods 
  ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES public.payment_categories(id);

ALTER TABLE public.payment_methods 
  ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- 3) Insérer les catégories par défaut
INSERT INTO public.payment_categories (code, label, sort_order, required_fields) VALUES
  ('mobile_money', 'Mobile Money', 1, '["transaction_id"]'::jsonb),
  ('banque', 'Virement Bancaire', 2, '["reference_virement"]'::jsonb),
  ('cheque', 'Chèque', 3, '["numero_cheque", "banque_emetteur"]'::jsonb),
  ('especes', 'Espèces', 4, '["caisse"]'::jsonb),
  ('autre', 'Autre', 5, '[]'::jsonb)
ON CONFLICT (code) DO NOTHING;

-- 4) Insérer les méthodes de paiement par catégorie
-- D'abord récupérer les IDs des catégories
DO $$
DECLARE
  cat_mobile UUID;
  cat_banque UUID;
  cat_cheque UUID;
  cat_especes UUID;
  cat_autre UUID;
BEGIN
  SELECT id INTO cat_mobile FROM public.payment_categories WHERE code = 'mobile_money';
  SELECT id INTO cat_banque FROM public.payment_categories WHERE code = 'banque';
  SELECT id INTO cat_cheque FROM public.payment_categories WHERE code = 'cheque';
  SELECT id INTO cat_especes FROM public.payment_categories WHERE code = 'especes';
  SELECT id INTO cat_autre FROM public.payment_categories WHERE code = 'autre';

  -- Mobile Money
  INSERT INTO public.payment_methods (code, label, category_id, sort_order, is_active) VALUES
    ('wave', 'Wave', cat_mobile, 1, true),
    ('orange_money', 'Orange Money', cat_mobile, 2, true),
    ('mtn_money', 'MTN Money', cat_mobile, 3, true),
    ('moov_money', 'Moov Money', cat_mobile, 4, true),
    ('djamo', 'Djamo', cat_mobile, 5, true)
  ON CONFLICT (code) DO UPDATE SET category_id = EXCLUDED.category_id;

  -- Banques
  INSERT INTO public.payment_methods (code, label, category_id, sort_order, is_active) VALUES
    ('bicici', 'BICICI', cat_banque, 1, true),
    ('sg_ci', 'SG CI', cat_banque, 2, true),
    ('nsia_banque', 'NSIA Banque', cat_banque, 3, true),
    ('ecobank', 'Ecobank', cat_banque, 4, true),
    ('orabank', 'Orabank', cat_banque, 5, true),
    ('boa', 'BOA', cat_banque, 6, true),
    ('autre_banque', 'Autre banque', cat_banque, 99, true)
  ON CONFLICT (code) DO UPDATE SET category_id = EXCLUDED.category_id;

  -- Chèque
  INSERT INTO public.payment_methods (code, label, category_id, sort_order, is_active) VALUES
    ('cheque_standard', 'Chèque', cat_cheque, 1, true)
  ON CONFLICT (code) DO UPDATE SET category_id = EXCLUDED.category_id;

  -- Espèces / Caisses
  INSERT INTO public.payment_methods (code, label, category_id, sort_order, is_active) VALUES
    ('caisse_principale', 'Caisse principale', cat_especes, 1, true),
    ('caisse_logistique', 'Caisse logistique', cat_especes, 2, true),
    ('caisse_chantier', 'Caisse chantier', cat_especes, 3, true)
  ON CONFLICT (code) DO UPDATE SET category_id = EXCLUDED.category_id;

  -- Autre
  INSERT INTO public.payment_methods (code, label, category_id, sort_order, is_active) VALUES
    ('autre_mode', 'Autre mode', cat_autre, 1, true)
  ON CONFLICT (code) DO UPDATE SET category_id = EXCLUDED.category_id;

END $$;

-- 5) Ajouter colonnes pour stocker les détails paiement structurés sur demandes_achat
ALTER TABLE public.demandes_achat
  ADD COLUMN IF NOT EXISTS payment_category_id UUID REFERENCES public.payment_categories(id),
  ADD COLUMN IF NOT EXISTS payment_method_id UUID REFERENCES public.payment_methods(id),
  ADD COLUMN IF NOT EXISTS payment_details JSONB DEFAULT '{}'::jsonb;

-- 6) Même chose pour notes_frais
ALTER TABLE public.notes_frais
  ADD COLUMN IF NOT EXISTS payment_category_id UUID REFERENCES public.payment_categories(id),
  ADD COLUMN IF NOT EXISTS payment_method_id UUID REFERENCES public.payment_methods(id),
  ADD COLUMN IF NOT EXISTS payment_details JSONB DEFAULT '{}'::jsonb;

-- 7) RLS pour permettre aux comptables/DAF de lire les catégories et méthodes
CREATE POLICY "Comptable DAF voient catégories"
  ON public.payment_categories
  FOR SELECT
  USING (is_comptable(auth.uid()) OR has_role(auth.uid(), 'daf'::app_role));

CREATE POLICY "Comptable DAF voient méthodes"
  ON public.payment_methods
  FOR SELECT
  USING (is_comptable(auth.uid()) OR has_role(auth.uid(), 'daf'::app_role));
