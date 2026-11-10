-- UniBuddy: split 1% buyer + 1% seller commission, payment ledger and payout tracking.
-- Run after supabase/schema.sql. Amounts are PHP decimal amounts; production payment
-- adapters should calculate in integer centavos and store verified provider references.

alter table public.orders
  add column if not exists buyer_fee_php numeric(12,2) not null default 0,
  add column if not exists seller_fee_php numeric(12,2) not null default 0,
  add column if not exists platform_revenue_php numeric(12,2) not null default 0,
  add column if not exists seller_net_php numeric(12,2) not null default 0,
  add column if not exists provider text,
  add column if not exists provider_payment_id text,
  add column if not exists paid_at timestamptz,
  add column if not exists refunded_at timestamptz;

alter table public.order_items
  add column if not exists buyer_fee_php numeric(12,2) not null default 0,
  add column if not exists platform_revenue_php numeric(12,2) not null default 0;

create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  order_id uuid references public.orders(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(provider, provider_event_id)
);

create table if not exists public.seller_payouts (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id),
  order_id uuid not null references public.orders(id),
  gross_php numeric(12,2) not null,
  seller_fee_php numeric(12,2) not null,
  net_php numeric(12,2) not null,
  provider text not null,
  provider_payout_id text,
  status text not null default 'pending' check (status in ('pending','processing','paid','failed','reversed')),
  scheduled_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique(order_id, seller_id)
);

alter table public.payment_events enable row level security;
alter table public.seller_payouts enable row level security;
-- No client write policies: trusted Edge Functions/service role only.
create policy "seller reads own payout rows" on public.seller_payouts
  for select to authenticated using (seller_id = auth.uid());

create index if not exists idx_products_seller_active on public.products(seller_id,is_active);
create index if not exists idx_messages_conversation_created on public.messages(conversation_id,created_at);
create index if not exists idx_orders_buyer_created on public.orders(buyer_id,created_at desc);
create index if not exists idx_payouts_seller_status on public.seller_payouts(seller_id,status);

-- Server-side formula: round each side to centavos independently.
-- buyer_fee = round(subtotal * 0.01, 2)
-- seller_fee = round(subtotal * 0.01, 2)
-- buyer_total = subtotal + buyer_fee
-- seller_net = subtotal - seller_fee
-- platform_revenue = buyer_fee + seller_fee
-- Shipping/tax are excluded from the commission base unless UniBuddy explicitly changes policy.

create or replace function public.calculate_split_commission(subtotal_centavos bigint)
returns table (
  buyer_fee_centavos bigint,
  seller_fee_centavos bigint,
  buyer_total_centavos bigint,
  seller_net_centavos bigint,
  platform_revenue_centavos bigint
)
language plpgsql immutable as $$
begin
  if subtotal_centavos is null or subtotal_centavos < 0 then
    raise exception 'subtotal_centavos must be a non-negative integer';
  end if;
  buyer_fee_centavos := round(subtotal_centavos * 0.01)::bigint;
  seller_fee_centavos := round(subtotal_centavos * 0.01)::bigint;
  buyer_total_centavos := subtotal_centavos + buyer_fee_centavos;
  seller_net_centavos := subtotal_centavos - seller_fee_centavos;
  platform_revenue_centavos := buyer_fee_centavos + seller_fee_centavos;
  return next;
end;
$$;
revoke all on function public.calculate_split_commission(bigint) from public;
grant execute on function public.calculate_split_commission(bigint) to authenticated;
