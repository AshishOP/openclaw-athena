import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
import { emptyPluginConfigSchema } from "openclaw/plugin-sdk";
import { McpClientManager } from "./src/client.js";

// Global MCP manager instance (singleton)
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
  description: "Connect to MCP servers (Athena, etc.) and use their tools",
  configSchema: emptyPluginConfigSchema(),
  
  // SYNC register function - no async!
  register(api: OpenClawPluginApi) {
    const logger = api.logger;
    const manager = getMcpManager(logger);

    // Configuration for Athena MCP server
    const athenaConfig = {
      name: "athena",
      command: "python",
      args: ["-m", "athena.mcp_server"],
      cwd: process.env.ATHENA_PATH || "/opt/athena",
      env: {
        ...process.env,
        PYTHONPATH: process.env.ATHENA_PATH || "/opt/athena/src",
      },
    };

    // Register a tool factory - this gets called when agent starts
    // The factory connects to MCP and returns the tools
    api.registerTool((ctx) => {
      // This factory is called when tools are resolved for the agent
      // Return tools that will call MCP
      return {
        name: "athena_smart_search",
        description: "Search Athena's memory using hybrid RAG (vector + keyword + graph)",
        parameters: {
          type: "object",
          properties: {
            query: { 
              type: "string", 
              description: "Search query to find relevant information from memory" 
            },
            limit: { 
              type: "number", 
              description: "Maximum number of results (default: 5)",
              default: 5
            },
          },
          required: ["query"],
        },
        async execute(params: { query: string; limit?: number }) {
          try {
            // Ensure connection on first use
            if (!manager.isConnected("athena")) {
              logger.info("Connecting to Athena MCP server...");
              await manager.connectServer(athenaConfig);
            }
            
            const result = await manager.callTool("athena", "smart_search", {
              query: params.query,
              limit: params.limit ?? 5,
            });
            
            return JSON.stringify(result, null, 2);
          } catch (error) {
            logger.error(`Athena smart_search failed: ${error}`);
            return `Error searching memory: ${error}`;
          }
        },
      };
    });

    // Register more Athena tools
    api.registerTool((ctx) => ({
      name: "athena_quicksave",
      description: "Save a checkpoint to Athena's session log",
      parameters: {
        type: "object",
        properties: {
          summary: { 
            type: "string", 
            description: "Summary of current state to save" 
          },
        },
        required: ["summary"],
      },
      async execute(params: { summary: string }) {
        try {
          if (!manager.isConnected("athena")) {
            await manager.connectServer(athenaConfig);
          }
          
          const result = await manager.callTool("athena", "quicksave", {
            summary: params.summary,
          });
          
          return "✅ Session saved to Athena memory";
        } catch (error) {
          logger.error(`Athena quicksave failed: ${error}`);
          return `Error saving session: ${error}`;
        }
      },
    }));

    api.registerTool((ctx) => ({
      name: "athena_recall_session",
      description: "Recall recent session log content from Athena",
      parameters: {
        type: "object",
        properties: {
          limit: { 
            type: "number", 
            description: "Number of recent sessions to recall",
            default: 1
          },
        },
      },
      async execute(params: { limit?: number }) {
        try {
          if (!manager.isConnected("athena")) {
            await manager.connectServer(athenaConfig);
          }
          
          const result = await manager.callTool("athena", "recall_session", {
            limit: params.limit ?? 1,
          });
          
          return JSON.stringify(result, null, 2);
        } catch (error) {
          logger.error(`Athena recall_session failed: ${error}`);
          return `Error recalling session: ${error}`;
        }
      },
    }));

    api.registerTool((ctx) => ({
      name: "athena_health_check",
      description: "Check Athena system health (database, vector API)",
      parameters: {
        type: "object",
        properties: {},
      },
      async execute() {
        try {
          if (!manager.isConnected("athena")) {
            await manager.connectServer(athenaConfig);
          }
          
          const result = await manager.callTool("athena", "health_check", {});
          
          return JSON.stringify(result, null, 2);
        } catch (error) {
          logger.error(`Athena health_check failed: ${error}`);
          return `Error checking health: ${error}`;
        }
      },
    }));

    // Register additional Athena tools (5 more)
    api.registerTool((ctx) => ({
      name: "athena_agentic_search",
      description: "Multi-step query decomposition with parallel search across all memory sources",
      parameters: {
        type: "object",
        properties: {
          query: { 
            type: "string", 
            description: "Complex search query to decompose and search" 
          },
          limit: { 
            type: "number", 
            description: "Maximum number of results per sub-query (default: 5)",
            default: 5
          },
        },
        required: ["query"],
      },
      async execute(params: { query: string; limit?: number }) {
        try {
          if (!manager.isConnected("athena")) {
            await manager.connectServer(athenaConfig);
          }
          
          const result = await manager.callTool("athena", "agentic_search", {
            query: params.query,
            limit: params.limit ?? 5,
          });
          
          return JSON.stringify(result, null, 2);
        } catch (error) {
          logger.error(`Athena agentic_search failed: ${error}`);
          return `Error in agentic search: ${error}`;
        }
      },
    }));

    api.registerTool((ctx) => ({
      name: "athena_governance_status",
      description: "Check Athena's Triple-Lock compliance state and governance settings",
      parameters: {
        type: "object",
        properties: {},
      },
      async execute() {
        try {
          if (!manager.isConnected("athena")) {
            await manager.connectServer(athenaConfig);
          }
          
          const result = await manager.callTool("athena", "governance_status", {});
          
          return JSON.stringify(result, null, 2);
        } catch (error) {
          logger.error(`Athena governance_status failed: ${error}`);
          return `Error checking governance: ${error}`;
        }
      },
    }));

    api.registerTool((ctx) => ({
      name: "athena_list_memory_paths",
      description: "List all active memory directories and their contents",
      parameters: {
        type: "object",
        properties: {},
      },
      async execute() {
        try {
          if (!manager.isConnected("athena")) {
            await manager.connectServer(athenaConfig);
          }
          
          const result = await manager.callTool("athena", "list_memory_paths", {});
          
          return JSON.stringify(result, null, 2);
        } catch (error) {
          logger.error(`Athena list_memory_paths failed: ${error}`);
          return `Error listing memory paths: ${error}`;
        }
      },
    }));

    api.registerTool((ctx) => ({
      name: "athena_set_secret_mode",
      description: "Toggle Athena's secret/demo mode (redacts sensitive content)",
      parameters: {
        type: "object",
        properties: {
          enabled: { 
            type: "boolean", 
            description: "Enable secret mode (true) or disable (false)" 
          },
        },
        required: ["enabled"],
      },
      async execute(params: { enabled: boolean }) {
        try {
          if (!manager.isConnected("athena")) {
            await manager.connectServer(athenaConfig);
          }
          
          const result = await manager.callTool("athena", "set_secret_mode", {
            enabled: params.enabled,
          });
          
          return params.enabled 
            ? "🔒 Secret mode enabled - sensitive content will be redacted"
            : "🔓 Secret mode disabled - full access restored";
        } catch (error) {
          logger.error(`Athena set_secret_mode failed: ${error}`);
          return `Error setting secret mode: ${error}`;
        }
      },
    }));

    api.registerTool((ctx) => ({
      name: "athena_permission_status",
      description: "Show current access state and available tool manifest",
      parameters: {
        type: "object",
        properties: {},
      },
      async execute() {
        try {
          if (!manager.isConnected("athena")) {
            await manager.connectServer(athenaConfig);
          }
          
          const result = await manager.callTool("athena", "permission_status", {});
          
          return JSON.stringify(result, null, 2);
        } catch (error) {
          logger.error(`Athena permission_status failed: ${error}`);
          return `Error checking permissions: ${error}`;
        }
      },
    }));

    // Register cleanup hook
    api.on("gateway_stop", async () => {
      logger.info("Disconnecting from MCP servers...");
      if (mcpManager) {
        await mcpManager.disconnectAll();
        mcpManager = null;
      }
    });

    logger.info("MCP Client plugin registered (9 tools: smart_search, agentic_search, quicksave, recall_session, health_check, governance_status, list_memory_paths, set_secret_mode, permission_status)");
  },
};

export default plugin;