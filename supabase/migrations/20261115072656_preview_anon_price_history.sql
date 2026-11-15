-- Keep the isolated preview's anonymous recipe workflow functional.
drop policy if exists "preview anon manage ingredient price history" on public.ingredient_price_history;
create policy "preview anon manage ingredient price history" on public.ingredient_price_history
  for all to anon using (true) with check (true);
grant select, insert on public.ingredient_price_history to anon;