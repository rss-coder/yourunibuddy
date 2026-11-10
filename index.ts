// Fail-closed checkout scaffold. Live provider requests are intentionally disabled
// until PayMongo confirms marketplace/Platforms approval and provides the current
// API contract, merchant onboarding flow, and webhook signature specification.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": Deno.env.get("ALLOWED_ORIGIN") ?? "https://YOUR-USERNAME.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, "Content-Type": "application/json" },
});
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization) return json({ error: "Authentication required" }, 401);
    const url = Deno.env.get("SUPABASE_URL");
    const anon = Deno.env.get("SUPABASE_ANON_KEY");
    if (!url || !anon) return json({ error: "Backend is not configured" }, 503);
    const supabase = createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const { data: { user }, error } = await supabase.auth.getUser();
    if (error || !user) return json({ error: "Invalid session" }, 401);
    const body = await req.json().catch(() => null);
    if (!body || typeof body.productId !== "string" || !Number.isInteger(body.quantity) || body.quantity < 1 || body.quantity > 20) {
      return json({ error: "A valid productId and quantity (1–20) are required" }, 400);
    }
    // Verify the product exists and is available before a payment adapter is added.
    const { data: product, error: productError } = await supabase
      .from("products").select("id,seller_id,price_php,stock,is_active")
      .eq("id", body.productId).maybeSingle();
    if (productError) return json({ error: "Could not validate product" }, 500);
    if (!product || !product.is_active || product.stock < body.quantity) return json({ error: "Product unavailable" }, 409);
    const subtotalCentavos = Math.round(Number(product.price_php) * body.quantity * 100);
    const buyerFeeCentavos = Math.round(subtotalCentavos * 0.01);
    const sellerFeeCentavos = Math.round(subtotalCentavos * 0.01);
    return json({
      error: "Live checkout is not enabled. Complete the PayMongo Platforms integration and verified webhook before accepting payments.",
      quote: {
        currency: "PHP", subtotalCentavos, buyerFeeCentavos, sellerFeeCentavos,
        buyerTotalCentavos: subtotalCentavos + buyerFeeCentavos,
        sellerNetCentavos: subtotalCentavos - sellerFeeCentavos,
        platformRevenueCentavos: buyerFeeCentavos + sellerFeeCentavos,
      },
    }, 503);
  } catch {
    return json({ error: "Invalid request" }, 400);
  }
});
