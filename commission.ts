// Monetary math in integer centavos to avoid floating-point currency errors.
export function calculateSplitCommission(subtotalCentavos: number) {
  if (!Number.isSafeInteger(subtotalCentavos) || subtotalCentavos < 0) {
    throw new Error("subtotalCentavos must be a non-negative safe integer");
  }
  const buyerFeeCentavos = Math.round(subtotalCentavos * 0.01);
  const sellerFeeCentavos = Math.round(subtotalCentavos * 0.01);
  return {
    subtotalCentavos, buyerFeeCentavos, sellerFeeCentavos,
    buyerTotalCentavos: subtotalCentavos + buyerFeeCentavos,
    sellerNetCentavos: subtotalCentavos - sellerFeeCentavos,
    platformRevenueCentavos: buyerFeeCentavos + sellerFeeCentavos,
  };
}
