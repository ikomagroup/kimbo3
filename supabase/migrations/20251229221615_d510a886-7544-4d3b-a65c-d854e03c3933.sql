-- Create a security definer function to check if user can insert besoin lignes
CREATE OR REPLACE FUNCTION public.user_can_insert_besoin_ligne(_user_id uuid, _besoin_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.besoins
    WHERE id = _besoin_id 
      AND user_id = _user_id
      AND status = 'cree'
  )
$$;

-- Drop and recreate the policy using the security definer function
DROP POLICY IF EXISTS "Créateur peut insérer ses lignes" ON public.besoin_lignes;

CREATE POLICY "Créateur peut insérer ses lignes"
ON public.besoin_lignes
FOR INSERT
TO authenticated
WITH CHECK (
  public.user_can_insert_besoin_ligne(auth.uid(), besoin_id)
);