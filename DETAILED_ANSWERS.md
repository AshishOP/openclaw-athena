# OpenClaw + Athena - Detailed Answers

## 1. Will NVIDIA appear during `openclaw onboard`? ❌

**Answer**: No. NVIDIA uses API key authentication, not OAuth, so it won't appear in the interactive onboarding wizard.

**Why**: The onboarding wizard (`src/wizard/onboarding.ts`) only shows OAuth-based providers that need interactive authentication. API key providers like NVIDIA, OpenAI, and Anthropic are configured differently.

**How to enable NVIDIA**:
```bash
# Set environment variable
export NVIDIA_API_KEY="nvidia-api-key-here"

# Or configure directly
openclaw config set models.providers.nvidia.apiKey "your-key"
openclaw config set models.default "nvidia/llama-3.1-nemotron-70b-instruct"

# Verify
openclaw models list | grep nvidia
```

**I created a helper script** (`scripts/setup-nvidia.sh`) to make this easier.

---

## 2. Is MCP accessible by the agent? ✅ (Fixed!)

**Answer**: **YES**, but I had to fix the plugin first!

### The Problem
OpenClaw's plugin system **ignores async register functions**. From `src/plugins/loader.ts:439-447`:

```typescript
const result = register(api);
if (result && typeof result.then === "function") {
  registry.diagnostics.push({
    level: "warn",
    pluginId: record.id,
    source: record.source,
    message: "plugin register returned a promise; async registration is ignored",
  });
}
```

My first plugin version used `async register()` - this was **ignored**!

### The Solution
I rewrote the plugin to use:
1. **Synchronous register function** - no async/await in register()
2. **Tool factories** - Functions that return tools when agent starts
3. **Lazy connection** - MCP connection happens on first tool use, not at registration

### How It Works Now

```
OpenClaw Starts
    ↓
Plugin Loads (sync register)
    ↓
Registers 4 tool factories:
  - athena_smart_search
  - athena_quicksave  
  - athena_recall_session
  - athena_health_check
    ↓
Agent Starts (resolves tools)
    ↓
Tool factory called
    ↓
Connects to Athena MCP (first use)
    ↓
Tool executes via MCP
```

### Tool Factory Pattern

```typescript
// SYNC register - no async!
register(api) {
  api.registerTool((ctx) => {
    // This factory is called when agent starts
    return {
      name: "athena_smart_search",
      description: "Search Athena's memory...",
      parameters: { ... },
      async execute(params) {
        // Lazy connect on first use
        if (!manager.isConnected("athena")) {
          await manager.connectServer(athenaConfig);
        }
        return manager.callTool("athena", "smart_search", params);
      }
    };
  });
}
```

### MCP Tools Now Available

When the agent starts, these tools are available:

1. **`athena_smart_search`** - Hybrid RAG search
   ```
   Agent: "Find information about my previous project"
   → Calls athena_smart_search
   → Athena searches SQLite + vectors + tags
   → Returns relevant context
   ```

2. **`athena_quicksave`** - Save session checkpoint
   ```
   Agent: "Save this session"
   → Calls athena_quicksave
   → Athena writes to session log
   → "✅ Session saved to Athena memory"
   ```

3. **`athena_recall_session`** - Read previous sessions
   ```
   Agent: "What did we work on yesterday?"
   → Calls athena_recall_session
   → Athena reads session logs
   → Returns conversation history
   ```

4. **`athena_health_check`** - System status
   ```
   Agent: "Is Athena working?"
   → Calls athena_health_check
   → Checks database + vector API
   → Returns status report
   ```

### Testing MCP Tools

```bash
# 1. Start OpenClaw
export ATHENA_PATH=/opt/athena
cd /opt/openclaw
pnpm dev

# 2. Check if tools are loaded
openclaw tools list | grep athena

# 3. Test direct tool call
openclaw tools call athena_health_check

# 4. Test via agent
openclaw send "Use athena_health_check to check system status"
```

---

## 3. Is Athena Embedded? ❌ (Separate Process)

**Answer**: **NO**, Athena is NOT embedded in OpenClaw. They are separate processes that communicate via MCP.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Digital Ocean Droplet                     │
│                                                              │
│  ┌─────────────────────┐      ┌─────────────────────┐       │
│  │    OpenClaw         │      │    Athena MCP       │       │
│  │    (Node.js/TS)     │◄────►│    Server (Python)  │       │
│  │                     │ stdio │                     │       │
│  │  ┌───────────────┐  │      │  ┌───────────────┐  │       │
│  │  │ MCP Client    │  │      │  │ FastMCP       │  │       │
│  │  │ Plugin        │  │      │  │ (MCP SDK)     │  │       │
│  │  └───────────────┘  │      │  └───────────────┘  │       │
│  │         │           │      │         │           │       │
│  │  ┌──────▼────────┐  │      │  ┌──────▼────────┐  │       │
│  │  │ Agent         │  │      │  │ Tools         │  │       │
│  │  │ (Your AI)     │  │      │  │ (9 total)     │  │       │
│  │  └───────────────┘  │      │  └───────────────┘  │       │
│  └─────────────────────┘      └─────────────────────┘       │
│           │                              │                  │
│           │      stdio pipes             │                  │
│           └──────────────────────────────┘                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### How They Communicate

1. **Transport**: stdio (standard input/output pipes)
2. **Protocol**: MCP (Model Context Protocol)
3. **Process**: 
   - OpenClaw spawns: `python -m athena.mcp_server`
   - Communicates via JSON-RPC over stdio
   - Both processes run independently

### Process Lifecycle

```
OpenClaw Gateway Starts
    ↓
MCP Client Plugin Loaded
    ↓
User sends message to Agent
    ↓
Agent needs memory → Calls athena_smart_search
    ↓
Tool executes:
  1. Check if Athena connected? No → Spawn process
  2. Send JSON-RPC: {"method": "tools/call", ...}
  3. Athena receives → Executes tool
  4. Athena returns result
  5. Tool returns to Agent
    ↓
Agent uses context to generate response
```

### Why Separate Processes?

**Advantages**:
- ✅ **Language independence** - OpenClaw (TS) + Athena (Python)
- ✅ **Fault isolation** - If Athena crashes, OpenClaw continues
- ✅ **Resource management** - Separate memory/CPU limits
- ✅ **Scalability** - Can run on different machines
- ✅ **Upgrades** - Update one without affecting the other

**Trade-offs**:
- ⚠️ **Startup latency** - First tool call spawns Python process (~1-2s)
- ⚠️ **Communication overhead** - JSON-RPC serialization
- ⚠️ **Process management** - Need to handle crashes/reconnects

### Deployment Options

#### Option A: Same Machine (Recommended for droplets)
```
Droplet:
  - OpenClaw (port 18789)
  - Athena (stdio via MCP)
  - SQLite database (/var/lib/athena/)
  - Markdown files (.context/)
```

#### Option B: Separate Machines
```
Droplet 1: OpenClaw
  ↓ HTTP/MCP SSE
Droplet 2: Athena MCP Server
  ↓ local
Droplet 2: Supabase/PostgreSQL
```

#### Option C: Container (Future)
```
Docker Compose:
  - openclaw: node:22
  - athena: python:3.12
  - volumes:
    - athena-data:/var/lib/athena
```

### Storage Locations

**Athena stores data in**:
```
/opt/athena/
├── .context/
│   ├── memories/
│   │   └── session_logs/      # Session transcripts
│   ├── memory_bank/           # Knowledge files
│   └── CANONICAL.md          # Core identity
├── athena.db                 # SQLite database
└── embedding_cache.json      # Cached embeddings
```

**OpenClaw stores data in**:
```
~/.openclaw/
├── agents/
│   └── <agent-id>/
│       ├── sessions/         # Session JSONL files
│       └── auth-profiles.json
├── plugins/
│   └── mcp-client/           # MCP plugin
└── config.json               # OpenClaw config
```

### Data Flow Example

**User**: "What did we discuss about the database yesterday?"

```
1. OpenClaw Agent receives message
2. Agent decides to use athena_smart_search
3. MCP Client spawns Athena (if not running)
4. MCP Client sends:
   {
     "jsonrpc": "2.0",
     "method": "tools/call",
     "params": {
       "name": "smart_search",
       "arguments": {
         "query": "database discussion yesterday"
       }
     }
   }
5. Athena receives → searches:
   - SQLite: SELECT * FROM memories WHERE ...
   - Vector search: embedding similarity
   - Tag search: grep "database"
6. Athena returns:
   {
     "content": [
       {
         "type": "text",
         "text": "[Session 2026-02-15] We discussed PostgreSQL..."
       }
     ]
   }
7. MCP Client returns to Agent
8. Agent generates response with context
9. Response sent to user
```

---

## Summary Table

| Question | Answer | Details |
|----------|--------|---------|
| **NVIDIA in onboard?** | ❌ No | Use `NVIDIA_API_KEY` env var or config |
| **MCP accessible?** | ✅ Yes | Fixed plugin with sync register + tool factories |
| **Athena embedded?** | ❌ No | Separate Python process via MCP stdio |

---

## Quick Verification Commands

```bash
# 1. Check NVIDIA
openclaw models list | grep nvidia

# 2. Check MCP tools
openclaw tools list | grep athena

# 3. Check Athena process
pgrep -f "athena.mcp_server"

# 4. Check Athena data
ls -la /opt/athena/.context/

# 5. Test end-to-end
openclaw send "Use athena_health_check"
```

## Troubleshooting

**MCP tools not showing?**
```bash
# Check plugin loaded
openclaw plugins list

# Check logs
journalctl -u openclaw -f | grep mcp

# Test manually
cd /opt/athena && python3 -m athena.mcp_server
```

**Athena connection fails?**
```bash
# Verify Athena path
ls -la $ATHENA_PATH/src/athena/mcp_server.py

# Test Athena standalone
cd /opt/athena
PYTHONPATH=/opt/athena/src python3 -m athena.mcp_server
# (Should start without errors)
```

**NVIDIA not working?**
```bash
# Verify key
echo $NVIDIA_API_KEY

# Test API
curl https://integrate.api.nvidia.com/v1/models \
  -H "Authorization: Bearer $NVIDIA_API_KEY"
```