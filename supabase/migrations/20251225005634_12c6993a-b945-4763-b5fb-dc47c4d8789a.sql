-- Insertion des comptes comptables SYSCOHADA par défaut (Classes 6 et 7 principalement)

-- Classe 6 - Comptes de charges
INSERT INTO public.comptes_comptables (code, libelle, classe, is_active) VALUES
-- 60 - Achats et variations de stocks
('601', 'Achats de marchandises', 6, true),
('602', 'Achats de matières premières', 6, true),
('604', 'Achats stockés de matières et fournitures consommables', 6, true),
('605', 'Autres achats', 6, true),
('608', 'Achats d''emballages', 6, true),

-- 61 - Transports
('611', 'Transports sur achats', 6, true),
('612', 'Transports sur ventes', 6, true),
('613', 'Transports pour le compte de tiers', 6, true),
('618', 'Autres frais de transport', 6, true),

-- 62 - Services extérieurs A
('621', 'Sous-traitance générale', 6, true),
('622', 'Locations et charges locatives', 6, true),
('623', 'Redevances de crédit-bail et contrats assimilés', 6, true),
('624', 'Entretien, réparations et maintenance', 6, true),
('625', 'Primes d''assurance', 6, true),
('626', 'Études, recherches et documentation', 6, true),
('627', 'Publicité, publications, relations publiques', 6, true),
('628', 'Frais de télécommunications', 6, true),

-- 63 - Services extérieurs B
('631', 'Frais bancaires', 6, true),
('632', 'Rémunérations d''intermédiaires et de conseils', 6, true),
('633', 'Frais de formation du personnel', 6, true),
('634', 'Redevances pour brevets, licences et droits', 6, true),
('635', 'Cotisations', 6, true),
('636', 'Dons', 6, true),
('637', 'Réceptions', 6, true),
('638', 'Autres charges externes', 6, true),

-- 64 - Impôts et taxes
('641', 'Impôts et taxes directs', 6, true),
('645', 'Impôts et taxes indirects', 6, true),
('646', 'Droits d''enregistrement', 6, true),
('647', 'Pénalités et amendes fiscales', 6, true),
('648', 'Autres impôts et taxes', 6, true),

-- 65 - Autres charges
('651', 'Pertes sur créances clients', 6, true),
('652', 'Quote-part de résultat sur opérations en commun', 6, true),
('654', 'Valeurs comptables des cessions courantes d''immobilisations', 6, true),
('658', 'Charges diverses', 6, true),

-- 66 - Charges de personnel
('661', 'Rémunérations directes versées au personnel national', 6, true),
('662', 'Rémunérations directes versées au personnel non national', 6, true),
('663', 'Indemnités forfaitaires versées au personnel', 6, true),
('664', 'Charges sociales', 6, true),
('665', 'Charges de personnel affecté à l''exploitation', 6, true),
('666', 'Rémunérations et charges sociales de l''exploitant individuel', 6, true),
('668', 'Autres charges sociales', 6, true),

-- 67 - Charges financières
('671', 'Charges d''intérêts', 6, true),
('672', 'Pertes sur créances liées à des participations', 6, true),
('673', 'Pertes sur cessions de titres de placement', 6, true),
('674', 'Pertes de change', 6, true),
('676', 'Pertes sur risques financiers', 6, true),
('678', 'Autres charges financières', 6, true),

-- 68 - Dotations aux amortissements
('681', 'Dotations aux amortissements d''exploitation', 6, true),
('687', 'Dotations aux amortissements à caractère financier', 6, true),

-- 69 - Dotations aux provisions
('691', 'Dotations aux provisions d''exploitation', 6, true),
('697', 'Dotations aux provisions financières', 6, true),

-- Classe 7 - Comptes de produits
-- 70 - Ventes
('701', 'Ventes de marchandises', 7, true),
('702', 'Ventes de produits finis', 7, true),
('703', 'Ventes de produits intermédiaires', 7, true),
('704', 'Ventes de produits résiduels', 7, true),
('705', 'Travaux facturés', 7, true),
('706', 'Services vendus', 7, true),
('707', 'Produits accessoires', 7, true),

-- 71 - Subventions d'exploitation
('711', 'Subventions d''exploitation reçues', 7, true),
('712', 'Subventions d''équilibre reçues', 7, true),

-- 72 - Production immobilisée
('721', 'Production immobilisée d''immobilisations incorporelles', 7, true),
('722', 'Production immobilisée d''immobilisations corporelles', 7, true),

-- 73 - Variations de stocks
('731', 'Variations de stocks de produits en cours', 7, true),
('732', 'Variations de stocks de produits finis', 7, true),
('734', 'Variations des en-cours de services', 7, true),

-- 75 - Autres produits
('752', 'Quote-part de résultat sur opérations en commun', 7, true),
('754', 'Produits des cessions courantes d''immobilisations', 7, true),
('758', 'Produits divers', 7, true),

-- 77 - Produits financiers
('771', 'Revenus des titres de participation', 7, true),
('772', 'Revenus des titres de placement', 7, true),
('773', 'Produits financiers liés à des opérations en commun', 7, true),
('774', 'Gains de change', 7, true),
('775', 'Escomptes obtenus', 7, true),
('776', 'Gains sur risques financiers', 7, true),
('778', 'Autres produits financiers', 7, true),

-- 78 - Transferts de charges
('781', 'Transferts de charges d''exploitation', 7, true),
('787', 'Transferts de charges financières', 7, true),

-- 79 - Reprises de provisions
('791', 'Reprises de provisions d''exploitation', 7, true),
('797', 'Reprises de provisions financières', 7, true),

-- Classe 5 - Comptes de trésorerie (utiles pour les paiements)
('512', 'Banques locales', 5, true),
('514', 'Chèques postaux', 5, true),
('517', 'Banques étrangères', 5, true),
('521', 'Banques locales - Comptes courants', 5, true),
('531', 'Chèques à encaisser', 5, true),
('571', 'Caisse siège social', 5, true),
('572', 'Caisse succursale', 5, true),
('581', 'Virements de fonds', 5, true),

-- Classe 4 - Comptes de tiers (fournisseurs)
('401', 'Fournisseurs', 4, true),
('408', 'Fournisseurs - Factures non parvenues', 4, true),
('409', 'Fournisseurs débiteurs', 4, true),
('411', 'Clients', 4, true),
('421', 'Personnel - Avances et acomptes', 4, true),
('422', 'Personnel - Rémunérations dues', 4, true),
('431', 'Sécurité sociale', 4, true),
('441', 'État, impôt sur les bénéfices', 4, true),
('443', 'État, TVA facturée', 4, true),
('445', 'État, TVA récupérable', 4, true),
('447', 'État, impôts retenus à la source', 4, true)

ON CONFLICT (code) DO NOTHING;