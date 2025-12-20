-- Drop the existing policy that's too restrictive for Achats
DROP POLICY IF EXISTS "Achats peut traiter DA" ON public.demandes_achat;

-- Create a new policy that allows Achats to update DAs and change status appropriately
-- USING checks current state, WITH CHECK validates the new state
CREATE POLICY "Achats peut traiter DA" 
ON public.demandes_achat 
FOR UPDATE 
USING ((is_achats(auth.uid()) OR is_admin(auth.uid())) AND status IN ('soumise'::da_status, 'en_analyse'::da_status, 'chiffree'::da_status))
WITH CHECK ((is_achats(auth.uid()) OR is_admin(auth.uid())) AND status IN ('soumise'::da_status, 'en_analyse'::da_status, 'chiffree'::da_status, 'soumise_validation'::da_status));