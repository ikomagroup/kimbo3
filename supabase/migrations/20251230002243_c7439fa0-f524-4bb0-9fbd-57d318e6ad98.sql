-- ============================================================
-- MIGRATION KPM PRODUCTION-READY : BLOC 1-5
-- Date: 2025-12-30
-- Objectif: Audit trail complet, traçabilité, stock, workflow
-- ============================================================

-- ============================================================
-- BLOC 1.1: AUDIT TRIGGERS SUR TOUTES LES TABLES MÉTIER
-- ============================================================

-- Fonction d'audit déjà existante: audit_trigger_function()
-- Ajout des triggers sur les 21 tables manquantes

-- besoin_attachments
DROP TRIGGER IF EXISTS audit_besoin_attachments ON public.besoin_attachments;
CREATE TRIGGER audit_besoin_attachments
  AFTER INSERT OR UPDATE OR DELETE ON public.besoin_attachments
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- besoin_lignes
DROP TRIGGER IF EXISTS audit_besoin_lignes ON public.besoin_lignes;
CREATE TRIGGER audit_besoin_lignes
  AFTER INSERT OR UPDATE OR DELETE ON public.besoin_lignes
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- bl_articles
DROP TRIGGER IF EXISTS audit_bl_articles ON public.bl_articles;
CREATE TRIGGER audit_bl_articles
  AFTER INSERT OR UPDATE OR DELETE ON public.bl_articles
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- caisse_mouvements
DROP TRIGGER IF EXISTS audit_caisse_mouvements ON public.caisse_mouvements;
CREATE TRIGGER audit_caisse_mouvements
  AFTER INSERT OR UPDATE OR DELETE ON public.caisse_mouvements
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- caisses
DROP TRIGGER IF EXISTS audit_caisses ON public.caisses;
CREATE TRIGGER audit_caisses
  AFTER INSERT OR UPDATE OR DELETE ON public.caisses
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- comptes_comptables
DROP TRIGGER IF EXISTS audit_comptes_comptables ON public.comptes_comptables;
CREATE TRIGGER audit_comptes_comptables
  AFTER INSERT OR UPDATE OR DELETE ON public.comptes_comptables
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- da_article_prices
DROP TRIGGER IF EXISTS audit_da_article_prices ON public.da_article_prices;
CREATE TRIGGER audit_da_article_prices
  AFTER INSERT OR UPDATE OR DELETE ON public.da_article_prices
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- da_articles
DROP TRIGGER IF EXISTS audit_da_articles ON public.da_articles;
CREATE TRIGGER audit_da_articles
  AFTER INSERT OR UPDATE OR DELETE ON public.da_articles
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- departments
DROP TRIGGER IF EXISTS audit_departments ON public.departments;
CREATE TRIGGER audit_departments
  AFTER INSERT OR UPDATE OR DELETE ON public.departments
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- note_frais_lignes
DROP TRIGGER IF EXISTS audit_note_frais_lignes ON public.note_frais_lignes;
CREATE TRIGGER audit_note_frais_lignes
  AFTER INSERT OR UPDATE OR DELETE ON public.note_frais_lignes
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- notes_frais
DROP TRIGGER IF EXISTS audit_notes_frais ON public.notes_frais;
CREATE TRIGGER audit_notes_frais
  AFTER INSERT OR UPDATE OR DELETE ON public.notes_frais
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- notifications
DROP TRIGGER IF EXISTS audit_notifications ON public.notifications;
CREATE TRIGGER audit_notifications
  AFTER INSERT OR UPDATE OR DELETE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- payment_categories
DROP TRIGGER IF EXISTS audit_payment_categories ON public.payment_categories;
CREATE TRIGGER audit_payment_categories
  AFTER INSERT OR UPDATE OR DELETE ON public.payment_categories
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- payment_methods
DROP TRIGGER IF EXISTS audit_payment_methods ON public.payment_methods;
CREATE TRIGGER audit_payment_methods
  AFTER INSERT OR UPDATE OR DELETE ON public.payment_methods
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- permissions
DROP TRIGGER IF EXISTS audit_permissions ON public.permissions;
CREATE TRIGGER audit_permissions
  AFTER INSERT OR UPDATE OR DELETE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- projets
DROP TRIGGER IF EXISTS audit_projets ON public.projets;
CREATE TRIGGER audit_projets
  AFTER INSERT OR UPDATE OR DELETE ON public.projets
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- role_permissions
DROP TRIGGER IF EXISTS audit_role_permissions ON public.role_permissions;
CREATE TRIGGER audit_role_permissions
  AFTER INSERT OR UPDATE OR DELETE ON public.role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- roles
DROP TRIGGER IF EXISTS audit_roles ON public.roles;
CREATE TRIGGER audit_roles
  AFTER INSERT OR UPDATE OR DELETE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- settings
DROP TRIGGER IF EXISTS audit_settings ON public.settings;
CREATE TRIGGER audit_settings
  AFTER INSERT OR UPDATE OR DELETE ON public.settings
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- stock_categories
DROP TRIGGER IF EXISTS audit_stock_categories ON public.stock_categories;
CREATE TRIGGER audit_stock_categories
  AFTER INSERT OR UPDATE OR DELETE ON public.stock_categories
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- units
DROP TRIGGER IF EXISTS audit_units ON public.units;
CREATE TRIGGER audit_units
  AFTER INSERT OR UPDATE OR DELETE ON public.units
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- ============================================================
-- BLOC 1.2: IMMUTABILITÉ AUDIT_LOGS DOCUMENTÉE
-- ============================================================

COMMENT ON TABLE public.audit_logs IS 
'TABLE AUDIT APPEND-ONLY PAR DESIGN.
============================================================
IMMUTABILITÉ GARANTIE : Aucune policy UPDATE ou DELETE ne doit 
être ajoutée sur cette table. Les logs sont immuables et 
constituent la preuve légale des opérations du système KPM.
Toute modification de cette règle nécessite validation 
de la direction et de l''auditeur externe.
============================================================
Date de mise en place: 2025-12-30
Responsable: Système KPM';

-- ============================================================
-- BLOC 2: TRAÇABILITÉ DES AUTEURS (NOT NULL)
-- ============================================================

-- D'abord, mettre à jour les enregistrements existants avec NULL
-- Utiliser un UUID système pour les enregistrements orphelins
DO $$
DECLARE
  system_user_id UUID := '00000000-0000-0000-0000-000000000000';
BEGIN
  -- articles_stock: created_by
  UPDATE public.articles_stock 
  SET created_by = system_user_id 
  WHERE created_by IS NULL;
  
  -- ecritures_comptables: created_by
  UPDATE public.ecritures_comptables 
  SET created_by = system_user_id 
  WHERE created_by IS NULL;
  
  -- caisse_mouvements: reference
  UPDATE public.caisse_mouvements 
  SET reference = 'REF-MIGRATION-' || SUBSTRING(id::text, 1, 8)
  WHERE reference IS NULL OR reference = '';
  
  -- stock_movements: reference
  UPDATE public.stock_movements 
  SET reference = 'REF-MIGRATION-' || SUBSTRING(id::text, 1, 8)
  WHERE reference IS NULL OR reference = '';
END $$;

-- Appliquer les contraintes NOT NULL
ALTER TABLE public.articles_stock 
  ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE public.ecritures_comptables 
  ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE public.caisse_mouvements 
  ALTER COLUMN reference SET NOT NULL;

ALTER TABLE public.stock_movements 
  ALTER COLUMN reference SET NOT NULL;

-- ============================================================
-- BLOC 3: VALIDATION STOCK SERVEUR (INTERDICTION STOCK NÉGATIF)
-- ============================================================

-- Trigger pour empêcher le stock négatif
CREATE OR REPLACE FUNCTION public.prevent_negative_stock()
RETURNS TRIGGER AS $$
BEGIN
  -- Vérifier que quantity_available ne devient pas négatif
  IF NEW.quantity_available < 0 THEN
    -- Logger l'erreur dans audit_logs
    INSERT INTO public.audit_logs (
      user_id,
      action,
      table_name,
      record_id,
      old_values,
      new_values
    ) VALUES (
      auth.uid(),
      'STOCK_NEGATIVE_BLOCKED',
      'articles_stock',
      NEW.id,
      jsonb_build_object('quantity_available', OLD.quantity_available),
      jsonb_build_object(
        'attempted_quantity', NEW.quantity_available,
        'designation', NEW.designation,
        'blocked_at', NOW()
      )
    );
    
    RAISE EXCEPTION 'STOCK_NEGATIF_INTERDIT: La quantité disponible ne peut pas être négative. Article: %, Quantité tentée: %', 
      NEW.designation, NEW.quantity_available;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS prevent_negative_stock_trigger ON public.articles_stock;
CREATE TRIGGER prevent_negative_stock_trigger
  BEFORE UPDATE ON public.articles_stock
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_negative_stock();

-- Contrainte CHECK additionnelle pour les INSERT
ALTER TABLE public.articles_stock 
  DROP CONSTRAINT IF EXISTS articles_stock_quantity_non_negative;
ALTER TABLE public.articles_stock 
  ADD CONSTRAINT articles_stock_quantity_non_negative 
  CHECK (quantity_available >= 0);

-- ============================================================
-- BLOC 4: WORKFLOW BESOIN - NOUVEAU STATUT 'RETOURNE'
-- ============================================================

-- Ajouter la valeur à l'enum besoin_status
ALTER TYPE public.besoin_status ADD VALUE IF NOT EXISTS 'retourne';

-- Commentaire documentant les statuts
COMMENT ON TYPE public.besoin_status IS 
'Statuts du workflow Besoin:
- cree: Besoin créé, en attente de prise en charge
- pris_en_charge: Pris en charge par la logistique
- accepte: Accepté pour transformation (DA ou BL)
- refuse: Refusé définitivement (fin de workflow)
- retourne: Retourné au demandeur pour correction (réversible)
Date: 2025-12-30';

-- ============================================================
-- BLOC 5: DAF DÉROGATION CONTRÔLÉE
-- ============================================================

-- Table de gouvernance pour documenter les dérogations
CREATE TABLE IF NOT EXISTS public.governance_derogations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  derogation_type TEXT NOT NULL,
  role_concerned TEXT NOT NULL,
  description TEXT NOT NULL,
  justification TEXT NOT NULL,
  approved_by TEXT NOT NULL,
  approval_date DATE NOT NULL,
  expiration_date DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  review_frequency TEXT DEFAULT 'trimestriel',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Activer RLS
ALTER TABLE public.governance_derogations ENABLE ROW LEVEL SECURITY;

-- Politique: seuls admin et DG peuvent gérer
CREATE POLICY "Admin DG gèrent dérogations"
  ON public.governance_derogations
  FOR ALL
  USING (is_admin(auth.uid()) OR is_dg(auth.uid()))
  WITH CHECK (is_admin(auth.uid()) OR is_dg(auth.uid()));

-- Politique: DAF et comptable peuvent lire
CREATE POLICY "DAF Comptable lisent dérogations"
  ON public.governance_derogations
  FOR SELECT
  USING (has_role(auth.uid(), 'daf') OR is_comptable(auth.uid()));

-- Audit trigger
CREATE TRIGGER audit_governance_derogations
  AFTER INSERT OR UPDATE OR DELETE ON public.governance_derogations
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();

-- Insérer la dérogation DAF documentée
INSERT INTO public.governance_derogations (
  derogation_type,
  role_concerned,
  description,
  justification,
  approved_by,
  approval_date,
  expiration_date,
  is_active,
  review_frequency
) VALUES (
  'CUMUL_POUVOIRS_OPERATIONNELS_CONTROLE',
  'daf',
  'Le rôle DAF cumule des pouvoirs opérationnels (création DA, analyse, chiffrage, gestion fournisseurs, manipulation stock) avec ses pouvoirs de contrôle financier (validation, paiement). Cette configuration permet au DAF d''exécuter un workflow complet sans contre-pouvoir.',
  'Dérogation temporaire validée par la direction pour la phase de démarrage. L''organisation actuelle ne permet pas une séparation stricte des rôles. Cette dérogation sera levée dès que les effectifs le permettront.',
  'Direction Générale Kimbo Africa SA',
  CURRENT_DATE,
  CURRENT_DATE + INTERVAL '6 months',
  true,
  'trimestriel'
);

-- Commentaire sur la table
COMMENT ON TABLE public.governance_derogations IS 
'Table de gouvernance traçant les dérogations aux règles de séparation des pouvoirs.
Chaque dérogation doit être explicitement justifiée, approuvée et révisée périodiquement.
USAGE AUDITEUR: Cette table constitue la preuve des décisions de gouvernance.
Date de mise en place: 2025-12-30';

-- ============================================================
-- BLOC 6: DOCUMENTATION SYSTÈME DE RÔLES
-- ============================================================

COMMENT ON TABLE public.user_roles IS 
'SYSTÈME DE RÔLES DUAL (MIGRATION EN COURS)
============================================================
État actuel:
- Colonne legacy "role" (enum app_role): utilisée par les fonctions RLS
- Colonne "role_id" (FK vers roles): nouveau système dynamique

Système cible: role_id uniquement avec table roles
Règle de transition: 
- Toute création/modification doit mettre à jour LES DEUX colonnes
- Les fonctions has_role() utilisent l''enum legacy
- Le système dynamique de permissions utilise role_id

Plan de convergence:
1. Compléter la migration des données role_id
2. Modifier les fonctions RLS pour utiliser role_id
3. Déprécier puis supprimer la colonne role enum
============================================================
Date documentation: 2025-12-30';

COMMENT ON TABLE public.roles IS 
'Table cible du système de rôles dynamiques.
Contient les définitions de rôles avec leurs propriétés.
Liée à role_permissions pour les permissions granulaires.
Date: 2025-12-30';