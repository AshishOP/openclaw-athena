import type { ApplyAuthChoiceParams, ApplyAuthChoiceResult } from "./auth-choice.apply.js";
import { resolveEnvApiKey } from "../agents/model-auth.js";
import {
  formatApiKeyPreview,
  normalizeApiKeyInput,
  validateApiKeyInput,
} from "./auth-choice.api-key.js";
import { createAuthChoiceAgentModelNoter } from "./auth-choice.apply-helpers.js";
import { applyDefaultModelChoice } from "./auth-choice.default-model.js";
import {
  applyAuthProfileConfig,
  applyNvidiaConfig,
  applyNvidiaProviderConfig,
  setNvidiaApiKey,
  NVIDIA_DEFAULT_MODEL_REF,
} from "./onboard-auth.js";

export async function applyAuthChoiceNVIDIA(
  params: ApplyAuthChoiceParams,
): Promise<ApplyAuthChoiceResult | null> {
  if (params.authChoice !== "nvidia-api-key") {
    return null;
  }

  let nextConfig = params.config;
  let agentModelOverride: string | undefined;
  const noteAgentModel = createAuthChoiceAgentModelNoter(params);

  let hasCredential = false;
  const optsKey = params.opts?.nvidiaApiKey?.trim();
  if (optsKey) {
    setNvidiaApiKey(normalizeApiKeyInput(optsKey), params.agentDir);
    hasCredential = true;
  }

  if (!hasCredential) {
    const envKey = resolveEnvApiKey("nvidia");
    if (envKey) {
      const useExisting = await params.prompter.confirm({
        message: `Use existing NVIDIA_API_KEY (${envKey.source}, ${formatApiKeyPreview(envKey.apiKey)})?`,
        initialValue: true,
      });
      if (useExisting) {
        setNvidiaApiKey(envKey.apiKey, params.agentDir);
        hasCredential = true;
      }
    }
  }

  if (!hasCredential) {
    const key = await params.prompter.text({
      message: "Enter NVIDIA API key (from build.nvidia.com)",
      validate: validateApiKeyInput,
    });
    setNvidiaApiKey(normalizeApiKeyInput(String(key)), params.agentDir);
  }

  nextConfig = applyAuthProfileConfig(nextConfig, {
    profileId: "nvidia:default",
    provider: "nvidia",
    mode: "api_key",
  });
  {
    const applied = await applyDefaultModelChoice({
      config: nextConfig,
      setDefaultModel: params.setDefaultModel,
      defaultModel: NVIDIA_DEFAULT_MODEL_REF,
      applyDefaultConfig: applyNvidiaConfig,
      applyProviderConfig: applyNvidiaProviderConfig,
      noteDefault: NVIDIA_DEFAULT_MODEL_REF,
      noteAgentModel,
      prompter: params.prompter,
    });
    nextConfig = applied.config;
    agentModelOverride = applied.agentModelOverride ?? agentModelOverride;
  }

  return { config: nextConfig, agentModelOverride };
}