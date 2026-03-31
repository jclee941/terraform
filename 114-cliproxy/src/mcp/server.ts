/**
 * MCP Server exposing all n8n workflow tools.
 *
 * Usage:
 *   import { createN8nMcpServer } from "./server.js";
 *   const server = createN8nMcpServer();
 *   // attach to transport (e.g. stdio)
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import * as n8n from "../n8n/client.js";

/** Create and return a fully-configured MCP server with all n8n tools */
export function createN8nMcpServer(): McpServer {
  const server = new McpServer({
    name: "n8n-workflow-agent",
    version: "1.0.0",
  });

  server.tool(
    "list_workflows",
    "List all n8n workflows. Optionally filter by active status.",
    {
      active: z.boolean().optional().describe("Filter by active status (true/false)"),
      limit: z.number().int().positive().optional().describe("Max number of workflows to return"),
      cursor: z.string().optional().describe("Pagination cursor from previous response"),
    },
    async (args) => {
      const result = await n8n.listWorkflows({
        active: args.active,
        limit: args.limit,
        cursor: args.cursor,
      });
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "get_workflow",
    "Get full details of a specific workflow by ID, including nodes, connections, and settings.",
    {
      workflowId: z.string().describe("ID of the workflow to retrieve"),
    },
    async (args) => {
      const result = await n8n.getWorkflow(args.workflowId);
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "create_workflow",
    "Create a new workflow in n8n. Requires name, nodes array, and connections object. Settings, tags, and active are optional.",
    {
      name: z.string().describe("Name for the new workflow"),
      nodes: z.string().describe("JSON string of nodes array (required)"),
      connections: z.string().describe("JSON string of connections object (required)"),
      settings: z.string().optional().describe("JSON string of workflow settings"),
      tags: z.string().optional().describe("Comma-separated tag names"),
      active: z.boolean().optional().describe("Whether the workflow should be active upon creation"),
    },
    async (args) => {
      const payload: {
        name: string;
        nodes: unknown;
        connections: unknown;
        settings?: unknown;
        tags?: string[];
        active?: boolean;
      } = {
        name: args.name,
        nodes: JSON.parse(args.nodes),
        connections: JSON.parse(args.connections),
      };
      if (args.settings) payload.settings = JSON.parse(args.settings);
      if (args.tags) payload.tags = args.tags.split(",").map((t) => t.trim());
      if (args.active !== undefined) payload.active = args.active;
      const result = await n8n.createWorkflow(payload as Parameters<typeof n8n.createWorkflow>[0]);
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "update_workflow",
    "Update an existing workflow (full replace via PUT). Requires workflowId, name, nodes, and connections. Settings, tags, and active are optional.",
    {
      workflowId: z.string().describe("ID of the workflow to update"),
      name: z.string().describe("Name for the workflow"),
      nodes: z.string().describe("JSON string of full nodes array (required)"),
      connections: z.string().describe("JSON string of full connections object (required)"),
      settings: z.string().optional().describe("JSON string of workflow settings"),
      tags: z.string().optional().describe("Comma-separated tag names"),
      active: z.boolean().optional().describe("Whether the workflow should be active"),
    },
    async (args) => {
      const payload: {
        name: string;
        nodes: unknown;
        connections: unknown;
        settings?: unknown;
        tags?: string[];
        active?: boolean;
      } = {
        name: args.name,
        nodes: JSON.parse(args.nodes),
        connections: JSON.parse(args.connections),
      };
      if (args.settings) payload.settings = JSON.parse(args.settings);
      if (args.tags) payload.tags = args.tags.split(",").map((t) => t.trim());
      if (args.active !== undefined) payload.active = args.active;
      const result = await n8n.updateWorkflow(
        args.workflowId,
        payload as Parameters<typeof n8n.updateWorkflow>[1],
      );
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "delete_workflow",
    "Permanently delete a workflow by ID. This cannot be undone.",
    {
      workflowId: z.string().describe("ID of the workflow to delete"),
    },
    async (args) => {
      await n8n.deleteWorkflow(args.workflowId);
      return {
        content: [{ type: "text" as const, text: `Workflow ${args.workflowId} deleted successfully.` }],
      };
    },
  );

  server.tool(
    "activate_workflow",
    "Activate a workflow so its triggers start listening.",
    {
      workflowId: z.string().describe("ID of the workflow to activate"),
    },
    async (args) => {
      const result = await n8n.activateWorkflow(args.workflowId);
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "deactivate_workflow",
    "Deactivate a workflow so its triggers stop listening.",
    {
      workflowId: z.string().describe("ID of the workflow to deactivate"),
    },
    async (args) => {
      const result = await n8n.deactivateWorkflow(args.workflowId);
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "list_executions",
    "List workflow executions. Optionally filter by workflow ID or status.",
    {
      workflowId: z.string().optional().describe("Filter executions by workflow ID"),
      status: z.enum(["canceled", "crashed", "error", "new", "running", "success", "unknown", "waiting"]).optional().describe("Filter by execution status"),
      limit: z.number().int().positive().optional().describe("Max number of executions to return"),
      cursor: z.string().optional().describe("Pagination cursor from previous response"),
      includeData: z.boolean().optional().describe("Include execution data in response"),
    },
    async (args) => {
      const result = await n8n.listExecutions({
        workflowId: args.workflowId,
        status: args.status,
        limit: args.limit,
        cursor: args.cursor,
        includeData: args.includeData,
      });
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "get_execution",
    "Get detailed information about a specific execution, including node-level run data.",
    {
      executionId: z.string().describe("ID of the execution to retrieve"),
    },
    async (args) => {
      const result = await n8n.getExecution(args.executionId);
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "delete_execution",
    "Delete a specific execution record by ID.",
    {
      executionId: z.string().describe("ID of the execution to delete"),
    },
    async (args) => {
      await n8n.deleteExecution(args.executionId);
      return {
        content: [{ type: "text" as const, text: `Execution ${args.executionId} deleted successfully.` }],
      };
    },
  );

  server.tool(
    "run_webhook",
    "Execute a workflow via its webhook trigger. The workflow must have a Webhook node configured with the specified path.",
    {
      webhookPath: z.string().describe('Webhook path configured in the workflow (e.g. "my-workflow" for /webhook/my-workflow)'),
      data: z.string().optional().describe("JSON string of data to send as the webhook body"),
      headers: z.string().optional().describe("JSON string of additional headers to send"),
    },
    async (args) => {
      const data = args.data ? JSON.parse(args.data) : undefined;
      const extraHeaders = args.headers ? JSON.parse(args.headers) : undefined;
      const result = await n8n.runWebhook(args.webhookPath, data, extraHeaders);
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "list_credentials",
    "List all credentials stored in n8n. Returns id, name, type, and timestamps.",
    {
      includeScopes: z.boolean().optional().describe("Include permission scopes in response"),
      includeData: z.boolean().optional().describe("Include credential data (sensitive fields redacted)"),
      limit: z.number().int().positive().optional().describe("Max number of credentials to return"),
      cursor: z.string().optional().describe("Pagination cursor from previous response"),
    },
    async (args) => {
      const result = await n8n.listCredentials({
        includeScopes: args.includeScopes,
        includeData: args.includeData,
        limit: args.limit,
        cursor: args.cursor,
      });
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "create_credential",
    "Create a new credential in n8n. Use get_credential_schema first to see required fields for a given credential type.",
    {
      name: z.string().describe("Display name for the credential"),
      type: z.string().describe('Credential type identifier (e.g. "telegramApi", "httpBasicAuth", "supabaseApi")'),
      data: z.string().describe("JSON string of credential data matching the type schema"),
    },
    async (args) => {
      const result = await n8n.createCredential({
        name: args.name,
        type: args.type,
        data: JSON.parse(args.data),
      });
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "update_credential",
    "Update an existing credential by ID. Can update name, data, or both.",
    {
      credentialId: z.string().describe("ID of the credential to update"),
      name: z.string().optional().describe("New display name for the credential"),
      data: z.string().optional().describe("JSON string of updated credential data (full replace)"),
    },
    async (args) => {
      const payload: Parameters<typeof n8n.updateCredential>[1] = {};
      if (args.name) payload.name = args.name;
      if (args.data) payload.data = JSON.parse(args.data);
      const result = await n8n.updateCredential(args.credentialId, payload);
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "delete_credential",
    "Permanently delete a credential by ID. This cannot be undone.",
    {
      credentialId: z.string().describe("ID of the credential to delete"),
    },
    async (args) => {
      await n8n.deleteCredential(args.credentialId);
      return {
        content: [{ type: "text" as const, text: `Credential ${args.credentialId} deleted successfully.` }],
      };
    },
  );

  server.tool(
    "get_credential_schema",
    "Get the JSON schema for a specific credential type, showing which fields are required and their types.",
    {
      typeName: z.string().describe('Credential type identifier (e.g. "telegramApi", "httpBasicAuth", "supabaseApi")'),
    },
    async (args) => {
      const result = await n8n.getCredentialSchema(args.typeName);
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.tool(
    "test_credential",
    "Test whether a stored credential can successfully connect to its service.",
    {
      credentialId: z.string().describe("ID of the credential to test"),
      credentialType: z.string().describe("Type identifier of the credential (e.g. \"telegramApi\")"),
    },
    async (args) => {
      const result = await n8n.testCredential(
        args.credentialId,
        args.credentialType,
      );
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  return server;
}
