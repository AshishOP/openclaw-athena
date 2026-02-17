// NVIDIA Model Catalog - All available models through NVIDIA API
export const NVIDIA_MODEL_CATALOG = [
  // Base NVIDIA models
  {
    id: "nvidia/llama-3.1-nemotron-70b-instruct",
    name: "NVIDIA Llama 3.1 Nemotron 70B Instruct",
    reasoning: false,
    input: ["text"],
    output: ["text"],
    contextWindow: 131072,
    maxTokens: 4096,
  },
  {
    id: "meta/llama-3.3-70b-instruct",
    name: "Meta Llama 3.3 70B Instruct",
    reasoning: false,
    input: ["text"],
    output: ["text"],
    contextWindow: 131072,
    maxTokens: 4096,
  },
  {
    id: "nvidia/mistral-nemo-minitron-8b-8k-instruct",
    name: "NVIDIA Mistral NeMo Minitron 8B Instruct",
    reasoning: false,
    input: ["text"],
    output: ["text"],
    contextWindow: 8192,
    maxTokens: 2048,
  },
  // KIMI Models (Moonshot AI)
  {
    id: "moonshotai/kimi-k2-instruct",
    name: "KIMI K2 Instruct",
    reasoning: false,
    input: ["text"],
    output: ["text"],
    contextWindow: 131072,
    maxTokens: 4096,
  },
  {
    id: "moonshotai/kimi-k2-instruct-0905",
    name: "KIMI K2 Instruct 0905",
    reasoning: false,
    input: ["text"],
    output: ["text"],
    contextWindow: 131072,
    maxTokens: 4096,
  },
  {
    id: "moonshotai/kimi-k2-thinking",
    name: "KIMI K2 Thinking",
    reasoning: true,
    input: ["text"],
    output: ["text"],
    contextWindow: 131072,
    maxTokens: 4096,
  },
  {
    id: "moonshotai/kimi-k2.5",
    name: "KIMI K2.5",
    reasoning: false,
    input: ["text"],
    output: ["text"],
    contextWindow: 131072,
    maxTokens: 4096,
  },
  // GLM Models (Z.AI)
  {
    id: "z-ai/glm4.7",
    name: "Z.AI GLM-4.7",
    reasoning: false,
    input: ["text"],
    output: ["text"],
    contextWindow: 8192,
    maxTokens: 4096,
  },
  {
    id: "z-ai/glm5",
    name: "Z.AI GLM-5",
    reasoning: false,
    input: ["text"],
    output: ["text"],
    contextWindow: 8192,
    maxTokens: 4096,
  },
  {
    id: "thudm/chatglm3-6b",
    name: "THUDM ChatGLM3 6B",
    reasoning: false,
    input: ["text"],
    output: ["text"],
    contextWindow: 8192,
    maxTokens: 4096,
  },
];

export const NVIDIA_DEFAULT_MODEL_REF = "z-ai/glm5";
export const NVIDIA_DEFAULT_MODEL_ID = "z-ai/glm5";
export const NVIDIA_BASE_URL = "https://integrate.api.nvidia.com/v1";
