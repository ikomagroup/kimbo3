-- Migration 1: Ajouter les nouveaux statuts DA pour la validation financière
ALTER TYPE public.da_status ADD VALUE IF NOT EXISTS 'validee_finance';
ALTER TYPE public.da_status ADD VALUE IF NOT EXISTS 'refusee_finance';
ALTER TYPE public.da_status ADD VALUE IF NOT EXISTS 'en_revision_achats';