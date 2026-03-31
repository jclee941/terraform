import type { Part } from "@opencode-ai/sdk/v2"
import type { createOpencodeClient } from "@opencode-ai/sdk/v2"

interface MessageWithRole {
  info?: {
    role?: string
    id?: string
    time?: {
      completed?: number
    }
    error?: {
      name?: string
      data?: {
        message?: string
        statusCode?: number
      }
    }
  }
  parts?: Part[]
}

interface AwaitAssistantTextOptions {
  attempts?: number
  sleepMs?: number
}

interface StartupSmokeTestOptions {
  sessionTitle: string
  model: {
    providerID: string
    modelID: string
  }
  systemPrompt: string
  attempts?: number
  sleepMs?: number
}

function isMessageWithRoleArray(value: unknown): value is MessageWithRole[] {
  return Array.isArray(value)
}

function hasParts(message: unknown): message is { parts: Part[] } {
  if (typeof message !== "object" || message === null) return false
  if (!("parts" in message)) return false

  const { parts } = message as { parts?: unknown }
  return Array.isArray(parts)
}

export function extractParticipantErrorMessage(participant: unknown): string | undefined {
  const error =
    typeof participant === "object" && participant !== null && "info" in participant
      ? (participant as {
          info?: {
            error?: {
              name?: string
              data?: {
                message?: string
                statusCode?: number
              }
            }
          }
        }).info?.error
      : undefined

  if (!error) return undefined

  const message = error.data?.message ?? error.name
  if (!message) return undefined
  const status = error.data?.statusCode
  return status ? `${message} (status ${status})` : message
}

export function extractTextFromParts(parts: Part[]): string {
  const raw = parts
    .filter((part): part is Extract<Part, { type: "text" }> => part.type === "text")
    .map((part) => part.text)
    .join("\n")

  const stripped = raw.replace(/<thinking>[\s\S]*?<\/thinking>/g, "").trim()
  return stripped.length > 0 ? stripped : raw.trim()
}

export function summarizeAssistantState(message: MessageWithRole | undefined): string {
  if (!message) return "assistant=missing"

  const partCount = Array.isArray(message.parts) ? message.parts.length : 0
  const role = message.info?.role ?? "unknown"
  const id = message.info?.id ?? "unknown"
  const completed = message.info?.time?.completed
  const errorMessage = message.info?.error?.data?.message ?? message.info?.error?.name

  return JSON.stringify({
    role,
    id,
    partCount,
    completed: completed ?? null,
    error: errorMessage ?? null,
  })
}

function getAssistantResponseText(message: unknown): string | undefined {
  if (!hasParts(message) || message.parts.length === 0) return undefined

  const text = extractTextFromParts(message.parts)
  return text || undefined
}

function findLatestAssistantMessage(value: unknown): MessageWithRole | undefined {
  if (!isMessageWithRoleArray(value)) return undefined
  return [...value].reverse().find((message) => message.info?.role === "assistant")
}

type OpencodeClient = ReturnType<typeof createOpencodeClient>

export async function awaitAssistantText(
  client: OpencodeClient,
  sessionID: string,
  options?: AwaitAssistantTextOptions,
): Promise<{ text: string; latestAssistant: MessageWithRole | undefined }> {
  const attempts = options?.attempts ?? 120
  const sleepMs = options?.sleepMs ?? 500

  let latestAssistant: MessageWithRole | undefined

  for (let attempt = 0; attempt < attempts; attempt++) {
    const { data: messages } = await client.session.messages({ sessionID })
    if (!messages) {
      throw new Error("Failed to get messages")
    }

    if (isMessageWithRoleArray(messages)) {
      for (const message of messages) {
        const participantError = extractParticipantErrorMessage(message)
        if (participantError) {
          throw new Error(`Agent error: ${participantError}`)
        }
      }
    }

    const assistantMessage = findLatestAssistantMessage(messages)
    if (assistantMessage) {
      latestAssistant = assistantMessage
      const text = getAssistantResponseText(assistantMessage)
      if (text) {
        return { text, latestAssistant }
      }
    }

    await Bun.sleep(sleepMs)
  }

  throw new Error(`Assistant unavailable. ${summarizeAssistantState(latestAssistant)}`)
}

export async function runStartupSmokeTest(
  client: OpencodeClient,
  options: StartupSmokeTestOptions,
): Promise<void> {
  const { data: session } = await client.session.create({
    title: options.sessionTitle,
  })

  if (!session) {
    throw new Error("Startup smoke test failed: unable to create session")
  }

  try {
    const promptResult = await client.session.prompt({
      sessionID: session.id,
      model: options.model,
      parts: [{ type: "text", text: "Reply with OK." }],
      system: options.systemPrompt,
    })

    if (promptResult.error) {
      throw new Error(`Startup smoke test failed: ${String(promptResult.error)}`)
    }

    const promptError = extractParticipantErrorMessage(promptResult.data)
    if (promptError) {
      throw new Error(`Startup smoke test failed: ${promptError}`)
    }

    await awaitAssistantText(client, session.id, {
      attempts: options.attempts,
      sleepMs: options.sleepMs,
    })
  } finally {
    await client.session.delete({ sessionID: session.id }).catch(() => {})
  }
}
