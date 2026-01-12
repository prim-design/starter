import Stripe from "stripe";

export function getStripeClient(secretKey: string): Stripe {
  return new Stripe(secretKey, {
    apiVersion: "2025-10-29.clover",
  });
}
