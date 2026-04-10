#!/usr/bin/env node

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { randomBytes, randomInt } from "node:crypto";

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ErrorCode,
  McpError,
} from "@modelcontextprotocol/sdk/types.js";

// Clear Connect env vars to prevent op CLI conflict — use SA token only
delete process.env.OP_CONNECT_HOST;
delete process.env.OP_CONNECT_TOKEN;

const execFileAsync = promisify(execFile);
const OP_BIN = process.env.OP_BIN || "/usr/bin/op";

async function opExec(args) {
  const { stdout } = await execFileAsync(OP_BIN, [...args, "--format=json"]);
  return JSON.parse(stdout);
}

async function opExecRaw(args) {
  const { stdout } = await execFileAsync(OP_BIN, args);
  return stdout;
}
const SYMBOLS = "!@#$%^&*-_+=";
const LOWERCASE = "abcdefghijklmnopqrstuvwxyz";
const UPPERCASE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const DIGITS = "0123456789";

const MEMORABLE_WORDS = [
  "apple",
  "anchor",
  "amber",
  "arrow",
  "baker",
  "beacon",
  "berry",
  "breeze",
  "cabin",
  "candle",
  "captain",
  "cedar",
  "cherry",
  "cloud",
  "coral",
  "crystal",
  "delta",
  "dolphin",
  "ember",
  "falcon",
  "field",
  "forest",
  "galaxy",
  "garden",
  "glacier",
  "harbor",
  "hazel",
  "island",
  "jungle",
  "kernel",
  "ladder",
  "lantern",
  "lemon",
  "lotus",
  "maple",
  "marble",
  "meadow",
  "mercury",
  "mint",
  "nebula",
  "oasis",
  "ocean",
  "opal",
  "orbit",
  "pebble",
  "pepper",
  "phoenix",
  "planet",
  "prairie",
  "quartz",
  "ranger",
  "river",
  "rocket",
  "saddle",
  "saffron",
  "sierra",
  "silver",
  "solar",
  "spruce",
  "sunset",
  "tango",
  "thunder",
  "timber",
  "topaz",
  "trident",
  "tulip",
  "valley",
  "velvet",
  "violet",
  "voyage",
  "willow",
  "winter",
  "wizard",
  "xenon",
  "yonder",
  "zephyr",
  "acorn",
  "brick",
  "copper",
  "drift",
  "eagle",
  "frozen",
  "grove",
  "horizon",
  "iris",
  "jasmine",
  "knight",
  "lunar",
  "mango",
  "nectar",
];

function toJsonResponse(data) {
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(data),
      },
    ],
    structuredContent: data,
  };
}

function normalizeOpError(error) {
  const msg = error instanceof Error ? error.message : String(error);
  if (msg.includes("401")) {
    return {
      code: "AUTH_ERROR",
      message: "Authentication failed - check OP_CONNECT_TOKEN",
    };
  }
  if (msg.includes("403")) {
    return {
      code: "FORBIDDEN",
      message: "Access denied to this vault or item",
    };
  }
  if (msg.includes("404")) {
    return {
      code: "NOT_FOUND",
      message: "Vault or item not found",
    };
  }
  if (msg.includes("429")) {
    return {
      code: "RATE_LIMITED",
      message: "Rate limited by Connect Server",
    };
  }
  return { code: "OP_ERROR", message: msg };
}

async function resolveSecretReference(ref) {
  // op read supports op:// references directly
  const result = await opExecRaw(["read", ref]);
  return result.trim();
}

function requireString(value, name) {
  if (typeof value !== "string" || value.length === 0) {
    throw new McpError(
      ErrorCode.InvalidParams,
      `${name} must be a non-empty string`,
    );
  }
}

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

function shouldRedactField(field, explicitField) {
  const keys = [
    field?.id,
    field?.label,
    field?.title,
    field?.purpose,
    field?.type,
  ]
    .filter((v) => typeof v === "string")
    .map((v) => v.toLowerCase());

  if (explicitField && keys.includes(explicitField.toLowerCase())) {
    return true;
  }

  return keys.some(
    (key) => key.includes("password") || key.includes("concealed"),
  );
}

function redactItemSecrets(item, explicitField) {
  const clone = deepClone(item);
  if (Array.isArray(clone.fields)) {
    clone.fields = clone.fields.map((field) => {
      if (
        field &&
        typeof field === "object" &&
        "value" in field &&
        shouldRedactField(field, explicitField)
      ) {
        return { ...field, value: "REDACTED" };
      }
      return field;
    });
  }

  if (clone.password) {
    clone.password = "REDACTED"; // pragma: allowlist secret
  }

  return clone;
}

function metadataOnlyItem(item) {
  const clone = deepClone(item);
  if (Array.isArray(clone.fields)) {
    clone.fields = clone.fields.map((field) => {
      if (!field || typeof field !== "object") {
        return field;
      }
      const fieldClone = { ...field };
      delete fieldClone.value;
      return fieldClone;
    });
  }
  return clone;
}

function randomChar(charset) {
  const max = 256 - (256 % charset.length);
  while (true) {
    const byte = randomBytes(1)[0];
    if (byte < max) {
      return charset[byte % charset.length];
    }
  }
}

function generatePassword({
  length = 20,
  includeSymbols = true,
  includeNumbers = true,
  includeUppercase = true,
}) {
  if (!Number.isInteger(length) || length < 8 || length > 128) {
    throw new McpError(
      ErrorCode.InvalidParams,
      "length must be an integer between 8 and 128",
    );
  }

  let charset = LOWERCASE;
  if (includeUppercase) {
    charset += UPPERCASE;
  }
  if (includeNumbers) {
    charset += DIGITS;
  }
  if (includeSymbols) {
    charset += SYMBOLS;
  }

  let output = "";
  for (let i = 0; i < length; i += 1) {
    output += randomChar(charset);
  }
  return output;
}

function capitalizeWord(word) {
  return word.charAt(0).toUpperCase() + word.slice(1);
}

function generateMemorablePassword({
  wordCount = 3,
  separator = "-",
  includeNumber = true,
  includeSymbol = true,
  capitalize = true,
}) {
  if (!Number.isInteger(wordCount) || wordCount < 2 || wordCount > 10) {
    throw new McpError(
      ErrorCode.InvalidParams,
      "wordCount must be an integer between 2 and 10",
    );
  }
  if (typeof separator !== "string") {
    throw new McpError(ErrorCode.InvalidParams, "separator must be a string");
  }

  const words = [];
  for (let i = 0; i < wordCount; i += 1) {
    const word = MEMORABLE_WORDS[randomInt(0, MEMORABLE_WORDS.length)];
    words.push(capitalize ? capitalizeWord(word) : word);
  }

  let output = words.join(separator);
  if (includeNumber) {
    output += String(randomInt(0, 100));
  }
  if (includeSymbol) {
    output += SYMBOLS[randomInt(0, SYMBOLS.length)];
  }
  return output;
}

const tools = [
  {
    name: "vault_list",
    description: "List available 1Password vaults",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: "item_lookup",
    description: "Look up items in a vault by title",
    inputSchema: {
      type: "object",
      properties: {
        vaultId: { type: "string" },
        query: { type: "string" },
        limit: { type: "integer", minimum: 1, maximum: 200 },
      },
      required: ["vaultId"],
      additionalProperties: false,
    },
  },
  {
    name: "item_delete",
    description: "Delete an item from a vault",
    inputSchema: {
      type: "object",
      properties: {
        vaultId: { type: "string" },
        itemId: { type: "string" },
      },
      required: ["vaultId", "itemId"],
      additionalProperties: false,
    },
  },
  {
    name: "password_create",
    description: "Create a password or login item",
    inputSchema: {
      type: "object",
      properties: {
        vaultId: { type: "string" },
        title: { type: "string" },
        password: { type: "string" },
        username: { type: "string" },
        category: { type: "string", enum: ["Login", "Password"] },
        tags: { type: "array", items: { type: "string" } },
        notes: { type: "string" },
        url: { type: "string" },
        returnSecret: { type: "boolean" },
      },
      required: ["vaultId", "title", "password"],
      additionalProperties: false,
    },
  },
  {
    name: "password_read",
    description: "Read a secret reference or item data",
    inputSchema: {
      type: "object",
      properties: {
        secretReference: { type: "string" },
        vaultId: { type: "string" },
        itemId: { type: "string" },
        field: { type: "string", default: "password" },
        reveal: { type: "boolean", default: true },
      },
      additionalProperties: false,
    },
  },
  {
    name: "password_update",
    description: "Update a concealed field on an item",
    inputSchema: {
      type: "object",
      properties: {
        vaultId: { type: "string" },
        itemId: { type: "string" },
        newPassword: { type: "string" },
        field: { type: "string", default: "password" },
        returnSecret: { type: "boolean" },
      },
      required: ["vaultId", "itemId", "newPassword"],
      additionalProperties: false,
    },
  },
  {
    name: "password_generate",
    description: "Generate a random password",
    inputSchema: {
      type: "object",
      properties: {
        length: { type: "integer", minimum: 8, maximum: 128, default: 20 },
        includeSymbols: { type: "boolean", default: true },
        includeNumbers: { type: "boolean", default: true },
        includeUppercase: { type: "boolean", default: true },
      },
      additionalProperties: false,
    },
  },
  {
    name: "password_generate_memorable",
    description: "Generate a memorable passphrase",
    inputSchema: {
      type: "object",
      properties: {
        wordCount: { type: "integer", minimum: 2, maximum: 10, default: 3 },
        separator: { type: "string", default: "-", maxLength: 5 },
        includeNumber: { type: "boolean", default: true },
        includeSymbol: { type: "boolean", default: true },
        capitalize: { type: "boolean", default: true },
      },
      additionalProperties: false,
    },
  },
];

const server = new Server(
  {
    name: "op-mcp-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const toolName = request.params.name;
  const args = request.params.arguments ?? {};
  try {
    switch (toolName) {
      case "vault_list": {
        const vaults = await opExec(["vault", "list"]);
        return toJsonResponse({
          vaults: Array.isArray(vaults)
            ? vaults.map((v) => ({ id: v.id, name: v.name, description: v.description, type: v.type }))
            : [],
        });
      }

      case "item_lookup": {
        const { vaultId, query, limit } = args;
        requireString(vaultId, "vaultId");
        let items = await opExec(["item", "list", "--vault", vaultId]);
        if (!Array.isArray(items)) items = [];
        if (typeof query === "string" && query.length > 0) {
          const q = query.toLowerCase();
          items = items.filter((i) => i.title?.toLowerCase().includes(q));
        }
        if (Number.isInteger(limit) && limit > 0) items = items.slice(0, limit);
        return toJsonResponse({
          items: items.map((i) => ({ id: i.id, title: i.title, category: i.category, vault_id: vaultId })),
        });
      }

      case "item_delete": {
        const { vaultId, itemId } = args;
        requireString(vaultId, "vaultId");
        requireString(itemId, "itemId");
        await opExecRaw(["item", "delete", itemId, "--vault", vaultId]);
        return toJsonResponse({ success: true });
      }

      case "password_create": {
        const { vaultId, title, password, username, category = "Login", tags, notes, url, returnSecret = false } = args;
        requireString(vaultId, "vaultId");
        requireString(title, "title");
        requireString(password, "password");
        if (category !== "Login" && category !== "Password")
          throw new McpError(ErrorCode.InvalidParams, "category must be Login or Password");
        const opArgs = ["item", "create", "--vault", vaultId, "--category", category, "--title", title, `password=${password}`];
        if (typeof username === "string" && username.length > 0) opArgs.push(`username=${username}`);
        if (typeof url === "string" && url.length > 0) opArgs.push("--url", url);
        if (typeof notes === "string" && notes.length > 0) opArgs.push(`notesPlain=${notes}`);
        if (Array.isArray(tags) && tags.length > 0) opArgs.push("--tags", tags.join(","));
        const created = await opExec(opArgs);
        return toJsonResponse(returnSecret ? created : redactItemSecrets(created, "password"));
      }

      case "password_read": {
        const {
          secretReference,
          vaultId,
          itemId,
          field = "password",
          reveal = true,
        } = args;

        if (
          typeof secretReference === "string" &&
          secretReference.length > 0
        ) {
          if (!reveal) {
            return toJsonResponse({ secretReference });
          }
          const value = await resolveSecretReference(secretReference);
          return toJsonResponse({ value });
        }

        if (
          typeof vaultId === "string" &&
          vaultId.length > 0 &&
          typeof itemId === "string" &&
          itemId.length > 0
        ) {
          const item = await opExec(["item", "get", itemId, "--vault", vaultId]);
          if (!reveal) return toJsonResponse(metadataOnlyItem(item));
          return toJsonResponse(item);
        }

        throw new McpError(
          ErrorCode.InvalidParams,
          "Provide either secretReference or both vaultId and itemId",
        );
      }

      case "password_update": {
        const { vaultId, itemId, newPassword, field = "password", returnSecret = false } = args;
        requireString(vaultId, "vaultId");
        requireString(itemId, "itemId");
        requireString(newPassword, "newPassword");
        const updated = await opExec(["item", "edit", itemId, "--vault", vaultId, `${field}=${newPassword}`]);
        return toJsonResponse(returnSecret ? updated : redactItemSecrets(updated, field));
      }

      case "password_generate": {
        const generated = generatePassword(args);
        return toJsonResponse({ password: generated });
      }

      case "password_generate_memorable": {
        const generated = generateMemorablePassword(args);
        return toJsonResponse({ password: generated });
      }

      default:
        throw new McpError(
          ErrorCode.MethodNotFound,
          `Unknown tool: ${toolName}`,
        );
    }
  } catch (error) {
    if (error instanceof McpError) {
      throw error;
    }
    const normalized = normalizeOpError(error);
    throw new McpError(
      ErrorCode.InternalError,
      `${normalized.code}: ${normalized.message}`,
    );
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});
