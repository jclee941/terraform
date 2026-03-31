import {
  createOpencodeServer,
  createOpencodeClient,
} from "@opencode-ai/sdk/v2"
import type { Part } from "@opencode-ai/sdk/v2"
import * as readline from "node:readline"
import {
  server as serverConfig,
  proxyModel,
  proxyProvider,
  getProxyProviderConfigError,
  smokeTest,
} from "./config.js"
import {
  awaitAssistantText,
  runStartupSmokeTest,
} from "./opencode-chat.js"

const PORT = serverConfig.port

const N8N_SYSTEM_PROMPT = `You are an N8N workflow management agent. You have access to n8n tools through MCP.

Your capabilities:
- List all n8n workflows (list_workflows)
- Get details of a specific workflow (get_workflow)
- Create new workflows (create_workflow)
- Update existing workflows (update_workflow)
- Delete workflows (delete_workflow)
- Activate/deactivate workflows (activate_workflow, deactivate_workflow)
- Execute workflows via webhook (run_webhook)
- List and inspect executions (list_executions, get_execution)

When the user asks about workflows, use the available n8n MCP tools to fulfill their request.
Present workflow information in a clear, structured format.
For destructive operations (delete, deactivate), confirm the action clearly in your response.`

function createCliServerConfig() {
  const internalModelRef = `${proxyProvider.id}/${proxyModel.targetId}`

  return {
    enabled_providers: [proxyProvider.id],
    default_agent: "build",
    model: internalModelRef,
    small_model: internalModelRef,
    provider: {
      [proxyProvider.id]: {
        name: "N8N OpenAI Compatible",
        npm: "@ai-sdk/openai-compatible",
        api: proxyProvider.baseUrl || "https://openrouter.ai/api/v1",
        env: [],
        models: {
          [proxyModel.targetId]: {
            name: proxyModel.targetId,
            tool_call: true,
            reasoning: true,
            temperature: true,
            limit: {
              context: 128000,
              output: 32768,
            },
          },
        },
        options: {
          ...(proxyProvider.apiKey ? { apiKey: proxyProvider.apiKey } : {}),
          ...(proxyProvider.baseUrl ? { baseURL: proxyProvider.baseUrl } : {}),
        },
      },
    },
    agent: {
      build: {
        model: internalModelRef,
        prompt: N8N_SYSTEM_PROMPT,
      },
      plan: { model: internalModelRef },
      general: { model: internalModelRef },
      explore: { model: internalModelRef },
      title: { model: internalModelRef },
      summary: { model: internalModelRef },
      compaction: { model: internalModelRef },
    },
  }
}

function printPart(part: Part): void {
  switch (part.type) {
    case "text":
      console.log(part.text)
      break
    case "tool":
      if (part.state.status === "completed") {
        console.log(`  \uD83D\uDD27 ${part.state.title ?? part.tool} \u2705`)
      } else if (part.state.status === "error") {
        console.log(`  \uD83D\uDD27 ${part.tool} \u274C ${part.state.error}`)
      }
      break
    case "step-start":
    case "step-finish":
    case "reasoning":
      // Skip internal parts
      break
    default:
      break
  }
}

async function main(): Promise<void> {
  console.log("Starting N8N Agent server...")
  const startupConfigError = getProxyProviderConfigError()
  if (startupConfigError) {
    throw new Error(startupConfigError)
  }

  const cliRuntimeConfig = createCliServerConfig()
  const previousConfigContent = process.env.OPENCODE_CONFIG_CONTENT
  process.env.OPENCODE_CONFIG_CONTENT = JSON.stringify(cliRuntimeConfig)

  let server: Awaited<ReturnType<typeof createOpencodeServer>>
  try {
    server = await createOpencodeServer({
      port: PORT,
      hostname: "127.0.0.1",
      config: cliRuntimeConfig,
    })
  } catch (error) {
    throw new Error(
      `OpenCode bootstrap failed: ${error instanceof Error ? error.message : String(error)}`,
    )
  } finally {
    if (previousConfigContent === undefined) {
      delete process.env.OPENCODE_CONFIG_CONTENT
    } else {
      process.env.OPENCODE_CONFIG_CONTENT = previousConfigContent
    }
  }
  console.log(`Server running at ${server.url}`)

  const client = createOpencodeClient({
    baseUrl: server.url,
    directory: process.cwd(),
  })

  await runStartupSmokeTest(client, {
    sessionTitle: "n8n-cli-startup-smoke-test",
    model: {
      providerID: proxyProvider.id,
      modelID: proxyModel.targetId,
    },
    systemPrompt: N8N_SYSTEM_PROMPT,
    attempts: smokeTest.attempts,
    sleepMs: smokeTest.sleepMs,
  })

  // Register n8n MCP server
  await client.mcp.add({
    name: "n8n",
    config: {
      type: "local" as const,
      command: ["bun", "run", new URL("./mcp/index.ts", import.meta.url).pathname],
      environment: {
        ...(process.env.N8N_BASE_URL ? { N8N_BASE_URL: process.env.N8N_BASE_URL } : {}),
        ...(process.env.N8N_API_KEY ? { N8N_API_KEY: process.env.N8N_API_KEY } : {}),
      },
    },
  })
  console.log("n8n MCP server registered")

  const { data: session } = await client.session.create({
    title: "N8N Agent Session",
  })
  if (!session) {
    throw new Error("Failed to create session")
  }

  console.log(`Session: ${session.id}`)
  console.log("\nN8N Agent ready. Type your commands (Ctrl+C to exit):\n")

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    prompt: "n8n> ",
  })

  rl.prompt()

  rl.on("line", async (line: string) => {
    const input = line.trim()
    if (!input) {
      rl.prompt()
      return
    }

    try {
      console.log("\n\u23F3 Processing...\n")

      const promptResult = await client.session.prompt({
        sessionID: session.id,
        parts: [{ type: "text", text: input }],
        system: N8N_SYSTEM_PROMPT,
      })

      if (promptResult.error) {
        throw new Error(String(promptResult.error))
      }

      const { text } = await awaitAssistantText(client, session.id, {
        attempts: 120,
        sleepMs: 500,
      })
      console.log(text)
    } catch (error) {
      console.error(
        "Error:",
        error instanceof Error ? error.message : String(error),
      )
    }

    console.log()
    rl.prompt()
  })

  rl.on("close", () => {
    console.log("\nShutting down...")
    server.close()
    process.exit(0)
  })

  process.on("SIGINT", () => {
    rl.close()
  })
}

main().catch((error: unknown) => {
  console.error("Fatal:", error)
  process.exit(1)
})
