-- Update default currency from XAF to XOF in demandes_achat
ALTER TABLE public.demandes_achat 
ALTER COLUMN currency SET DEFAULT 'XOF';

-- Update default currency from XAF to XOF in da_article_prices
ALTER TABLE public.da_article_prices 
ALTER COLUMN currency SET DEFAULT 'XOF';

-- Update default currency from XAF to XOF in ecritures_comptables
ALTER TABLE public.ecritures_comptables 
ALTER COLUMN devise SET DEFAULT 'XOF';

-- Update existing records with XAF to XOF
UPDATE public.demandes_achat SET currency = 'XOF' WHERE currency = 'XAF';
UPDATE public.da_article_prices SET currency = 'XOF' WHERE currency = 'XAF';
UPDATE public.ecritures_comptables SET devise = 'XOF' WHERE devise = 'XAF';