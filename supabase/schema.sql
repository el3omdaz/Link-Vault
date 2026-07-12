-- LinkVault Supabase schema
-- شغّل هذا الملف من Supabase SQL Editor مرة واحدة.

create extension if not exists pgcrypto;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  color text,
  icon text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint categories_name_not_blank check (length(trim(name)) > 0),
  constraint categories_user_name_unique unique (user_id, name)
);

create table if not exists public.links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  url text not null,
  platform text not null default 'Web',
  category_name text not null default 'أخرى',
  notes text,
  trailer_url text,
  thumbnail_url text,
  is_favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint links_title_not_blank check (length(trim(title)) > 0),
  constraint links_url_not_blank check (length(trim(url)) > 0)
);

create index if not exists links_user_created_idx on public.links (user_id, created_at desc);
create index if not exists links_user_category_idx on public.links (user_id, category_name);
create index if not exists categories_user_created_idx on public.categories (user_id, created_at asc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_categories_updated_at on public.categories;
create trigger set_categories_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

drop trigger if exists set_links_updated_at on public.links;
create trigger set_links_updated_at
before update on public.links
for each row execute function public.set_updated_at();

alter table public.categories enable row level security;
alter table public.links enable row level security;

drop policy if exists "categories_select_own" on public.categories;
create policy "categories_select_own" on public.categories
for select using (auth.uid() = user_id);

drop policy if exists "categories_insert_own" on public.categories;
create policy "categories_insert_own" on public.categories
for insert with check (auth.uid() = user_id);

drop policy if exists "categories_update_own" on public.categories;
create policy "categories_update_own" on public.categories
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "categories_delete_own" on public.categories;
create policy "categories_delete_own" on public.categories
for delete using (auth.uid() = user_id);

drop policy if exists "links_select_own" on public.links;
create policy "links_select_own" on public.links
for select using (auth.uid() = user_id);

drop policy if exists "links_insert_own" on public.links;
create policy "links_insert_own" on public.links
for insert with check (auth.uid() = user_id);

drop policy if exists "links_update_own" on public.links;
create policy "links_update_own" on public.links
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "links_delete_own" on public.links;
create policy "links_delete_own" on public.links
for delete using (auth.uid() = user_id);


-- Migration for existing LinkVault databases
alter table public.links add column if not exists is_favorite boolean not null default false;
