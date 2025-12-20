-- Table des écritures comptables SYSCOHADA
CREATE TABLE public.ecritures_comptables (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  da_id UUID NOT NULL REFERENCES public.demandes_achat(id) ON DELETE RESTRICT,
  reference TEXT NOT NULL,
  date_ecriture DATE NOT NULL DEFAULT CURRENT_DATE,
  classe_syscohada INTEGER NOT NULL CHECK (classe_syscohada BETWEEN 1 AND 7),
  compte_comptable TEXT NOT NULL,
  nature_charge TEXT NOT NULL,
  centre_cout TEXT,
  libelle TEXT NOT NULL,
  debit NUMERIC NOT NULL DEFAULT 0,
  credit NUMERIC NOT NULL DEFAULT 0,
  devise TEXT NOT NULL DEFAULT 'XAF',
  mode_paiement TEXT,
  reference_paiement TEXT,
  observations TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_validated BOOLEAN NOT NULL DEFAULT false,
  validated_by UUID REFERENCES public.profiles(id),
  validated_at TIMESTAMPTZ
);

-- Ajouter les colonnes comptables à demandes_achat
ALTER TABLE public.demandes_achat
ADD COLUMN IF NOT EXISTS comptabilise_by UUID REFERENCES public.profiles(id),
ADD COLUMN IF NOT EXISTS comptabilise_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS syscohada_classe INTEGER,
ADD COLUMN IF NOT EXISTS syscohada_compte TEXT,
ADD COLUMN IF NOT EXISTS syscohada_nature_charge TEXT,
ADD COLUMN IF NOT EXISTS syscohada_centre_cout TEXT,
ADD COLUMN IF NOT EXISTS mode_paiement TEXT,
ADD COLUMN IF NOT EXISTS reference_paiement TEXT,
ADD COLUMN IF NOT EXISTS comptabilite_rejection_reason TEXT;

-- RLS pour ecritures_comptables
ALTER TABLE public.ecritures_comptables ENABLE ROW LEVEL SECURITY;

-- Fonction helper pour vérifier si comptable
CREATE OR REPLACE FUNCTION public.is_comptable(_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
    AND role = 'comptable'
  )
$$;

-- Comptable peut voir toutes les écritures
CREATE POLICY "Comptable voit toutes les ecritures"
ON public.ecritures_comptables FOR SELECT
USING (is_comptable(auth.uid()) OR is_admin(auth.uid()) OR is_dg(auth.uid()) OR has_role(auth.uid(), 'daf'));

-- Comptable peut créer des écritures
CREATE POLICY "Comptable peut creer ecritures"
ON public.ecritures_comptables FOR INSERT
WITH CHECK (is_comptable(auth.uid()) AND created_by = auth.uid());

-- Comptable peut modifier écritures non validées
CREATE POLICY "Comptable peut modifier ecritures non validees"
ON public.ecritures_comptables FOR UPDATE
USING (is_comptable(auth.uid()) AND is_validated = false);

-- Admin peut supprimer
CREATE POLICY "Admin peut supprimer ecritures"
ON public.ecritures_comptables FOR DELETE
USING (is_admin(auth.uid()));

-- RLS: Comptable peut voir les DA validées financièrement
CREATE POLICY "Comptable voit DA validees finance"
ON public.demandes_achat FOR SELECT
USING (
  is_comptable(auth.uid()) 
  AND status IN ('validee_finance', 'payee', 'rejetee_comptabilite')
);

-- RLS: Comptable peut modifier les DA validées financièrement
CREATE POLICY "Comptable peut traiter DA validees"
ON public.demandes_achat FOR UPDATE
USING (
  is_comptable(auth.uid()) 
  AND status = 'validee_finance'
);

-- Notification quand DA payée
CREATE OR REPLACE FUNCTION public.notify_on_da_paid()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _besoin RECORD;
  _logistics_user RECORD;
  _daf_user RECORD;
  _dg_user RECORD;
BEGIN
  IF OLD.status = 'validee_finance' AND NEW.status = 'payee' THEN
    SELECT b.title, b.user_id INTO _besoin
    FROM public.besoins b WHERE b.id = NEW.besoin_id;
    
    -- Notifier le créateur du besoin
    PERFORM create_notification(
      _besoin.user_id,
      'da_paid',
      'Demande payée',
      CONCAT('Votre demande ', NEW.reference, ' a été payée (', NEW.total_amount, ' ', NEW.currency, ').'),
      '/demandes-achat/' || NEW.id
    );
    
    -- Notifier la Logistique
    FOR _logistics_user IN 
      SELECT DISTINCT ur.user_id 
      FROM public.user_roles ur
      WHERE ur.role IN ('responsable_logistique', 'agent_logistique')
    LOOP
      PERFORM create_notification(
        _logistics_user.user_id,
        'da_paid',
        'DA payée',
        CONCAT('La demande ', NEW.reference, ' a été payée. Le stock peut être réceptionné.'),
        '/demandes-achat/' || NEW.id
      );
    END LOOP;
    
    -- Notifier DAF
    FOR _daf_user IN 
      SELECT DISTINCT ur.user_id 
      FROM public.user_roles ur
      WHERE ur.role = 'daf'
    LOOP
      PERFORM create_notification(
        _daf_user.user_id,
        'da_paid',
        'Paiement effectué',
        CONCAT('La DA ', NEW.reference, ' (', NEW.total_amount, ' ', NEW.currency, ') a été payée.'),
        '/demandes-achat/' || NEW.id
      );
    END LOOP;
    
    -- Notifier DG
    FOR _dg_user IN 
      SELECT DISTINCT ur.user_id 
      FROM public.user_roles ur
      WHERE ur.role = 'dg'
    LOOP
      PERFORM create_notification(
        _dg_user.user_id,
        'da_paid',
        'Paiement effectué',
        CONCAT('DA ', NEW.reference, ' payée: ', NEW.total_amount, ' ', NEW.currency),
        '/demandes-achat/' || NEW.id
      );
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Notification quand DA rejetée comptablement
CREATE OR REPLACE FUNCTION public.notify_on_da_rejected_comptabilite()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _besoin RECORD;
  _logistics_user RECORD;
  _daf_user RECORD;
BEGIN
  IF OLD.status = 'validee_finance' AND NEW.status = 'rejetee_comptabilite' THEN
    SELECT b.title, b.user_id INTO _besoin
    FROM public.besoins b WHERE b.id = NEW.besoin_id;
    
    -- Notifier DAF
    FOR _daf_user IN 
      SELECT DISTINCT ur.user_id 
      FROM public.user_roles ur
      WHERE ur.role = 'daf'
    LOOP
      PERFORM create_notification(
        _daf_user.user_id,
        'da_rejected_comptabilite',
        'DA rejetée par Comptabilité',
        CONCAT('La DA ', NEW.reference, ' a été rejetée. Motif: ', COALESCE(NEW.comptabilite_rejection_reason, 'Non spécifié')),
        '/demandes-achat/' || NEW.id
      );
    END LOOP;
    
    -- Notifier Logistique
    FOR _logistics_user IN 
      SELECT DISTINCT ur.user_id 
      FROM public.user_roles ur
      WHERE ur.role IN ('responsable_logistique', 'agent_logistique')
    LOOP
      PERFORM create_notification(
        _logistics_user.user_id,
        'da_rejected_comptabilite',
        'DA rejetée',
        CONCAT('La DA ', NEW.reference, ' a été rejetée par la Comptabilité.'),
        '/demandes-achat/' || NEW.id
      );
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Créer les triggers
DROP TRIGGER IF EXISTS trigger_da_paid ON public.demandes_achat;
CREATE TRIGGER trigger_da_paid
  AFTER UPDATE ON public.demandes_achat
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_da_paid();

DROP TRIGGER IF EXISTS trigger_da_rejected_comptabilite ON public.demandes_achat;
CREATE TRIGGER trigger_da_rejected_comptabilite
  AFTER UPDATE ON public.demandes_achat
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_da_rejected_comptabilite();

-- Générer référence écriture
CREATE OR REPLACE FUNCTION public.generate_ecriture_reference()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _year TEXT;
  _month TEXT;
  _count INT;
  _ref TEXT;
BEGIN
  _year := to_char(now(), 'YYYY');
  _month := to_char(now(), 'MM');
  SELECT COUNT(*) + 1 INTO _count 
  FROM public.ecritures_comptables 
  WHERE reference LIKE 'EC-' || _year || _month || '-%';
  _ref := 'EC-' || _year || _month || '-' || lpad(_count::TEXT, 5, '0');
  RETURN _ref;
END;
$$;