-- UniBuddy marketplace starter schema (Supabase/Postgres)
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null default 'both' check (role in ('buyer','seller','both')),
  stripe_account_id text,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  category text not null,
  price_php numeric(12,2) not null check (price_php > 0),
  image_path text,
  stock integer not null default 1 check (stock >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete set null,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(product_id,buyer_id,seller_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id),
  subtotal_php numeric(12,2) not null,
  platform_fee_php numeric(12,2) not null,
  total_php numeric(12,2) not null,
  currency text not null default 'php',
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed','refunded')),
  stripe_session_id text unique,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  seller_id uuid not null references public.profiles(id),
  quantity integer not null check (quantity > 0),
  unit_price_php numeric(12,2) not null,
  platform_fee_php numeric(12,2) not null,
  seller_net_php numeric(12,2) not null
);

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

create policy "profiles readable by authenticated users" on public.profiles for select to authenticated using (true);
create policy "users update own profile" on public.profiles for update to authenticated using (auth.uid()=id) with check (auth.uid()=id);
create policy "users create own profile" on public.profiles for insert to authenticated with check (auth.uid()=id);

create policy "active products public read" on public.products for select using (is_active=true or seller_id=auth.uid());
create policy "seller creates own products" on public.products for insert to authenticated with check (seller_id=auth.uid());
create policy "seller updates own products" on public.products for update to authenticated using (seller_id=auth.uid()) with check (seller_id=auth.uid());
create policy "seller deletes own products" on public.products for delete to authenticated using (seller_id=auth.uid());

create policy "conversation participants read" on public.conversations for select to authenticated using (buyer_id=auth.uid() or seller_id=auth.uid());
create policy "buyer creates conversation" on public.conversations for insert to authenticated with check (buyer_id=auth.uid());
create policy "participants read messages" on public.messages for select to authenticated using (
  exists(select 1 from public.conversations c where c.id=conversation_id and (c.buyer_id=auth.uid() or c.seller_id=auth.uid()))
);
create policy "participant sends message" on public.messages for insert to authenticated with check (
  sender_id=auth.uid() and exists(select 1 from public.conversations c where c.id=conversation_id and (c.buyer_id=auth.uid() or c.seller_id=auth.uid()))
);
create policy "buyer reads own orders" on public.orders for select to authenticated using (buyer_id=auth.uid());
create policy "buyer reads own order items" on public.order_items for select to authenticated using (
  exists(select 1 from public.orders o where o.id=order_id and o.buyer_id=auth.uid())
);

-- Production note: create orders/order_items only through a trusted Edge Function or
-- tightly controlled database function. Never let a client set its own paid status,
-- commission, seller payout, or Stripe identifiers.
