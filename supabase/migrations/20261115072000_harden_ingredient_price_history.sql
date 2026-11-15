-- Harden the price-history trigger and keep RLS predicates init-plan friendly.
create index if not exists ingredient_price_history_changed_by_idx
  on public.ingredient_price_history(changed_by)
  where changed_by is not null;

drop policy if exists "admin read ingredient price history" on public.ingredient_price_history;
create policy "admin read ingredient price history" on public.ingredient_price_history
  for select to authenticated using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('owner','admin','manager','baker','pastry_chef')
    )
  );

drop policy if exists "admin insert ingredient price history" on public.ingredient_price_history;
create policy "admin insert ingredient price history" on public.ingredient_price_history
  for insert to authenticated with check (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('owner','admin','manager','baker','pastry_chef')
    )
  );

create or replace function public.record_ingredient_price_history()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.ingredient_price_history (
      ingredient_id, supplier_name, package_label, purchase_quantity,
      purchase_unit, purchase_price, price_per_base_unit, price_valid_from,
      price_source, changed_by
    ) values (
      new.ingredient_id, new.supplier_name, new.package_label,
      new.purchase_quantity, new.purchase_unit, new.purchase_price,
      new.price_per_base_unit, new.price_valid_from, new.price_source,
      auth.uid()
    );
  elsif new.purchase_price is distinct from old.purchase_price
     or new.purchase_quantity is distinct from old.purchase_quantity
     or new.purchase_unit is distinct from old.purchase_unit
     or new.supplier_name is distinct from old.supplier_name
     or new.price_valid_from is distinct from old.price_valid_from
     or new.price_source is distinct from old.price_source
     or new.package_label is distinct from old.package_label then
    insert into public.ingredient_price_history (
      ingredient_id, supplier_name, package_label, purchase_quantity,
      purchase_unit, purchase_price, price_per_base_unit, price_valid_from,
      price_source, changed_by
    ) values (
      new.ingredient_id, new.supplier_name, new.package_label,
      new.purchase_quantity, new.purchase_unit, new.purchase_price,
      new.price_per_base_unit, new.price_valid_from, new.price_source,
      auth.uid()
    );
  end if;
  return new;
end;
$$;

revoke all on function public.record_ingredient_price_history() from public, anon, authenticated;
