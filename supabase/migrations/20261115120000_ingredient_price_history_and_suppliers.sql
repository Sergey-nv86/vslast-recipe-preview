-- Supplier-aware ingredient price directory with an immutable price history.
-- Apply only to the isolated vslast-recipe-tech Supabase project.

alter table public.ingredient_prices
  add column if not exists supplier_name text,
  add column if not exists price_valid_from date not null default current_date,
  add column if not exists price_source text,
  add column if not exists package_label text;

create table if not exists public.ingredient_price_history (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.ingredients(id) on delete cascade,
  supplier_name text,
  package_label text,
  purchase_quantity numeric(14,4) not null,
  purchase_unit text not null check (purchase_unit in ('g','kg','ml','l','pcs')),
  purchase_price numeric(14,2) not null check (purchase_price >= 0),
  price_per_base_unit numeric(16,8) not null,
  price_valid_from date not null default current_date,
  price_source text,
  changed_at timestamptz not null default now(),
  changed_by uuid references auth.users(id)
);

create index if not exists ingredient_price_history_lookup_idx
  on public.ingredient_price_history(ingredient_id, changed_at desc);

alter table public.ingredient_price_history enable row level security;
drop policy if exists "admin read ingredient price history" on public.ingredient_price_history;
create policy "admin read ingredient price history" on public.ingredient_price_history
  for select to authenticated using (
    exists (select 1 from public.profiles p where p.id=auth.uid()
      and p.role in ('owner','admin','manager','baker','pastry_chef'))
  );
drop policy if exists "admin insert ingredient price history" on public.ingredient_price_history;
create policy "admin insert ingredient price history" on public.ingredient_price_history
  for insert to authenticated with check (
    exists (select 1 from public.profiles p where p.id=auth.uid()
      and p.role in ('owner','admin','manager','baker','pastry_chef'))
  );
grant select, insert on public.ingredient_price_history to authenticated;

create or replace function public.record_ingredient_price_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT'
     or new.purchase_price is distinct from old.purchase_price
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

drop trigger if exists ingredient_price_history_after_change on public.ingredient_prices;
create trigger ingredient_price_history_after_change
after insert or update on public.ingredient_prices
for each row execute function public.record_ingredient_price_history();
