# UniBuddy Marketplace

A GitHub Pages-friendly marketplace prototype with product listings, buyer/seller messaging UI, cart, simulated checkout, and a 1% buyer + 1% seller commission model.

## Commission policy

Commission is calculated on the item subtotal only:

- Buyer pays an additional 1% platform fee.
- Seller contributes 1% deducted from the item proceeds.
- UniBuddy earns 2% total.
- Example: ₱1,000 item → buyer pays ₱1,010 before shipping/tax; seller item proceeds are ₱990 before provider fees/refunds/other disclosed deductions; UniBuddy gross commission is ₱20.

## Files

- `index.html`, `styles.css`, `app.js`: responsive browser demo.
- `supabase/schema.sql`: database tables and baseline RLS policies.
- `supabase/migrations/20261110_split_commission_and_payouts.sql`: split commission fields, payment event idempotency, seller payout ledger, and server-side calculation function.
- `supabase/functions/_shared/commission.ts`: integer-centavo calculation helper.
- `supabase/functions/create-checkout/index.ts`: authenticated, fail-closed checkout scaffold. It deliberately does not charge money until PayMongo confirms marketplace/Platforms access and its current API contract is implemented.
- `PAYMENTS-PH.md`: Philippine provider and live-launch checklist.

## Run the demo

Open `index.html` in a browser or run:

```bash
python -m http.server 8000
```

Visit `http://localhost:8000`.

## Publish the prototype

1. Create a GitHub repository and upload the contents of this folder to its root.
2. Go to **Settings → Pages**.
3. Select **Deploy from a branch**, choose `main` and `/ (root)`, then save.

GitHub Pages is for the static prototype only. Do not use it as the host for a live commercial e-commerce service or sensitive transactions. Host the live app on an appropriate application platform.

## Production backend

The browser app still uses `localStorage` for sample users, listings, messages, carts, and simulated orders. It is not yet a live multi-user marketplace. The SQL/backend structure is a starting point, not a fully deployed production service.

Recommended stack:
- Supabase Auth for real user accounts.
- Supabase Postgres with RLS for products, orders, conversations, and messages.
- Supabase Realtime for cross-device buyer/seller chat.
- Supabase Storage for product images.
- PayMongo Platforms (subject to approval and onboarding) for marketplace payments and split payouts in the Philippines.

Read `PAYMENTS-PH.md` before implementing live checkout. Never commit provider secrets, Supabase service-role keys, or webhook secrets. Never trust browser-calculated prices, commission, seller IDs, or payment status. Verify signed provider webhooks, deduplicate event IDs, and reconcile refunds, disputes, inventory, and payouts server-side.

## Automatic payouts

Automatic payout means the payment provider releases the seller's net proceeds according to its settlement and payout schedule after funds clear. It does not mean instant payout. Sellers must complete provider onboarding/KYC and provide eligible payout details.
