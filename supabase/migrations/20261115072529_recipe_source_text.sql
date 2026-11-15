-- Preserve the verified OCR text as the source attached to a technology card.
alter table public.recipe_tech_cards add column if not exists source_text text;