#!/bin/bash
# OpenClaw + Athena + NVIDIA Complete Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | bash
# Or with sudo: curl -fsSL ... | sudo bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${INSTALL_DIR:-/opt}"
OPENCLAW_DIR="${INSTALL_DIR}/openclaw"
ATHENA_DIR="${INSTALL_DIR}/athena"
# Default repos - can be overridden via environment variables
OPENCLAW_REPO="${OPENCLAW_REPO:-https://github.com/openclaw/openclaw.git}"
ATHENA_REPO="${ATHENA_REPO:-https://github.com/winstonkoh87/Athena-Public.git}"
MODIFICATIONS_REPO="${MODIFICATIONS_REPO:-https://github.com/AshishOP/openclaw-athena.git}"
NVIDIA_API_KEY="${NVIDIA_API_KEY:-}"

# Logging
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        warn "Not running as root. Some operations may fail."
        warn "Consider running with sudo for system-wide installation."
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
    log "Detected OS: $OS"
}

# Install system dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        apt-get update
        apt-get install -y \
            curl \
            wget \
            git \
            python3 \
            python3-pip \
            python3-venv \
            nodejs \
            npm \
            build-essential \
            pkg-config \
            libsqlite3-dev \
            || error "Failed to install dependencies"
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]] || [[ "$OS" == "fedora" ]]; then
        yum update -y
        yum install -y \
            curl \
            wget \
            git \
            python3 \
            python3-pip \
            nodejs \
            npm \
            gcc \
            gcc-c++ \
            make \
            sqlite-devel \
            || error "Failed to install dependencies"
    elif [[ "$OS" == "cachyos" ]] || [[ "$OS" == "arch" ]] || [[ "$OS" == "manjaro" ]]; then
        log "Arch-based system detected. Installing dependencies with pacman..."
        pacman -Sy --noconfirm --needed \
            curl \
            wget \
            git \
            python \
            python-pip \
            python-venv \
            nodejs \
            npm \
            gcc \
            make \
            sqlite \
            || error "Failed to install dependencies"
    elif [[ "$OS" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            error "Homebrew not found. Please install Homebrew first."
        fi
        brew install \
            git \
            python3 \
            node \
            npm \
            || error "Failed to install dependencies"
    else
        warn "Unknown OS. Attempting to continue with existing dependencies..."
    fi
    
    success "System dependencies installed"
}

# Install Node.js 22+
install_nodejs() {
    log "Checking Node.js version..."
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$NODE_VERSION" -ge 22 ]]; then
            success "Node.js $(node --version) already installed"
            return
        fi
    fi
    
    log "Installing Node.js 22+..."
    
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt-get install -y nodejs
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]] || [[ "$OS" == "fedora" ]]; then
        curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
        yum install -y nodejs
    elif [[ "$OS" == "macos" ]]; then
        brew install node@22
    fi
    
    success "Node.js $(node --version) installed"
}

# Install pnpm
install_pnpm() {
    log "Installing pnpm..."
    
    if command -v pnpm &> /dev/null; then
        success "pnpm $(pnpm --version) already installed"
        return
    fi
    
    npm install -g pnpm
    success "pnpm installed"
}

# Setup Athena (LIGHTWEIGHT - only MCP server deps)
setup_athena() {
    log "Setting up Athena (Lightweight - MCP Server Only)..."
    
    if [[ -d "$ATHENA_DIR" ]]; then
        warn "Athena directory already exists at $ATHENA_DIR"
        warn "Backing up existing installation..."
        mv "$ATHENA_DIR" "${ATHENA_DIR}.backup.$(date +%s)"
    fi
    
    log "Cloning Athena from $ATHENA_REPO..."
    git clone "$ATHENA_REPO" "$ATHENA_DIR"
    
    cd "$ATHENA_DIR"
    
    # For Arch-based systems, use virtual environment due to PEP 668
    if [[ "$OS" == "cachyos" ]] || [[ "$OS" == "arch" ]] || [[ "$OS" == "manjaro" ]]; then
        log "Arch-based system detected. Creating virtual environment for Athena..."
        python3 -m venv "$ATHENA_DIR/venv"
        source "$ATHENA_DIR/venv/bin/activate"
        
        # Install LIGHTWEIGHT dependencies only (no torch, no heavy ML deps!)
        log "Installing LIGHTWEIGHT Athena dependencies (no PyTorch)..."
        pip install \
            fastmcp \
            python-dotenv \
            pydantic \
            requests \
            uvicorn \
            httpx \
            || error "Failed to install lightweight Athena dependencies"
        
        # Create activation script for systemd/service
        cat > "$ATHENA_DIR/activate-venv.sh" << EOF
#!/bin/bash
source ${ATHENA_DIR}/venv/bin/activate
export PYTHONPATH=${ATHENA_DIR}/src
exec python -m athena.mcp_server "\$@"
EOF
        chmod +x "$ATHENA_DIR/activate-venv.sh"
    else
        # Install LIGHTWEIGHT dependencies only (no torch, no heavy ML deps!)
        log "Installing LIGHTWEIGHT Athena dependencies (no PyTorch)..."
        pip3 install \
            fastmcp \
            python-dotenv \
            pydantic \
            requests \
            uvicorn \
            httpx \
            || error "Failed to install lightweight Athena dependencies"
    fi
    
    # Create necessary directories
    mkdir -p "$ATHENA_DIR/.context/memories/session_logs"
    mkdir -p "$ATHENA_DIR/.context/memory_bank"
    
    # Create Athena environment file
    cat > "$ATHENA_DIR/.env" << EOF
# Athena Configuration (Lightweight Mode)
ATHENA_MODE=local
ATHENA_LOCAL_DB_PATH=${ATHENA_DIR}/.context/vectorstore
PYTHONPATH=${ATHENA_DIR}/src
EOF
    
    # Create directories for local storage
    mkdir -p "$ATHENA_DIR/.context/vectorstore"
    
    success "Athena (Lightweight) installed at $ATHENA_DIR"
}

# Setup OpenClaw
setup_openclaw() {
    log "Setting up OpenClaw..."
    
    if [[ -d "$OPENCLAW_DIR" ]]; then
        warn "OpenClaw directory already exists at $OPENCLAW_DIR"
        warn "Backing up existing installation..."
        mv "$OPENCLAW_DIR" "${OPENCLAW_DIR}.backup.$(date +%s)"
    fi
    
    log "Cloning OpenClaw from $OPENCLAW_REPO..."
    git clone "$OPENCLAW_REPO" "$OPENCLAW_DIR"
    
    cd "$OPENCLAW_DIR"
    
    # Get the directory where this install script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    log "Installing OpenClaw dependencies..."
    pnpm install
    
# Clone and apply our modifications (NVIDIA + MCP)
  log "Cloning modifications from $MODIFICATIONS_REPO..."
  MODS_TEMP_DIR=$(mktemp -d)
  git clone --depth 1 "$MODIFICATIONS_REPO" "$MODS_TEMP_DIR"

  if [[ -d "$MODS_TEMP_DIR/modifications" ]]; then
    log "Applying OpenClaw modifications..."

    # Copy modified command files
    if [[ -d "$MODS_TEMP_DIR/modifications/openclaw-src/commands" ]]; then
      cp -r "$MODS_TEMP_DIR/modifications/openclaw-src/commands/"* "$OPENCLAW_DIR/src/commands/"
      log "Applied command modifications"
    fi

    # Copy modified ACP files
    if [[ -d "$MODS_TEMP_DIR/modifications/openclaw-src/acp" ]]; then
      cp -r "$MODS_TEMP_DIR/modifications/openclaw-src/acp/"* "$OPENCLAW_DIR/src/acp/"
      log "Applied ACP modifications"
    fi

    # Copy MCP client plugin
    if [[ -d "$MODS_TEMP_DIR/modifications/openclaw-extensions/mcp-client" ]]; then
      rm -rf "$OPENCLAW_DIR/extensions/mcp-client"
      cp -r "$MODS_TEMP_DIR/modifications/openclaw-extensions/mcp-client" "$OPENCLAW_DIR/extensions/"
      log "Applied MCP client plugin"

      # Install MCP plugin dependencies
      log "Installing MCP client plugin dependencies..."
      cd "$OPENCLAW_DIR/extensions/mcp-client"
      pnpm install
      cd "$OPENCLAW_DIR"
    fi

    # Cleanup
    rm -rf "$MODS_TEMP_DIR"

    success "Modifications applied"
  else
    warn "No modifications directory found in $MODIFICATIONS_REPO"
  fi
    
    # Build OpenClaw
    log "Building OpenClaw..."
    pnpm build
    
    # Create environment file
    cat > "$OPENCLAW_DIR/.env" << EOF
# OpenClaw Configuration
NODE_ENV=production
OPENCLAW_GATEWAY_PORT=18789
ATHENA_PATH=${ATHENA_DIR}
NVIDIA_API_KEY=${NVIDIA_API_KEY}
EOF

    # Create minimal config for gateway
    mkdir -p ~/.openclaw
    echo '{"gateway":{"mode":"local"}}' > ~/.openclaw/openclaw.json
    
    success "OpenClaw installed at $OPENCLAW_DIR"
}

# Apply NVIDIA modifications to OpenClaw
apply_nvidia_modifications() {
    log "Applying NVIDIA modifications to OpenClaw..."
    
    # Check if modifications already exist
    if grep -q "nvidia-api-key" "$OPENCLAW_DIR/src/commands/onboard-types.ts" 2>/dev/null; then
        warn "NVIDIA modifications appear to already be applied"
        return
    fi
    
    log "Creating NVIDIA modifications..."
    
    # Create the modifications directory
    mkdir -p "$OPENCLAW_DIR/nvidia-modifications"
    
    # Create auth-choice.apply.nvidia.ts
    cat > "$OPENCLAW_DIR/src/commands/auth-choice.apply.nvidia.ts" << 'NVIDIAAUTH'
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
NVIDIAAUTH

    # Modify onboard-auth.config-core.ts to add NVIDIA functions
    if ! grep -q "applyNvidiaConfig" "$OPENCLAW_DIR/src/commands/onboard-auth.config-core.ts"; then
        # Add NVIDIA_BASE_URL and functions
        sed -i '1a\
export const NVIDIA_BASE_URL = "https://integrate.api.nvidia.com/v1";\
export const NVIDIA_DEFAULT_MODEL_ID = "nvidia/llama-3.1-nemotron-70b-instruct";\
export const NVIDIA_DEFAULT_MODEL_REF = "nvidia/llama-3.1-nemotron-70b-instruct";\
\
export function applyNvidiaProviderConfig(cfg: OpenClawConfig): OpenClawConfig {\
  return cfg;\
}\
\
export function applyNvidiaConfig(cfg: OpenClawConfig): OpenClawConfig {\
  return cfg;\
}\
' "$OPENCLAW_DIR/src/commands/onboard-auth.config-core.ts" 2>/dev/null || true
    fi
    
    success "NVIDIA modifications applied"
}

# Setup MCP client plugin
setup_mcp_plugin() {
    log "Setting up MCP client plugin..."
    
    MCP_DIR="$OPENCLAW_DIR/extensions/mcp-client"
    
    if [[ -d "$MCP_DIR" ]]; then
        warn "MCP client plugin already exists"
        return
    fi
    
    mkdir -p "$MCP_DIR/src"
    
    # Create package.json
    cat > "$MCP_DIR/package.json" << 'MCPPACKAGE'
{
  "name": "@openclaw/mcp-client",
  "version": "2026.2.16",
  "description": "MCP client plugin for OpenClaw - connects to Athena",
  "type": "module",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.4",
    "zod": "^4.3.6"
  },
  "devDependencies": {
    "openclaw": "workspace:*"
  },
  "openclaw": {
    "extensions": [
      "./index.ts"
    ]
  }
}
MCPPACKAGE

    # Create client.ts
    cat > "$MCP_DIR/src/client.ts" << 'MCPCLIENT'
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import type { Tool } from "@modelcontextprotocol/sdk/types.js";
import type { AnyAgentTool } from "openclaw/plugin-sdk";

export type McpServerConfig = {
  name: string;
  command: string;
  args?: string[];
  env?: Record<string, string>;
  cwd?: string;
};

export class McpClientManager {
  private clients: Map<string, Client> = new Map();
  private transports: Map<string, StdioClientTransport> = new Map();
  private tools: Map<string, Tool[]> = new Map();
  private logger: { info: (msg: string) => void; error: (msg: string) => void };

  constructor(logger: { info: (msg: string) => void; error: (msg: string) => void }) {
    this.logger = logger;
  }

  async connectServer(config: McpServerConfig): Promise<void> {
    if (this.clients.has(config.name)) {
      this.logger.info(`MCP server '${config.name}' already connected`);
      return;
    }

    this.logger.info(`Connecting to MCP server: ${config.name}`);

    const transport = new StdioClientTransport({
      command: config.command,
      args: config.args || [],
      env: config.env,
      cwd: config.cwd,
    });

    const client = new Client(
      { name: "openclaw-mcp-client", version: "1.0.0" },
      { capabilities: {} }
    );

    try {
      await client.connect(transport);
      const toolsResult = await client.listTools();
      const availableTools = toolsResult.tools || [];
      
      this.tools.set(config.name, availableTools);
      this.clients.set(config.name, client);
      this.transports.set(config.name, transport);

      this.logger.info(`Connected to '${config.name}' with ${availableTools.length} tools`);
    } catch (error) {
      this.logger.error(`Failed to connect to MCP server '${config.name}': ${error}`);
      throw error;
    }
  }

  async disconnectServer(name: string): Promise<void> {
    const client = this.clients.get(name);
    if (client) {
      await client.close();
      this.clients.delete(name);
      this.transports.delete(name);
      this.tools.delete(name);
      this.logger.info(`Disconnected from MCP server: ${name}`);
    }
  }

  async disconnectAll(): Promise<void> {
    for (const [name, client] of this.clients) {
      await client.close();
      this.logger.info(`Disconnected from MCP server: ${name}`);
    }
    this.clients.clear();
    this.transports.clear();
    this.tools.clear();
  }

  getAllTools(): Array<{ server: string; tool: Tool }> {
    const result: Array<{ server: string; tool: Tool }> = [];
    for (const [server, tools] of this.tools) {
      for (const tool of tools) {
        result.push({ server, tool });
      }
    }
    return result;
  }

  async callTool(serverName: string, toolName: string, args: Record<string, unknown>): Promise<unknown> {
    const client = this.clients.get(serverName);
    if (!client) {
      throw new Error(`MCP server '${serverName}' not connected`);
    }
    this.logger.info(`Calling MCP tool: ${serverName}/${toolName}`);
    const result = await client.callTool({ name: toolName, arguments: args });
    return result;
  }

  isConnected(serverName: string): boolean {
    return this.clients.has(serverName);
  }
}
MCPCLIENT

    # Create index.ts with all 9 Athena tools
    cat > "$MCP_DIR/index.ts" << 'MCPINDEX'
import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
import { emptyPluginConfigSchema } from "openclaw/plugin-sdk";
import { McpClientManager } from "./src/client.js";

let mcpManager: McpClientManager | null = null;

function getMcpManager(logger: { info: (msg: string) => void; error: (msg: string) => void }): McpClientManager {
  if (!mcpManager) {
    mcpManager = new McpClientManager(logger);
  }
  return mcpManager;
}

const plugin = {
  id: "mcp-client",
  name: "MCP Client",
  description: "Connect to MCP servers (Athena) and use their tools",
  configSchema: emptyPluginConfigSchema(),
  
  register(api: OpenClawPluginApi) {
    const logger = api.logger;
    const manager = getMcpManager(logger);

    const athenaConfig = {
      name: "athena",
      command: "python",
      args: ["-m", "athena.mcp_server"],
      cwd: process.env.ATHENA_PATH || "/opt/athena",
      env: { ...process.env, PYTHONPATH: process.env.ATHENA_PATH || "/opt/athena/src" },
    };

    // 1. Smart Search
    api.registerTool(() => ({
      name: "athena_smart_search",
      description: "Search Athena's memory using hybrid RAG (vector + keyword + graph)",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string", description: "Search query" },
          limit: { type: "number", default: 5 },
        },
        required: ["query"],
      },
      async execute(params: { query: string; limit?: number }) {
        try {
          if (!manager.isConnected("athena")) await manager.connectServer(athenaConfig);
          const result = await manager.callTool("athena", "smart_search", params);
          return JSON.stringify(result, null, 2);
        } catch (error) {
          return `Error: ${error}`;
        }
      },
    }));

    // 2. Agentic Search
    api.registerTool(() => ({
      name: "athena_agentic_search",
      description: "Multi-step query decomposition with parallel search",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string", description: "Complex search query" },
          limit: { type: "number", default: 5 },
        },
        required: ["query"],
      },
      async execute(params: { query: string; limit?: number }) {
        try {
          if (!manager.isConnected("athena")) await manager.connectServer(athenaConfig);
          const result = await manager.callTool("athena", "agentic_search", params);
          return JSON.stringify(result, null, 2);
        } catch (error) {
          return `Error: ${error}`;
        }
      },
    }));

    // 3. Quicksave
    api.registerTool(() => ({
      name: "athena_quicksave",
      description: "Save a checkpoint to Athena's session log",
      parameters: {
        type: "object",
        properties: { summary: { type: "string", description: "Summary to save" } },
        required: ["summary"],
      },
      async execute(params: { summary: string }) {
        try {
          if (!manager.isConnected("athena")) await manager.connectServer(athenaConfig);
          await manager.callTool("athena", "quicksave", params);
          return "✅ Session saved to Athena memory";
        } catch (error) {
          return `Error: ${error}`;
        }
      },
    }));

    // 4. Recall Session
    api.registerTool(() => ({
      name: "athena_recall_session",
      description: "Recall recent session log content",
      parameters: {
        type: "object",
        properties: { limit: { type: "number", default: 1 } },
      },
      async execute(params: { limit?: number }) {
        try {
          if (!manager.isConnected("athena")) await manager.connectServer(athenaConfig);
          const result = await manager.callTool("athena", "recall_session", params);
          return JSON.stringify(result, null, 2);
        } catch (error) {
          return `Error: ${error}`;
        }
      },
    }));

    // 5. Health Check
    api.registerTool(() => ({
      name: "athena_health_check",
      description: "Check Athena system health",
      parameters: { type: "object", properties: {} },
      async execute() {
        try {
          if (!manager.isConnected("athena")) await manager.connectServer(athenaConfig);
          const result = await manager.callTool("athena", "health_check", {});
          return JSON.stringify(result, null, 2);
        } catch (error) {
          return `Error: ${error}`;
        }
      },
    }));

    // 6. Governance Status
    api.registerTool(() => ({
      name: "athena_governance_status",
      description: "Check Triple-Lock compliance state",
      parameters: { type: "object", properties: {} },
      async execute() {
        try {
          if (!manager.isConnected("athena")) await manager.connectServer(athenaConfig);
          const result = await manager.callTool("athena", "governance_status", {});
          return JSON.stringify(result, null, 2);
        } catch (error) {
          return `Error: ${error}`;
        }
      },
    }));

    // 7. List Memory Paths
    api.registerTool(() => ({
      name: "athena_list_memory_paths",
      description: "List active memory directories",
      parameters: { type: "object", properties: {} },
      async execute() {
        try {
          if (!manager.isConnected("athena")) await manager.connectServer(athenaConfig);
          const result = await manager.callTool("athena", "list_memory_paths", {});
          return JSON.stringify(result, null, 2);
        } catch (error) {
          return `Error: ${error}`;
        }
      },
    }));

    // 8. Set Secret Mode
    api.registerTool(() => ({
      name: "athena_set_secret_mode",
      description: "Toggle secret/demo mode (redacts sensitive content)",
      parameters: {
        type: "object",
        properties: { enabled: { type: "boolean" } },
        required: ["enabled"],
      },
      async execute(params: { enabled: boolean }) {
        try {
          if (!manager.isConnected("athena")) await manager.connectServer(athenaConfig);
          await manager.callTool("athena", "set_secret_mode", params);
          return params.enabled ? "🔒 Secret mode enabled" : "🔓 Secret mode disabled";
        } catch (error) {
          return `Error: ${error}`;
        }
      },
    }));

    // 9. Permission Status
    api.registerTool(() => ({
      name: "athena_permission_status",
      description: "Show access state and tool manifest",
      parameters: { type: "object", properties: {} },
      async execute() {
        try {
          if (!manager.isConnected("athena")) await manager.connectServer(athenaConfig);
          const result = await manager.callTool("athena", "permission_status", {});
          return JSON.stringify(result, null, 2);
        } catch (error) {
          return `Error: ${error}`;
        }
      },
    }));

    api.on("gateway_stop", async () => {
      if (mcpManager) {
        await mcpManager.disconnectAll();
        mcpManager = null;
      }
    });

    logger.info("MCP Client plugin registered (9 Athena tools)");
  },
};

export default plugin;
MCPINDEX

    success "MCP client plugin created at $MCP_DIR"
}

# Create systemd services (or supervisord for containers)
create_services() {
    log "Creating service configurations..."
    
    # Check if systemd is available
    if command -v systemctl &> /dev/null; then
        log "Creating systemd services..."
        
        # Determine Athena Python command based on OS
        if [[ "$OS" == "cachyos" ]] || [[ "$OS" == "arch" ]] || [[ "$OS" == "manjaro" ]]; then
            ATHENA_PYTHON_CMD="${ATHENA_DIR}/activate-venv.sh"
        else
            ATHENA_PYTHON_CMD="/usr/bin/python3"
        fi
        
        # Athena MCP service
        cat > /etc/systemd/system/athena-mcp.service << EOF
[Unit]
Description=Athena MCP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${ATHENA_DIR}
Environment=PYTHONPATH=${ATHENA_DIR}/src
Environment=ATHENA_MODE=local
Environment=ATHENA_LOCAL_DB_PATH=${ATHENA_DIR}/.context/vectorstore
ExecStart=${ATHENA_PYTHON_CMD}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        # OpenClaw service
        cat > /etc/systemd/system/openclaw.service << EOF
[Unit]
Description=OpenClaw AI Agent
After=network.target athena-mcp.service
Wants=athena-mcp.service

[Service]
Type=simple
User=root
WorkingDirectory=${OPENCLAW_DIR}
Environment=NODE_ENV=production
Environment=ATHENA_PATH=${ATHENA_DIR}
Environment=OPENCLAW_GATEWAY_PORT=18789
ExecStart=/usr/bin/node ${OPENCLAW_DIR}/openclaw.mjs gateway run --bind 0.0.0.0 --port 18789
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        success "Systemd services created"
        
    else
        # Create supervisord config for containers
        log "Systemd not available. Creating supervisord configuration..."
        
        mkdir -p /etc/supervisor/conf.d
        
        # Determine Athena Python command based on OS
        if [[ "$OS" == "cachyos" ]] || [[ "$OS" == "arch" ]] || [[ "$OS" == "manjaro" ]]; then
            ATHENA_SUPERVISOR_CMD="${ATHENA_DIR}/activate-venv.sh"
        else
            ATHENA_SUPERVISOR_CMD="python3 -m athena.mcp_server"
        fi
        
        cat > /etc/supervisor/conf.d/athena.conf << EOF
[program:athena-mcp]
command=${ATHENA_SUPERVISOR_CMD}
directory=${ATHENA_DIR}
environment=PYTHONPATH="${ATHENA_DIR}/src",ATHENA_MODE="local",ATHENA_LOCAL_DB_PATH="${ATHENA_DIR}/.context/vectorstore"
autostart=true
autorestart=true
stderr_logfile=/var/log/athena.err.log
stdout_logfile=/var/log/athena.out.log
EOF

        cat > /etc/supervisor/conf.d/openclaw.conf << EOF
[program:openclaw]
command=node ${OPENCLAW_DIR}/openclaw.mjs gateway run --bind 0.0.0.0 --port 18789
directory=${OPENCLAW_DIR}
environment=NODE_ENV="production",ATHENA_PATH="${ATHENA_DIR}",OPENCLAW_GATEWAY_PORT="18789"
autostart=true
autorestart=true
stderr_logfile=/var/log/openclaw.err.log
stdout_logfile=/var/log/openclaw.out.log
EOF

        success "Supervisord configuration created"
    fi
}

# Create helper scripts
create_helper_scripts() {
    log "Creating helper scripts..."
    
    # Start script
    cat > "$OPENCLAW_DIR/start.sh" << EOF
#!/bin/bash
# Start OpenClaw and Athena

export ATHENA_PATH=${ATHENA_DIR}
export NVIDIA_API_KEY=${NVIDIA_API_KEY}

echo "Starting Athena MCP Server..."
cd ${ATHENA_DIR}

if [[ -f "${ATHENA_DIR}/activate-venv.sh" ]]; then
    # Arch-based system - use virtual environment
    ${ATHENA_DIR}/activate-venv.sh &
else
    # Other systems - use system python
    python3 -m athena.mcp_server &
fi
ATHENA_PID=\$!

echo "Starting OpenClaw..."
cd ${OPENCLAW_DIR}
node openclaw.mjs gateway run --bind 0.0.0.0 --port 18789 &
OPENCLAW_PID=\$!

echo "Services started!"
echo "Athena PID: \$ATHENA_PID"
echo "OpenClaw PID: \$OPENCLAW_PID"
echo ""
echo "Access OpenClaw at: http://localhost:18789"
echo ""
echo "To stop, run: kill \$ATHENA_PID \$OPENCLAW_PID"
EOF
    chmod +x "$OPENCLAW_DIR/start.sh"
    
    # Stop script
    cat > "$OPENCLAW_DIR/stop.sh" << EOF
#!/bin/bash
# Stop OpenClaw and Athena

pkill -f "athena.mcp_server" || true
pkill -f "openclaw" || true

echo "Services stopped"
EOF
    chmod +x "$OPENCLAW_DIR/stop.sh"
    
    # Test script
    cat > "$OPENCLAW_DIR/test.sh" << 'EOF'
#!/bin/bash
# Test OpenClaw + Athena integration

echo "Testing OpenClaw + Athena..."
echo ""

# Test NVIDIA
echo "1. Testing NVIDIA provider..."
if openclaw models list 2>/dev/null | grep -q nvidia; then
    echo "✅ NVIDIA models available"
else
    echo "⚠️  NVIDIA models not found (set NVIDIA_API_KEY)"
fi

# Test MCP tools
echo ""
echo "2. Testing Athena MCP tools..."
if openclaw tools list 2>/dev/null | grep -q athena; then
    echo "✅ Athena tools available:"
    openclaw tools list 2>/dev/null | grep athena | sed 's/^/   - /'
else
    echo "❌ Athena tools not found"
fi

# Test Athena health
echo ""
echo "3. Testing Athena health..."
if openclaw tools call athena_health_check 2>/dev/null; then
    echo "✅ Athena responding"
else
    echo "❌ Athena not responding"
fi

echo ""
echo "Test complete!"
EOF
    chmod +x "$OPENCLAW_DIR/test.sh"
    
    success "Helper scripts created"
}

# Final setup and instructions
finalize() {
    log "Finalizing installation..."
    
    # Set permissions
    chmod -R 755 "$OPENCLAW_DIR" "$ATHENA_DIR"
    
    # Create symlinks for easy access
    ln -sf "$OPENCLAW_DIR/start.sh" /usr/local/bin/openclaw-start 2>/dev/null || true
    ln -sf "$OPENCLAW_DIR/stop.sh" /usr/local/bin/openclaw-stop 2>/dev/null || true
    ln -sf "$OPENCLAW_DIR/test.sh" /usr/local/bin/openclaw-test 2>/dev/null || true
    
    success "Installation complete!"
    
    echo ""
    echo "========================================"
    echo "🎉 OpenClaw + Athena + NVIDIA Setup Complete!"
    echo "========================================"
    echo ""
    echo "Installation Directory: $INSTALL_DIR"
    echo "OpenClaw: $OPENCLAW_DIR"
    echo "Athena: $ATHENA_DIR"
    echo ""
    echo "Quick Start:"
    echo "  cd $OPENCLAW_DIR"
    echo "  ./start.sh          # Start both services"
    echo "  ./stop.sh           # Stop both services"
    echo "  ./test.sh           # Test integration"
    echo ""
    echo "Or use systemd:"
    echo "  systemctl start athena-mcp openclaw"
    echo "  systemctl enable athena-mcp openclaw"
    echo ""
    echo "Access OpenClaw at: http://localhost:18789"
    echo ""
    echo "Available Athena Tools (9 total):"
    echo "  - athena_smart_search      : Search memory with RAG"
    echo "  - athena_agentic_search    : Multi-step query decomposition"
    echo "  - athena_quicksave         : Save session checkpoint"
    echo "  - athena_recall_session    : Read session logs"
    echo "  - athena_health_check      : System health check"
    echo "  - athena_governance_status : Check compliance"
    echo "  - athena_list_memory_paths : List memory directories"
    echo "  - athena_set_secret_mode   : Toggle demo mode"
    echo "  - athena_permission_status : Show access state"
    echo ""
    echo "Test with NVIDIA:"
    echo "  openclaw onboard --auth-choice nvidia-api-key"
    echo ""
    echo "========================================"
}

# Main installation flow
main() {
    log "Starting OpenClaw + Athena + NVIDIA installation..."
    
    check_root
    detect_os
    install_dependencies
    install_nodejs
    install_pnpm
    setup_athena
    setup_openclaw
    setup_mcp_plugin
    create_services
    create_helper_scripts
    finalize
    
    success "Installation complete!"
}

# Run main function
main "$@"