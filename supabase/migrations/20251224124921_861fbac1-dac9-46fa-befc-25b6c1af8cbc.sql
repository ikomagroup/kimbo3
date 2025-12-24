-- Permettre à la logistique et admin de supprimer les articles du stock
CREATE POLICY "Logistique peut supprimer articles stock" 
ON public.articles_stock 
FOR DELETE 
USING (is_logistics(auth.uid()) OR is_admin(auth.uid()));

-- Permettre au DAF de supprimer les articles du stock
CREATE POLICY "DAF peut supprimer articles stock" 
ON public.articles_stock 
FOR DELETE 
USING (has_role(auth.uid(), 'daf'::app_role));