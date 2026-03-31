/**
 * Standalone MCP server entry point.
 * Runs over stdio transport for use with MCP clients.
 *
 * Usage:
 *   bun run src/mcp/index.ts
 *   # or via package.json: bun run mcp
 */

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createN8nMcpServer } from "./server.js";

async function main(): Promise<void> {
  const server = createN8nMcpServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // Server runs until stdin closes
}

main().catch((err) => {
  console.error("MCP server fatal error:", err);
  process.exit(1);
});
