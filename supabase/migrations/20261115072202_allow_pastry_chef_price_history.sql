drop policy if exists "admin read ingredient price history" on public.ingredient_price_history;
create policy "admin read ingredient price history" on public.ingredient_price_history
  for select to authenticated using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('owner','admin','manager','baker','pastry_chef','pastryChef')
    )
  );

drop policy if exists "admin insert ingredient price history" on public.ingredient_price_history;
create policy "admin insert ingredient price history" on public.ingredient_price_history
  for insert to authenticated with check (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('owner','admin','manager','baker','pastry_chef','pastryChef')
    )
  );