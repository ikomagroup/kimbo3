-- =====================================================
-- MODULE SERVICE ACHATS (v2) - Part 2: Tables & Policies
-- =====================================================

-- =====================================================
-- TABLE: Fournisseurs
-- =====================================================
CREATE TABLE public.fournisseurs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  contact_name TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER update_fournisseurs_updated_at
  BEFORE UPDATE ON public.fournisseurs
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =====================================================
-- TABLE: Prix des articles DA
-- =====================================================
CREATE TABLE public.da_article_prices (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  da_article_id UUID NOT NULL REFERENCES public.da_articles(id) ON DELETE CASCADE,
  fournisseur_id UUID NOT NULL REFERENCES public.fournisseurs(id),
  unit_price DECIMAL(15,2) NOT NULL CHECK (unit_price >= 0),
  currency TEXT NOT NULL DEFAULT 'XAF',
  delivery_delay TEXT,
  conditions TEXT,
  is_selected BOOLEAN NOT NULL DEFAULT false,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(da_article_id, fournisseur_id)
);

-- =====================================================
-- Colonnes supplémentaires sur DA
-- =====================================================
ALTER TABLE public.demandes_achat 
  ADD COLUMN IF NOT EXISTS selected_fournisseur_id UUID REFERENCES public.fournisseurs(id),
  ADD COLUMN IF NOT EXISTS fournisseur_justification TEXT,
  ADD COLUMN IF NOT EXISTS total_amount DECIMAL(15,2),
  ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'XAF',
  ADD COLUMN IF NOT EXISTS analyzed_by UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS analyzed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS priced_by UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS priced_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS submitted_validation_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS submitted_validation_by UUID REFERENCES public.profiles(id);

-- =====================================================
-- RLS: Fournisseurs
-- =====================================================
ALTER TABLE public.fournisseurs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Utilisateurs voient fournisseurs actifs"
ON public.fournisseurs FOR SELECT
USING (is_active = true OR is_admin(auth.uid()) OR is_achats(auth.uid()));

CREATE POLICY "Achats peut créer fournisseurs"
ON public.fournisseurs FOR INSERT
WITH CHECK (is_achats(auth.uid()) OR is_admin(auth.uid()));

CREATE POLICY "Achats peut modifier fournisseurs"
ON public.fournisseurs FOR UPDATE
USING (is_achats(auth.uid()) OR is_admin(auth.uid()));

CREATE POLICY "Admin peut supprimer fournisseurs"
ON public.fournisseurs FOR DELETE
USING (is_admin(auth.uid()));

-- =====================================================
-- RLS: Prix articles DA
-- =====================================================
ALTER TABLE public.da_article_prices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Acces prix via DA"
ON public.da_article_prices FOR SELECT
USING (EXISTS (
  SELECT 1 FROM public.da_articles da_art
  JOIN public.demandes_achat da ON da.id = da_art.da_id
  WHERE da_art.id = da_article_id
  AND (is_admin(auth.uid()) OR is_dg(auth.uid()) OR is_achats(auth.uid()) 
       OR is_logistics(auth.uid()) OR has_role(auth.uid(), 'daf'))
));

CREATE POLICY "Achats peut creer prix"
ON public.da_article_prices FOR INSERT
WITH CHECK (is_achats(auth.uid()) OR is_admin(auth.uid()));

CREATE POLICY "Achats peut modifier prix"
ON public.da_article_prices FOR UPDATE
USING (is_achats(auth.uid()) OR is_admin(auth.uid()));

CREATE POLICY "Achats peut supprimer prix"
ON public.da_article_prices FOR DELETE
USING (is_achats(auth.uid()) OR is_admin(auth.uid()));

-- =====================================================
-- Mise à jour politique UPDATE DA pour Achats
-- =====================================================
DROP POLICY IF EXISTS "Achats peut rejeter DA soumise" ON public.demandes_achat;

CREATE POLICY "Achats peut traiter DA"
ON public.demandes_achat FOR UPDATE
USING (
  (is_achats(auth.uid()) OR is_admin(auth.uid())) 
  AND status IN ('soumise', 'en_analyse', 'chiffree')
);

-- =====================================================
-- NOTIFICATIONS
-- =====================================================

CREATE OR REPLACE FUNCTION public.notify_on_da_submitted_validation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _finance_user RECORD;
  _besoin RECORD;
BEGIN
  IF OLD.status IN ('en_analyse', 'chiffree') AND NEW.status = 'soumise_validation' THEN
    SELECT b.title, b.user_id INTO _besoin
    FROM public.besoins b WHERE b.id = NEW.besoin_id;
    
    FOR _finance_user IN 
      SELECT DISTINCT ur.user_id 
      FROM public.user_roles ur
      WHERE ur.role IN ('daf', 'dg')
    LOOP
      PERFORM create_notification(
        _finance_user.user_id,
        'da_validation_required',
        'DA prete pour validation',
        CONCAT('La demande d''achat ', NEW.reference, ' (', COALESCE(NEW.total_amount::TEXT, '0'), ' ', COALESCE(NEW.currency, 'XAF'), ') requiert votre validation.'),
        '/demandes-achat/' || NEW.id
      );
    END LOOP;
    
    PERFORM create_notification(
      _besoin.user_id,
      'da_submitted_validation',
      'DA soumise a validation',
      CONCAT('Votre demande ', NEW.reference, ' a ete chiffree et soumise a validation financiere.'),
      '/demandes-achat/' || NEW.id
    );
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_da_submitted_validation
  AFTER UPDATE ON public.demandes_achat
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_da_submitted_validation();

CREATE OR REPLACE FUNCTION public.notify_on_da_rejected_achats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _besoin RECORD;
  _logistics_user RECORD;
BEGIN
  IF OLD.status IN ('soumise', 'en_analyse') AND NEW.status = 'rejetee' THEN
    SELECT b.title, b.user_id INTO _besoin
    FROM public.besoins b WHERE b.id = NEW.besoin_id;
    
    PERFORM create_notification(
      _besoin.user_id,
      'da_rejected',
      'DA rejetee par les Achats',
      CONCAT('La demande ', NEW.reference, ' a ete rejetee. Motif: ', COALESCE(NEW.rejection_reason, 'Non specifie')),
      '/demandes-achat/' || NEW.id
    );
    
    FOR _logistics_user IN 
      SELECT DISTINCT ur.user_id 
      FROM public.user_roles ur
      WHERE ur.role IN ('responsable_logistique', 'agent_logistique')
    LOOP
      PERFORM create_notification(
        _logistics_user.user_id,
        'da_rejected',
        'DA rejetee',
        CONCAT('La demande ', NEW.reference, ' a ete rejetee par le Service Achats.'),
        '/demandes-achat/' || NEW.id
      );
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_da_rejected_achats
  AFTER UPDATE ON public.demandes_achat
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_da_rejected_achats();