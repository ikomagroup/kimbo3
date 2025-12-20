-- Catégories de besoin
CREATE TYPE public.besoin_category AS ENUM (
  'materiel',
  'service',
  'maintenance',
  'urgence',
  'autre'
);

-- Niveaux d'urgence
CREATE TYPE public.besoin_urgency AS ENUM (
  'normale',
  'urgente',
  'critique'
);

-- Statuts du besoin (strictement limités)
CREATE TYPE public.besoin_status AS ENUM (
  'cree',
  'pris_en_charge',
  'accepte',
  'refuse'
);

-- Table des besoins internes
CREATE TABLE public.besoins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Identification (auto-rempli)
  department_id UUID NOT NULL REFERENCES public.departments(id),
  user_id UUID NOT NULL REFERENCES public.profiles(id),
  
  -- Contenu
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category besoin_category NOT NULL,
  urgency besoin_urgency NOT NULL DEFAULT 'normale',
  desired_date DATE,
  
  -- Pièce jointe optionnelle
  attachment_url TEXT,
  attachment_name TEXT,
  
  -- Statut et workflow
  status besoin_status NOT NULL DEFAULT 'cree',
  rejection_reason TEXT,
  
  -- Prise en charge logistique
  taken_by UUID REFERENCES public.profiles(id),
  taken_at TIMESTAMPTZ,
  
  -- Décision finale
  decided_by UUID REFERENCES public.profiles(id),
  decided_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- Contraintes
  CONSTRAINT rejection_reason_required CHECK (
    (status = 'refuse' AND rejection_reason IS NOT NULL AND rejection_reason <> '') OR
    (status <> 'refuse')
  )
);

-- Index pour performances
CREATE INDEX idx_besoins_department ON public.besoins(department_id);
CREATE INDEX idx_besoins_user ON public.besoins(user_id);
CREATE INDEX idx_besoins_status ON public.besoins(status);
CREATE INDEX idx_besoins_created_at ON public.besoins(created_at DESC);

-- Trigger updated_at
CREATE TRIGGER update_besoins_updated_at
  BEFORE UPDATE ON public.besoins
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Enable RLS
ALTER TABLE public.besoins ENABLE ROW LEVEL SECURITY;

-- Fonction helper: peut créer un besoin?
CREATE OR REPLACE FUNCTION public.can_create_besoin(_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
    AND role IN ('admin', 'dg', 'daf', 'responsable_departement', 'responsable_logistique', 'responsable_achats')
  )
$$;

-- Fonction helper: est logistique?
CREATE OR REPLACE FUNCTION public.is_logistics(_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
    AND role IN ('responsable_logistique', 'agent_logistique')
  )
$$;

-- Fonction helper: est DG?
CREATE OR REPLACE FUNCTION public.is_dg(_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
    AND role = 'dg'
  )
$$;

-- RLS Policies

-- SELECT: Créateur voit ses besoins, Logistique/DG/Admin voient tout
CREATE POLICY "Créateur voit ses propres besoins"
  ON public.besoins FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Logistique voit tous les besoins"
  ON public.besoins FOR SELECT
  USING (is_logistics(auth.uid()));

CREATE POLICY "DG voit tous les besoins"
  ON public.besoins FOR SELECT
  USING (is_dg(auth.uid()));

CREATE POLICY "Admin voit tous les besoins"
  ON public.besoins FOR SELECT
  USING (is_admin(auth.uid()));

-- INSERT: Seuls les rôles autorisés peuvent créer
CREATE POLICY "Rôles autorisés peuvent créer un besoin"
  ON public.besoins FOR INSERT
  WITH CHECK (
    can_create_besoin(auth.uid()) AND
    user_id = auth.uid() AND
    department_id = get_user_department(auth.uid())
  );

-- UPDATE: Créateur peut modifier si statut = 'cree', Logistique peut changer statut
CREATE POLICY "Créateur peut modifier si statut cree"
  ON public.besoins FOR UPDATE
  USING (
    user_id = auth.uid() AND
    status = 'cree'
  )
  WITH CHECK (
    user_id = auth.uid() AND
    status = 'cree'
  );

CREATE POLICY "Logistique peut gérer les besoins"
  ON public.besoins FOR UPDATE
  USING (is_logistics(auth.uid()) OR is_admin(auth.uid()));

-- DELETE: Admin uniquement
CREATE POLICY "Admin peut supprimer les besoins"
  ON public.besoins FOR DELETE
  USING (is_admin(auth.uid()));

-- Table des notifications in-app
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  link TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user ON public.notifications(user_id);
CREATE INDEX idx_notifications_unread ON public.notifications(user_id, is_read) WHERE NOT is_read;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Utilisateur voit ses notifications"
  ON public.notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Utilisateur peut modifier ses notifications"
  ON public.notifications FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Système peut créer des notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (true);

-- Fonction pour créer une notification
CREATE OR REPLACE FUNCTION public.create_notification(
  _user_id UUID,
  _type TEXT,
  _title TEXT,
  _message TEXT,
  _link TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _notification_id UUID;
BEGIN
  INSERT INTO public.notifications (user_id, type, title, message, link)
  VALUES (_user_id, _type, _title, _message, _link)
  RETURNING id INTO _notification_id;
  
  RETURN _notification_id;
END;
$$;

-- Trigger pour notifier la logistique à la création d'un besoin
CREATE OR REPLACE FUNCTION public.notify_logistics_on_besoin_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _logistics_user RECORD;
  _creator_name TEXT;
BEGIN
  -- Récupérer le nom du créateur
  SELECT CONCAT(first_name, ' ', last_name) INTO _creator_name
  FROM public.profiles WHERE id = NEW.user_id;
  
  -- Notifier tous les utilisateurs logistique
  FOR _logistics_user IN 
    SELECT DISTINCT ur.user_id 
    FROM public.user_roles ur
    WHERE ur.role IN ('responsable_logistique', 'agent_logistique')
  LOOP
    PERFORM create_notification(
      _logistics_user.user_id,
      'besoin_created',
      'Nouveau besoin interne',
      CONCAT('Besoin créé par ', _creator_name, ': ', NEW.title),
      '/besoins/' || NEW.id
    );
  END LOOP;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_besoin_created
  AFTER INSERT ON public.besoins
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_logistics_on_besoin_created();

-- Trigger pour notifier le créateur sur changement de statut
CREATE OR REPLACE FUNCTION public.notify_creator_on_besoin_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _title TEXT;
  _message TEXT;
BEGIN
  IF OLD.status <> NEW.status THEN
    CASE NEW.status
      WHEN 'pris_en_charge' THEN
        _title := 'Besoin pris en charge';
        _message := CONCAT('Votre besoin "', NEW.title, '" a été pris en charge par la Logistique.');
      WHEN 'accepte' THEN
        _title := 'Besoin accepté';
        _message := CONCAT('Votre besoin "', NEW.title, '" a été accepté pour transformation.');
      WHEN 'refuse' THEN
        _title := 'Besoin refusé';
        _message := CONCAT('Votre besoin "', NEW.title, '" a été refusé. Motif: ', COALESCE(NEW.rejection_reason, 'Non spécifié'));
      ELSE
        RETURN NEW;
    END CASE;
    
    PERFORM create_notification(
      NEW.user_id,
      'besoin_status_changed',
      _title,
      _message,
      '/besoins/' || NEW.id
    );
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_besoin_status_change
  AFTER UPDATE ON public.besoins
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_creator_on_besoin_status_change();