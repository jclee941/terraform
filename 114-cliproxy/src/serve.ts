import {
  proxy as proxyConfig,
  proxyModel,
  proxyProvider,
  getProxyProviderConfigError,
} from "./config.js"

const PROXY_PORT = proxyConfig.port
const PROXY_HOST = proxyConfig.hostname

interface ChatMessage {
  role: "system" | "user" | "assistant" | "tool"
  content: string | null | unknown[]
  tool_calls?: Array<{
    id: string
    type: "function"
    function: { name: string; arguments: string }
  }>
  tool_call_id?: string
}

interface ChatCompletionRequest {
  model?: string
  messages: ChatMessage[]
  temperature?: number
  max_tokens?: number
  stream?: boolean
}

interface ChatCompletionResponse {
  id: string
  object: "chat.completion"
  created: number
  model: string
  choices: Array<{
    index: number
    message: { role: "assistant"; content: string }
    finish_reason: string
  }>
  usage: {
    prompt_tokens: number
    completion_tokens: number
    total_tokens: number
  }
}

interface ModelObject {
  id: string
  object: string
  created: number
  owned_by: string
}

function resolveTargetModel(requestedModel?: string): string {
  const requested = (requestedModel ?? "").trim() || proxyModel.publicId
  const upstreamParts = proxyModel.targetId.split("/")
  const bareUpstreamModel =
    upstreamParts.length > 1 ? upstreamParts.slice(1).join("/") : proxyModel.targetId
  const accepted = new Set([
    proxyModel.publicId,
    proxyModel.targetId,
    bareUpstreamModel,
    ...proxyModel.aliases,
  ])

  if (accepted.has(requested)) {
    return proxyModel.targetId
  }

  return requested
}

function getRequestApiKey(req: Request): string | undefined {
  const auth = req.headers.get("authorization")
  if (!auth) return undefined
  const [scheme, token] = auth.split(/\s+/, 2)
  if (!scheme || !token) return undefined
  if (scheme.toLowerCase() !== "bearer") return undefined
  return token.trim() || undefined
}

function isAccessKeyAuth(req: Request): boolean {
  const token = getRequestApiKey(req)
  return !!proxyProvider.accessKey && token === proxyProvider.accessKey
}

function authGate(req: Request): Response | null {
  if (proxyProvider.accessKey && !isAccessKeyAuth(req)) {
    return Response.json(
      { error: { message: "Invalid or missing access key" } },
      { status: 401, headers: corsHeaders },
    )
  }
  return null
}

/** Map Responses API content parts to Chat Completions content parts. */
function mapContentPart(part: Record<string, unknown>): Record<string, unknown> {
  if (part.type === "input_text" || part.type === "output_text") {
    return { type: "text", text: String(part.text ?? "") }
  }
  if (part.type === "input_image") {
    // Responses API: { type: "input_image", image_url: "https://..." }
    // Chat Completions: { type: "image_url", image_url: { url: "https://..." } }
    const url = typeof part.image_url === "string"
      ? part.image_url
      : (part.image_url as Record<string, unknown> | undefined)?.url ?? part.url ?? ""
    return { type: "image_url", image_url: { url: String(url) } }
  }
  // text, image_url, input_audio, etc. — pass through unchanged
  return part
}

/** Collapse a mapped content array to a plain string when all parts are text. */
function collapseTextContent(parts: Record<string, unknown>[]): string | unknown[] {
  const allText = parts.every((p) => p.type === "text")
  if (allText) {
    return parts.map((p) => String(p.text ?? "")).join("")
  }
  return parts
}

function normalizeResponsesInput(input: unknown): ChatMessage[] {
  if (input === undefined || input === null) return []

  if (typeof input === "string") {
    return [{ role: "user", content: input }]
  }

  if (Array.isArray(input)) {
    return input.flatMap((item): ChatMessage[] => {
      if (typeof item === "string") {
        return [{ role: "user" as const, content: item }]
      }
      if (item && typeof item === "object" && "type" in item) {
        const rec = item as Record<string, unknown>

        // Responses API message item → Chat Completions message
        if (rec.type === "message") {
          const role = rec.role as ChatMessage["role"] ?? "user"
          const contentArr = rec.content
          if (typeof contentArr === "string") {
            return [{ role, content: contentArr }]
          }
          if (Array.isArray(contentArr)) {
            const mapped = contentArr.map((c) => mapContentPart(c as Record<string, unknown>))
            return [{ role, content: collapseTextContent(mapped) }]
          }
          return [{ role, content: "" as string }]
        }

        // Responses API function_call item → assistant message with tool_calls
        if (rec.type === "function_call") {
          return [{
            role: "assistant" as const,
            content: null,
            tool_calls: [{
              id: String(rec.call_id ?? rec.id ?? ""),
              type: "function" as const,
              function: {
                name: String(rec.name ?? ""),
                arguments: String(rec.arguments ?? "{}"),
              },
            }],
          }]
        }

        // Responses API function_call_output item → tool message
        if (rec.type === "function_call_output") {
          const rawOutput = rec.output
          const outputStr =
            rawOutput === undefined || rawOutput === null
              ? ""
              : typeof rawOutput === "string"
                ? rawOutput
                : JSON.stringify(rawOutput)
          return [{
            role: "tool" as const,
            content: outputStr,
            tool_call_id: String(rec.call_id ?? ""),
          }]
        }

        // Unsupported Responses API item types are skipped.
        return []
      }
      if (item && typeof item === "object" && "role" in item) {
        const rec = item as Record<string, unknown>
        const content = rec.content
        if (typeof content === "string" || content === null) {
          return [item as ChatMessage]
        }
        if (Array.isArray(content)) {
          const mapped = content.map((c) => mapContentPart(c as Record<string, unknown>))
          return [{ role: rec.role as ChatMessage["role"], content: collapseTextContent(mapped) }]
        }
        return [item as ChatMessage]
      }
      return [{ role: "user" as const, content: JSON.stringify(item) }]
    })
  }

  return [{ role: "user", content: JSON.stringify(input) }]
}

const UPSTREAM_TIMEOUT_MS = 60_000

async function upstreamChatCompletion(
  body: Record<string, unknown>,
): Promise<{ status: number; data: ChatCompletionResponse | Record<string, unknown> }> {
  const resolved = { ...body, model: resolveTargetModel(body.model as string | undefined) }
  const upstreamUrl = `${proxyProvider.baseUrl}/chat/completions`

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS)

  try {
    const response = await fetch(upstreamUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${proxyProvider.apiKey}`,
      },
      body: JSON.stringify(resolved),
      signal: controller.signal,
    })

    const responseBody = await response.json() as ChatCompletionResponse | Record<string, unknown>
    return { status: response.status, data: responseBody }
  } finally {
    clearTimeout(timer)
  }
}

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
}

let cachedModels: ModelObject[] | null = null
let cachedModelsAt = 0
const MODEL_CACHE_TTL_MS = 5 * 60 * 1000

async function fetchUpstreamModels(): Promise<ModelObject[]> {
  const now = Date.now()
  if (cachedModels && now - cachedModelsAt < MODEL_CACHE_TTL_MS) {
    return cachedModels
  }

  try {
    const resp = await fetch(`${proxyProvider.baseUrl}/models`, {
      headers: { Authorization: `Bearer ${proxyProvider.apiKey}` },
    })
    if (!resp.ok) throw new Error(`${resp.status}`)
    const body = (await resp.json()) as { data?: ModelObject[] }
    let upstream = body.data ?? []

    upstream.sort((a, b) => b.created - a.created)

    const limit = proxyModel.modelsLimit
    if (limit > 0 && upstream.length > limit) {
      upstream = upstream.slice(0, limit)
    }

    const aliasModel: ModelObject = {
      id: proxyModel.publicId,
      object: "model",
      created: Math.floor(now / 1000),
      owned_by: "opencode",
    }

    const hasAlias = upstream.some((m) => m.id === proxyModel.publicId)
    cachedModels = hasAlias ? upstream : [aliasModel, ...upstream]
    cachedModelsAt = now
    return cachedModels
  } catch (err) {
    console.error("Failed to fetch upstream models:", err)
    const ts = Math.floor(now / 1000)
    return [
      { id: proxyModel.publicId, object: "model", created: ts, owned_by: "opencode" },
      { id: proxyModel.targetId, object: "model", created: ts, owned_by: "opencode" },
    ]
  }
}

async function main(): Promise<void> {
  const configError = getProxyProviderConfigError()
  if (configError) {
    throw new Error(configError)
  }

  fetchUpstreamModels().catch(() => {})

  Bun.serve({
    port: PROXY_PORT,
    hostname: PROXY_HOST,
    fetch: async (req) => {
      const url = new URL(req.url)
      const rawPath = url.pathname
      const path = rawPath.replace(/^(\/v1)+/, "") || "/"
      const reqStart = Date.now()

      const respond = (res: Response) => {
        console.log(`${res.status} ${req.method} ${rawPath} ${Date.now() - reqStart}ms`)
        return res
      }

      if (req.method === "OPTIONS") {
        return respond(new Response(null, { status: 204, headers: corsHeaders }))
      }

      if (rawPath === "/health") {
        return respond(Response.json({ healthy: true }, { headers: corsHeaders }))
      }

      if (path.startsWith("/models") && req.method === "GET") {
        const models = await fetchUpstreamModels()
        const modelIdSuffix = path.replace(/^\/models\/?/, "")

        if (modelIdSuffix) {
          const decoded = decodeURIComponent(modelIdSuffix)
          const found = models.find((m) => m.id === decoded)
          if (found) {
            return respond(Response.json(found, { headers: corsHeaders }))
          }
          return respond(Response.json(
            { error: { message: `Model '${decoded}' not found`, type: "invalid_request_error", code: "model_not_found" } },
            { status: 404, headers: corsHeaders },
          ))
        }

        return respond(Response.json({ object: "list", data: models }, { headers: corsHeaders }))
      }

      if (path === "/responses" && req.method === "POST") {
        const denied = authGate(req)
        if (denied) return respond(denied)

        try {
          const body = await req.json() as Record<string, unknown>

          if (body.stream) {
            const messages = normalizeResponsesInput(body.input)
            if (!messages.length) {
              return respond(Response.json(
                { error: { message: "No input provided" } },
                { status: 400, headers: corsHeaders },
              ))
            }

            if (body.instructions && typeof body.instructions === "string") {
              messages.unshift({ role: "system", content: body.instructions })
            }

            const responsesOnlyKeys = new Set([
              "input", "instructions", "stream", "previous_response_id",
              "truncation", "metadata", "store",
            ])

            const upstreamBody: Record<string, unknown> = { messages, stream: true }
            for (const [key, value] of Object.entries(body)) {
              if (!responsesOnlyKeys.has(key) && key !== "messages" && value !== undefined) {
                upstreamBody[key] = value
              }
            }

            if (body.max_output_tokens !== undefined && upstreamBody.max_tokens === undefined) {
              upstreamBody.max_tokens = body.max_output_tokens
              delete upstreamBody.max_output_tokens
            }

            upstreamBody.model = resolveTargetModel(upstreamBody.model as string | undefined)

            const upstreamUrl = `${proxyProvider.baseUrl}/chat/completions`
            const upstream = await fetch(upstreamUrl, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${proxyProvider.apiKey}`,
              },
              body: JSON.stringify(upstreamBody),
            })

            if (!upstream.ok) {
              let upstreamError: Record<string, unknown>
              try {
                upstreamError = await upstream.json() as Record<string, unknown>
              } catch {
                const text = await upstream.text()
                upstreamError = { error: { message: text || "Upstream error" } }
              }
              return respond(Response.json(upstreamError, { status: upstream.status, headers: corsHeaders }))
            }

            if (!upstream.body) {
              return respond(Response.json(
                { error: { message: "Upstream did not provide a stream body" } },
                { status: 502, headers: corsHeaders },
              ))
            }

            function sseEvent(event: string, data: unknown): string {
              return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`
            }

            const encoder = new TextEncoder()
            const respId = `resp_${crypto.randomUUID().replace(/-/g, "").slice(0, 24)}`
            const msgId = `msg_${crypto.randomUUID().replace(/-/g, "").slice(0, 24)}`

            let responseCreatedSent = false
            let textStarted = false
            let accumulatedText = ""
            let sawDone = false
            let createdAt = Math.floor(Date.now() / 1000)
            let model = String(upstreamBody.model ?? proxyModel.targetId)
            let latestUsage: {
              prompt_tokens?: number
              completion_tokens?: number
              total_tokens?: number
            } | null = null

            const toolCalls = new Map<number, {
              id: string
              callId: string
              name: string
              arguments: string
              outputIndex: number
            }>()

            const translated = new ReadableStream<Uint8Array>({
              start(controller) {
                const ensureResponseCreated = () => {
                  if (responseCreatedSent) return
                  responseCreatedSent = true
                  controller.enqueue(encoder.encode(sseEvent("response.created", {
                    type: "response.created",
                    response: {
                      id: respId,
                      object: "response",
                      created_at: createdAt,
                      status: "in_progress",
                      output: [],
                      model,
                    },
                  })))
                }

                const reader = upstream.body!.getReader()
                const decoder = new TextDecoder()
                let buffer = ""

                const processChunk = (chunk: Record<string, unknown>) => {
                  if (typeof chunk.created === "number") {
                    createdAt = chunk.created
                  }
                  if (typeof chunk.model === "string" && chunk.model) {
                    model = chunk.model
                  }

                  if (chunk.usage && typeof chunk.usage === "object") {
                    const usage = chunk.usage as Record<string, unknown>
                    latestUsage = {
                      prompt_tokens: typeof usage.prompt_tokens === "number" ? usage.prompt_tokens : undefined,
                      completion_tokens: typeof usage.completion_tokens === "number" ? usage.completion_tokens : undefined,
                      total_tokens: typeof usage.total_tokens === "number" ? usage.total_tokens : undefined,
                    }
                  }

                  const choices = Array.isArray(chunk.choices) ? chunk.choices : []
                  for (const choiceRaw of choices) {
                    const choice = choiceRaw as Record<string, unknown>
                    const delta = (choice.delta && typeof choice.delta === "object")
                      ? choice.delta as Record<string, unknown>
                      : undefined
                    if (!delta) continue

                    const contentDelta = typeof delta.content === "string" ? delta.content : ""
                    if (contentDelta) {
                      ensureResponseCreated()
                      if (!textStarted) {
                        textStarted = true
                        controller.enqueue(encoder.encode(sseEvent("response.output_item.added", {
                          type: "response.output_item.added",
                          output_index: 0,
                          item: {
                            type: "message",
                            id: msgId,
                            role: "assistant",
                            status: "in_progress",
                            content: [],
                          },
                        })))
                        controller.enqueue(encoder.encode(sseEvent("response.content_part.added", {
                          type: "response.content_part.added",
                          output_index: 0,
                          content_index: 0,
                          part: { type: "output_text", text: "" },
                        })))
                      }

                      accumulatedText += contentDelta
                      controller.enqueue(encoder.encode(sseEvent("response.output_text.delta", {
                        type: "response.output_text.delta",
                        output_index: 0,
                        content_index: 0,
                        delta: contentDelta,
                      })))
                    }

                    const deltaToolCalls = Array.isArray(delta.tool_calls)
                      ? delta.tool_calls as Array<Record<string, unknown>>
                      : []

                    for (const tc of deltaToolCalls) {
                      const idx = typeof tc.index === "number" ? tc.index : 0
                      const fn = (tc.function && typeof tc.function === "object")
                        ? tc.function as Record<string, unknown>
                        : undefined

                      let existing = toolCalls.get(idx)
                      if (!existing) {
                        existing = {
                          id: `fc_${crypto.randomUUID().replace(/-/g, "").slice(0, 24)}`,
                          callId: typeof tc.id === "string" ? tc.id : "",
                          name: typeof fn?.name === "string" ? fn.name : "",
                          arguments: "",
                          outputIndex: idx + 1,
                        }
                        toolCalls.set(idx, existing)
                        ensureResponseCreated()
                        controller.enqueue(encoder.encode(sseEvent("response.output_item.added", {
                          type: "response.output_item.added",
                          output_index: existing.outputIndex,
                          item: {
                            type: "function_call",
                            id: existing.id,
                            call_id: existing.callId,
                            name: existing.name,
                            arguments: "",
                            status: "in_progress",
                          },
                        })))
                      }

                      if (typeof tc.id === "string" && tc.id) {
                        existing.callId = tc.id
                      }
                      if (typeof fn?.name === "string" && fn.name) {
                        existing.name = fn.name
                      }
                      if (typeof fn?.arguments === "string") {
                        existing.arguments += fn.arguments
                        controller.enqueue(encoder.encode(sseEvent("response.function_call_arguments.delta", {
                          type: "response.function_call_arguments.delta",
                          output_index: existing.outputIndex,
                          delta: fn.arguments,
                        })))
                      }
                    }
                  }
                }

                const finalize = () => {
                  if (textStarted) {
                    controller.enqueue(encoder.encode(sseEvent("response.content_part.done", {
                      type: "response.content_part.done",
                      output_index: 0,
                      content_index: 0,
                      part: { type: "output_text", text: accumulatedText },
                    })))
                    controller.enqueue(encoder.encode(sseEvent("response.output_item.done", {
                      type: "response.output_item.done",
                      output_index: 0,
                      item: {
                        type: "message",
                        id: msgId,
                        role: "assistant",
                        status: "completed",
                        content: [{ type: "output_text", text: accumulatedText }],
                      },
                    })))
                  }

                  const toolList = [...toolCalls.entries()].sort((a, b) => a[0] - b[0]).map(([, tc]) => tc)
                  for (const tc of toolList) {
                    controller.enqueue(encoder.encode(sseEvent("response.function_call_arguments.done", {
                      type: "response.function_call_arguments.done",
                      output_index: tc.outputIndex,
                      arguments: tc.arguments,
                    })))
                    controller.enqueue(encoder.encode(sseEvent("response.output_item.done", {
                      type: "response.output_item.done",
                      output_index: tc.outputIndex,
                      item: {
                        type: "function_call",
                        id: tc.id,
                        call_id: tc.callId,
                        name: tc.name,
                        arguments: tc.arguments,
                        status: "completed",
                      },
                    })))
                  }

                  const output: Record<string, unknown>[] = []
                  if (textStarted || toolList.length === 0) {
                    output.push({
                      type: "message",
                      id: msgId,
                      role: "assistant",
                      status: "completed",
                      content: [{ type: "output_text", text: accumulatedText }],
                    })
                  }
                  for (const tc of toolList) {
                    output.push({
                      type: "function_call",
                      id: tc.id,
                      call_id: tc.callId,
                      name: tc.name,
                      arguments: tc.arguments,
                      status: "completed",
                    })
                  }

                  const responseObj = {
                    id: respId,
                    object: "response",
                    created_at: createdAt,
                    status: "completed",
                    model,
                    output,
                    usage: {
                      input_tokens: latestUsage?.prompt_tokens ?? 0,
                      output_tokens: latestUsage?.completion_tokens ?? 0,
                      total_tokens: latestUsage?.total_tokens ?? 0,
                    },
                  }

                  ensureResponseCreated()
                  controller.enqueue(encoder.encode(sseEvent("response.completed", {
                    type: "response.completed",
                    response: responseObj,
                  })))
                  controller.enqueue(encoder.encode(sseEvent("response.done", {
                    type: "response.done",
                    response: responseObj,
                  })))
                }

                const pump = async (): Promise<void> => {
                  try {
                    while (true) {
                      const { value, done } = await reader.read()
                      if (done) break
                      buffer += decoder.decode(value, { stream: true })

                      let lineBreak = buffer.indexOf("\n")
                      while (lineBreak >= 0) {
                        const rawLine = buffer.slice(0, lineBreak)
                        buffer = buffer.slice(lineBreak + 1)
                        const line = rawLine.endsWith("\r") ? rawLine.slice(0, -1) : rawLine

                        if (line.startsWith("data:")) {
                          const payload = line.slice(5).trimStart()
                          if (payload === "[DONE]") {
                            sawDone = true
                            break
                          }
                          if (payload) {
                            try {
                              const parsed = JSON.parse(payload) as Record<string, unknown>
                              processChunk(parsed)
                            } catch {
                            }
                          }
                        }

                        lineBreak = buffer.indexOf("\n")
                      }

                      if (sawDone) {
                        break
                      }
                    }

                    finalize()
                    controller.close()
                  } catch (error) {
                    const message = error instanceof Error ? error.message : String(error)
                    controller.enqueue(encoder.encode(sseEvent("error", {
                      type: "error",
                      error: { message },
                    })))
                    controller.close()
                  }
                }

                void pump()
              },
            })

            return respond(new Response(translated, {
              status: 200,
              headers: {
                ...corsHeaders,
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                Connection: "keep-alive",
              },
            }))
          }

          const messages = normalizeResponsesInput(body.input)
          if (!messages.length) {
            return respond(Response.json(
              { error: { message: "No input provided" } },
              { status: 400, headers: corsHeaders },
            ))
          }

          if (body.instructions && typeof body.instructions === "string") {
            messages.unshift({ role: "system", content: body.instructions })
          }

          const responsesOnlyKeys = new Set([
            "input", "instructions", "stream", "previous_response_id",
            "truncation", "metadata", "store",
          ])

          const upstreamBody: Record<string, unknown> = { messages }
          for (const [key, value] of Object.entries(body)) {
            if (!responsesOnlyKeys.has(key) && key !== "messages" && value !== undefined) {
              upstreamBody[key] = value
            }
          }

          if (body.max_output_tokens !== undefined && upstreamBody.max_tokens === undefined) {
            upstreamBody.max_tokens = body.max_output_tokens
            delete upstreamBody.max_output_tokens
          }

          const { status, data } = await upstreamChatCompletion(upstreamBody)

          if (status >= 400) {
            return respond(Response.json(data, { status, headers: corsHeaders }))
          }

          const result = data as ChatCompletionResponse
          const choice = result.choices?.[0]
          const assistantContent = choice?.message?.content
          const rawMessage = choice?.message as Record<string, unknown> | undefined
          const toolCalls = rawMessage?.tool_calls as unknown[] | undefined
          const respId = `resp_${crypto.randomUUID().replace(/-/g, "").slice(0, 24)}`

          const output: Record<string, unknown>[] = []

          if (assistantContent) {
            output.push({
              type: "message",
              id: `msg_${crypto.randomUUID().replace(/-/g, "").slice(0, 24)}`,
              role: "assistant",
              status: "completed",
              content: [{ type: "output_text", text: assistantContent }],
            })
          }

          if (Array.isArray(toolCalls)) {
            for (const tc of toolCalls) {
              const call = tc as Record<string, unknown>
              const fn = call.function as Record<string, unknown> | undefined
              output.push({
                type: "function_call",
                id: `fc_${crypto.randomUUID().replace(/-/g, "").slice(0, 24)}`,
                call_id: String(call.id ?? ""),
                name: String(fn?.name ?? ""),
                arguments: String(fn?.arguments ?? "{}"),
                status: "completed",
              })
            }
          }

          if (output.length === 0) {
            output.push({
              type: "message",
              id: `msg_${crypto.randomUUID().replace(/-/g, "").slice(0, 24)}`,
              role: "assistant",
              status: "completed",
              content: [{ type: "output_text", text: "" }],
            })
          }

          return respond(Response.json({
            id: respId,
            object: "response",
            created_at: result.created,
            status: "completed",
            model: result.model,
            output,
            usage: {
              input_tokens: result.usage?.prompt_tokens ?? 0,
              output_tokens: result.usage?.completion_tokens ?? 0,
              total_tokens: result.usage?.total_tokens ?? 0,
            },
          }, { headers: corsHeaders }))
        } catch (error) {
          console.error("Responses API error:", error)
          const errorMessage = error instanceof Error ? error.message : String(error)
          return respond(Response.json(
            { error: { message: errorMessage } },
            { status: 502, headers: corsHeaders },
          ))
        }
      }

      if (path === "/chat/completions" && req.method === "POST") {
        const denied = authGate(req)
        if (denied) return respond(denied)

        try {
          const body = (await req.json()) as Record<string, unknown>

          if (body.stream) {
            const resolvedBody = {
              ...body,
              stream: true,
              model: resolveTargetModel(body.model as string | undefined),
            }
            const upstreamUrl = `${proxyProvider.baseUrl}/chat/completions`
            const upstream = await fetch(upstreamUrl, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${proxyProvider.apiKey}`,
              },
              body: JSON.stringify(resolvedBody),
            })

            if (!upstream.ok) {
              let upstreamError: Record<string, unknown>
              try {
                upstreamError = await upstream.json() as Record<string, unknown>
              } catch {
                const text = await upstream.text()
                upstreamError = { error: { message: text || "Upstream error" } }
              }
              return respond(Response.json(upstreamError, { status: upstream.status, headers: corsHeaders }))
            }

            if (!upstream.body) {
              return respond(Response.json(
                { error: { message: "Upstream did not provide a stream body" } },
                { status: 502, headers: corsHeaders },
              ))
            }

            return respond(new Response(upstream.body, {
              status: upstream.status,
              headers: {
                ...corsHeaders,
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                Connection: "keep-alive",
              },
            }))
          }

          const messages = body.messages as unknown[] | undefined
          if (!messages?.length) {
            return respond(Response.json(
              { error: { message: "No messages provided" } },
              { status: 400, headers: corsHeaders },
            ))
          }

          const { status, data } = await upstreamChatCompletion(body)
          return respond(Response.json(data, { status, headers: corsHeaders }))
        } catch (error) {
          console.error("Chat completion error:", error)
          const errorMessage = error instanceof Error ? error.message : String(error)
          return respond(Response.json(
            { error: { message: errorMessage } },
            { status: 502, headers: corsHeaders },
          ))
        }
      }

      if (req.method === "POST") {
        const denied = authGate(req)
        if (denied) return respond(denied)

        try {
          const body = await req.json()
          if (body.model) {
            body.model = resolveTargetModel(body.model)
          }

          const upstreamUrl = `${proxyProvider.baseUrl}${path}`
          const upstream = await fetch(upstreamUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${proxyProvider.apiKey}`,
            },
            body: JSON.stringify(body),
          })

          const responseBody = await upstream.text()
          return respond(new Response(responseBody, {
            status: upstream.status,
            headers: {
              ...corsHeaders,
              "Content-Type": upstream.headers.get("Content-Type") ?? "application/json",
            },
          }))
        } catch (error) {
          console.error(`Proxy error (${path}):`, error)
          const errorMessage = error instanceof Error ? error.message : String(error)
          return respond(Response.json(
            { error: { message: errorMessage } },
            { status: 502, headers: corsHeaders },
          ))
        }
      }

      return respond(Response.json(
        { error: { message: "Not found" } },
        { status: 404, headers: corsHeaders },
      ))
    },
  })

  console.log(`OpenAI-compatible proxy listening on http://${PROXY_HOST}:${PROXY_PORT}`)
  console.log(`n8n base URL: http://<this-host>:${PROXY_PORT}/v1`)
  console.log(`Upstream: ${proxyProvider.baseUrl} → default model: ${proxyModel.targetId}`)

  process.on("SIGINT", () => {
    console.log("\nShutting down...")
    process.exit(0)
  })
}

main().catch((error: unknown) => {
  console.error("Fatal:", error)
  process.exit(1)
})
