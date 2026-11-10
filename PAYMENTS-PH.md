# UniBuddy payments and seller payouts (Philippines)

## Commission policy

For the item subtotal only:

- Buyer fee: 1% added to the buyer's checkout total.
- Seller fee: 1% deducted from the seller's item proceeds.
- UniBuddy gross commission: 2% total.
- Shipping and taxes are excluded from the commission base in this starter. Decide and disclose any change before launch.

For a ₱1,000 item: buyer pays ₱1,010 before shipping/tax; seller's item proceeds are ₱990 before any payment-provider charges, refunds, withholding, or other disclosed deductions; UniBuddy gross commission is ₱20.

## Suggested payment provider path

Because this project is intended for the Philippines, evaluate **PayMongo Platforms** first. Its public product information describes merchant/sub-account onboarding, platform fees, API payment splitting, and payouts. PayMongo also describes automated payouts after funds clear, with payout timing depending on payment method and payout schedule. Marketplace/Platforms access, commercial terms, KYC, eligible business types, supported flows, and API credentials must be confirmed directly with PayMongo before implementation.

- Platforms overview: https://www.paymongo.com/products/platform
- Workflows / split payouts: https://www.paymongo.com/products/fintech-infrastructure/workflows
- Payout timing: https://docs.paymongo.com/docs/money-movement-payouts
- Payment API: https://www.paymongo.com/en-ph/products/accept-payments/payments-api

Do not assume a normal merchant checkout account supports marketplace sub-merchant onboarding or split disbursements. Ask PayMongo for platform/marketplace approval and the current API specification. The previous Stripe Connect sample is not the default choice for a Philippines-based platform; Stripe country and Connect cross-border eligibility must be independently confirmed for the platform entity and each seller country.

## Automatic payout semantics

“Automatic” means the provider automatically releases the seller's net share under its clearing, risk, and payout schedule after successful payment—not instant, guaranteed, or immediate cash-out. Keep payout state (`pending`, `processing`, `paid`, `failed`, `reversed`) and reconcile provider events. Never mark a seller payout paid just because checkout redirected to a success URL.

## Required provider implementation before live money

1. Apply for and receive written confirmation of marketplace/platform product access.
2. Obtain the current official API documentation, sandbox credentials, production credentials, and webhook signing/verification instructions.
3. Complete platform and seller KYC/merchant onboarding using the provider's hosted/approved flow.
4. In a Supabase Edge Function, load authoritative prices and seller IDs from Postgres; never accept totals, fee amounts, or seller bank details from the browser.
5. Create a pending order and unique idempotency key, then request a provider checkout/payment with split instructions: buyer pays item subtotal + 1% buyer fee; seller receives item subtotal less 1% seller fee, subject to provider charges and settlement rules; platform retains both 1% fee components.
6. Verify signed webhooks server-side, deduplicate provider event IDs in `payment_events`, and transition order/payment/payout states transactionally.
7. Handle refunds, partial refunds, chargebacks, disputes, failed transfers, seller account holds, stock reservation/release, and reconciliation.
8. Test sandbox scenarios and obtain legal/accounting review for consumer disclosures, tax, privacy, KYC/AML, and marketplace obligations in the Philippines.

## Secrets

Store provider secrets only in Supabase Edge Function secrets. Never commit `.env`, secret keys, webhook secrets, service-role keys, private API keys, or seller payout credentials to GitHub. Only a publishable/anon client key may be placed in a frontend, and only with strict Row Level Security.

## Current repository state

The browser UI is still a demo frontend using localStorage for sample profiles, products, messages, carts, and simulated orders. SQL tables/migration provide backend structure, but they do not automatically connect the UI to Supabase or activate payments. Do not launch this repository as a live marketplace until authentication, database access, realtime chat, provider split checkout, verified webhooks, and seller payout reconciliation have been implemented and tested.
