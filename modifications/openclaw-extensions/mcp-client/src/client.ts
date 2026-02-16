import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import type { Tool } from "@modelcontextprotocol/sdk/types.js";
import { spawn } from "node:child_process";
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
      {
        name: "openclaw-mcp-client",
        version: "1.0.0",
      },
      {
        capabilities: {},
      }
    );

    try {
      await client.connect(transport);
      
      // List available tools
      const toolsResult = await client.listTools();
      const availableTools = toolsResult.tools || [];
      
      this.tools.set(config.name, availableTools);
      this.clients.set(config.name, client);
      this.transports.set(config.name, transport);

      this.logger.info(
        `Connected to '${config.name}' with ${availableTools.length} tools: ${availableTools.map(t => t.name).join(", ")}`
      );
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

  isConnected(serverName: string): boolean {
    return this.clients.has(serverName);
  }

  async callTool(serverName: string, toolName: string, args: Record<string, unknown>): Promise<unknown> {
    const client = this.clients.get(serverName);
    if (!client) {
      throw new Error(`MCP server '${serverName}' not connected`);
    }

    this.logger.info(`Calling MCP tool: ${serverName}/${toolName}`);
    
    const result = await client.callTool({
      name: toolName,
      arguments: args,
    });

    return result;
  }

  convertToOpenClawTool(server: string, tool: Tool): AnyAgentTool {
    const fullName = `mcp_${server}_${tool.name}`.replace(/[^a-zA-Z0-9_]/g, "_");
    
    return {
      name: fullName,
      description: tool.description || `MCP tool: ${tool.name} from ${server}`,
      parameters: tool.inputSchema || { type: "object", properties: {} },
      async execute(params: Record<string, unknown>) {
        const result = await this.callTool(server, tool.name, params);
        return JSON.stringify(result, null, 2);
      },
    };
  }
}