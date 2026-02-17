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
} from "./onboard-auth.js";
import {
  NVIDIA_MODEL_CATALOG,
  NVIDIA_DEFAULT_MODEL_REF,
} from "./nvidia-models.js";

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

  // Prompt user to select a model from the catalog
  const modelChoices = NVIDIA_MODEL_CATALOG.map((model) => ({
    value: model.id,
    label: model.name,
  }));

  const selectedModel = await params.prompter.select({
    message: "Select NVIDIA model",
    options: modelChoices,
    initialValue: NVIDIA_DEFAULT_MODEL_REF,
  });

  nextConfig = applyAuthProfileConfig(nextConfig, {
    profileId: "nvidia:default",
    provider: "nvidia",
    mode: "api_key",
  });

  {
    // Apply the provider configuration with all models
    nextConfig = applyNvidiaProviderConfig(nextConfig);
    
    // Set the selected model as the default
    nextConfig = applyNvidiaConfig(nextConfig);
    
    // Override with the specific model the user selected
    await noteAgentModel(String(selectedModel));
    agentModelOverride = String(selectedModel);
  }

  return { config: nextConfig, agentModelOverride };
}
