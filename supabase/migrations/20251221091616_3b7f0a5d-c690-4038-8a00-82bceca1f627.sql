-- Create storage bucket for besoins attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('besoins-attachments', 'besoins-attachments', true)
ON CONFLICT (id) DO NOTHING;

-- RLS policies for besoins-attachments bucket
CREATE POLICY "Users can upload their own besoins attachments"
ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'besoins-attachments' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view besoins attachments"
ON storage.objects
FOR SELECT
USING (bucket_id = 'besoins-attachments');

CREATE POLICY "Users can delete their own besoins attachments"
ON storage.objects
FOR DELETE
USING (bucket_id = 'besoins-attachments' AND auth.uid()::text = (storage.foldername(name))[1]);