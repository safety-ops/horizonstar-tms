-- Local Driver Auth + Local Flow Sync
-- Idempotent migration: safe for repeated deployment

begin;

create table if not exists public.local_drivers (
  id bigserial primary key,
  name text not null,
  phone text,
  service_area text,
  notes text,
  email text,
  status text not null default 'ACTIVE',
  auth_user_id uuid,
  linked_driver_id bigint,
  app_access_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.local_drivers add column if not exists email text;
alter table public.local_drivers add column if not exists status text default 'ACTIVE';
alter table public.local_drivers add column if not exists auth_user_id uuid;
alter table public.local_drivers add column if not exists linked_driver_id bigint;
alter table public.local_drivers add column if not exists app_access_enabled boolean default false;

update public.local_drivers
set status = 'ACTIVE'
where status is null;

update public.local_drivers
set app_access_enabled = false
where app_access_enabled is null;

alter table public.local_drivers
  alter column status set default 'ACTIVE';

alter table public.local_drivers
  alter column app_access_enabled set default false;

alter table public.local_drivers
  alter column app_access_enabled set not null;

create unique index if not exists idx_local_drivers_email_unique
  on public.local_drivers (lower(email))
  where email is not null and btrim(email) <> '';

create unique index if not exists idx_local_drivers_linked_driver_unique
  on public.local_drivers (linked_driver_id)
  where linked_driver_id is not null;

create index if not exists idx_local_drivers_auth_user_id
  on public.local_drivers (auth_user_id);

create index if not exists idx_local_drivers_status
  on public.local_drivers (status);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'local_drivers_auth_user_id_fkey'
      and conrelid = 'public.local_drivers'::regclass
  ) then
    alter table public.local_drivers
      add constraint local_drivers_auth_user_id_fkey
      foreign key (auth_user_id) references auth.users(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'local_drivers_linked_driver_id_fkey'
      and conrelid = 'public.local_drivers'::regclass
  ) then
    alter table public.local_drivers
      add constraint local_drivers_linked_driver_id_fkey
      foreign key (linked_driver_id) references public.drivers(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'local_drivers_status_check'
      and conrelid = 'public.local_drivers'::regclass
  ) then
    alter table public.local_drivers
      add constraint local_drivers_status_check
      check (upper(status) in ('ACTIVE', 'INACTIVE'));
  end if;
end $$;

alter table public.orders add column if not exists local_driver_id bigint;
alter table public.orders add column if not exists local_delivery_status text;
alter table public.orders add column if not exists local_delivery_type text;
alter table public.orders add column if not exists local_assigned_date date;
alter table public.orders add column if not exists local_confirmation_status text;
alter table public.orders add column if not exists local_notes text;
alter table public.orders add column if not exists not_for_local_delivery boolean default false;

update public.orders
set not_for_local_delivery = false
where not_for_local_delivery is null;

alter table public.orders
  alter column not_for_local_delivery set default false;

create index if not exists idx_orders_local_driver_status
  on public.orders (local_driver_id, local_delivery_status);

create index if not exists idx_orders_local_delivery_type
  on public.orders (local_delivery_type);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'orders_local_driver_id_fkey'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
      add constraint orders_local_driver_id_fkey
      foreign key (local_driver_id) references public.local_drivers(id)
      on delete set null;
  end if;
end $$;

commit;
