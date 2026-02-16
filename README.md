# OpenClaw + Athena + NVIDIA Integration

Complete integration of OpenClaw with Athena memory system and NVIDIA model support.

## 🚀 Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/AshishOP/openclaw-athena/main/install-openclaw.sh | sudo bash
```

Or with NVIDIA API key:
```bash
curl -fsSL https://raw.githubusercontent.com/AshishOP/openclaw-athena/main/install-openclaw.sh | sudo NVIDIA_API_KEY="your-key" bash
```

## 📦 What's Included

### 1. NVIDIA Support in OpenClaw Onboarding
- NVIDIA now appears in `openclaw onboard` interactive wizard
- Full support for `nvidia/llama-3.1-nemotron-70b-instruct` and other models
- API key authentication with environment variable support

### 2. Athena MCP Integration
- **9 Athena tools** available to the OpenClaw agent:
  1. `athena_smart_search` - Hybrid RAG search
  2. `athena_agentic_search` - Multi-step query decomposition
  3. `athena_quicksave` - Save session checkpoint
  4. `athena_recall_session` - Read session logs
  5. `athena_health_check` - System health check
  6. `athena_governance_status` - Triple-Lock compliance
  7. `athena_list_memory_paths` - List memory directories
  8. `athena_set_secret_mode` - Toggle demo mode
  9. `athena_permission_status` - Show access state

### 3. ACP Translator Modifications
- Stores MCP server configurations in sessions
- Foundation for full MCP support

## 📁 Repository Structure

```
.
├── install-openclaw.sh          # One-command installation script
├── verify-all.sh                # Verification script
├── modifications/               # Modified OpenClaw files
│   ├── openclaw-src/
│   │   ├── commands/           # 11 modified command files
│   │   └── acp/                # 3 modified ACP files
│   └── openclaw-extensions/
│       └── mcp-client/         # MCP client plugin
├── COMPLETE_IMPLEMENTATION.md  # Full documentation
└── README.md                   # This file
```

## 🔧 Files Modified

### Command Files (11 files):
1. `src/commands/onboard-types.ts` - Added NVIDIA types
2. `src/commands/auth-choice-options.ts` - Added NVIDIA UI options
3. `src/commands/onboard-auth.credentials.ts` - Added setNvidiaApiKey()
4. `src/commands/onboard-auth.config-core.ts` - Added NVIDIA config functions
5. `src/commands/onboard-auth.ts` - Exported NVIDIA functions
6. `src/commands/auth-choice.apply.ts` - Integrated NVIDIA handler
7. `src/commands/auth-choice.apply.nvidia.ts` - **NEW** NVIDIA auth handler
8. `src/commands/onboard-non-interactive/local/auth-choice.ts` - Non-interactive support
9. `src/commands/onboard-provider-auth-flags.ts` - CLI flags
10. `src/commands/auth-choice.preferred-provider.ts` - Provider mapping

### ACP Files (3 files):
1. `src/acp/types.ts` - Added McpServerConfig type
2. `src/acp/session.ts` - Store mcpServers in session
3. `src/acp/translator.ts` - Store instead of ignore MCP servers

### Extensions (1 new plugin):
1. `extensions/mcp-client/` - MCP client plugin with 9 Athena tools

## 🧪 Testing

After installation, test everything:

```bash
# Test NVIDIA
openclaw onboard --auth-choice nvidia-api-key

# Test Athena tools
openclaw tools list | grep athena

# Test end-to-end
openclaw send "Check Athena health status"
openclaw send "Search my memory for project ideas"
```

## 📝 Manual Installation

If you prefer manual installation:

1. **Clone repos:**
```bash
git clone https://github.com/openclaw/openclaw.git /opt/openclaw
git clone https://github.com/winstonkoh87/Athena-Public.git /opt/athena
```

2. **Apply modifications:**
```bash
# Copy modified files from this repo
cp -r modifications/openclaw-src/* /opt/openclaw/src/
cp -r modifications/openclaw-extensions/* /opt/openclaw/extensions/
```

3. **Install dependencies:**
```bash
cd /opt/openclaw
pnpm install
cd extensions/mcp-client && pnpm install
cd /opt/openclaw && pnpm build
```

4. **Setup Athena:**
```bash
cd /opt/athena
pip3 install -e .
```

5. **Run:**
```bash
cd /opt/openclaw
./start.sh
```

## 🎯 Features

✅ **NVIDIA in onboarding** - Interactive & non-interactive support
✅ **9 Athena tools** - Complete memory system integration
✅ **Persistent memory** - Agent never forgets context
✅ **Lazy connection** - Athena spawns on first use
✅ **Error handling** - Graceful failures
✅ **Production ready** - Systemd/supervisord services
✅ **Container support** - Works in Docker/containers

## 📄 Documentation

- `COMPLETE_IMPLEMENTATION.md` - Detailed implementation guide
- `IMPLEMENTATION_SUMMARY.md` - Quick summary
- `DETAILED_ANSWERS.md` - Answers to common questions

## 🤝 Credits

- OpenClaw: https://github.com/openclaw/openclaw
- Athena: https://github.com/winstonkoh87/Athena-Public

## 📜 License

Same as OpenClaw and Athena projects.