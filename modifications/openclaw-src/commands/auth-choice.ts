export { applyAuthChoice, type ApplyAuthChoiceParams, type ApplyAuthChoiceResult } from "./auth-choice.apply.js";
export { resolvePreferredProviderForAuthChoice } from "./auth-choice.preferred-provider.js";
export { applyNonInteractiveAuthChoice } from "./onboard-non-interactive/local/auth-choice.js";

export async function warnIfModelConfigLooksOff(): Promise<void> {
  // This is a no-op stub - original implementation not needed for basic auth
}
