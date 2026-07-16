-- Run once in Supabase Dashboard > SQL Editor.
ALTER TABLE public.links
  ADD COLUMN IF NOT EXISTS is_favorite boolean NOT NULL DEFAULT false;

-- Reload the PostgREST schema cache immediately.
NOTIFY pgrst, 'reload schema';
