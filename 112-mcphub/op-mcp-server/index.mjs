#!/usr/bin/env node

import { randomBytes, randomInt } from "node:crypto";

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ErrorCode,
  McpError,
} from "@modelcontextprotocol/sdk/types.js";

const OP_CONNECT_HOST = process.env.OP_CONNECT_HOST;
const OP_CONNECT_TOKEN = process.env.OP_CONNECT_TOKEN;

if (!OP_CONNECT_HOST || !OP_CONNECT_TOKEN) {
  process.stderr.write(
    "Missing OP_CONNECT_HOST or OP_CONNECT_TOKEN environment variables\n",
  );
  process.exit(1);
}

async function opFetch(path, options = {}) {
  const url = `${OP_CONNECT_HOST}/v1${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${OP_CONNECT_TOKEN}`,
      "Content-Type": "application/json",
      ...options.headers,
    },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`1Password Connect API error ${res.status}: ${body}`);
  }
  if (res.status === 204) {
    return null;
  }
  return res.json();
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
  const match = ref.match(/^op:\/\/([^/]+)\/([^/]+)\/(.+)$/);
  if (!match) {
    throw new Error(`Invalid secret reference: ${ref}`);
  }

  const vaultName = decodeURIComponent(match[1]);
  const itemName = decodeURIComponent(match[2]);
  const fieldPath = decodeURIComponent(match[3]);

  const vaults = await opFetch("/vaults");
  const vault = vaults.find(
    (candidate) => candidate.name === vaultName || candidate.id === vaultName,
  );
  if (!vault) {
    throw new Error(`Vault not found: ${vaultName}`);
  }

  const filter = encodeURIComponent(`title eq "${itemName}"`);
  const items = await opFetch(`/vaults/${vault.id}/items?filter=${filter}`);
  if (!items.length) {
    throw new Error(`Item not found: ${itemName}`);
  }

  const item = await opFetch(`/vaults/${vault.id}/items/${items[0].id}`);
  const parts = fieldPath.split("/");
  let field;
  if (parts.length === 1) {
    field = item.fields?.find(
      (candidate) =>
        candidate.label === parts[0] || candidate.id === parts[0],
    );
  } else {
    field = item.fields?.find(
      (candidate) =>
        candidate.section?.label === parts[0] &&
        (candidate.label === parts[1] || candidate.id === parts[1]),
    );
  }

  if (!field) {
    throw new Error(`Field not found: ${fieldPath}`);
  }
  return field.value;
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
        const vaults = await opFetch("/vaults");
        return toJsonResponse({
          vaults: Array.isArray(vaults)
            ? vaults.map((vault) => ({
                id: vault.id,
                name: vault.name,
                description: vault.description,
                type: vault.type,
              }))
            : [],
        });
      }

      case "item_lookup": {
        const { vaultId, query, limit } = args;
        requireString(vaultId, "vaultId");

        const queryParams = new URLSearchParams();
        if (typeof query === "string" && query.length > 0) {
          queryParams.set("filter", `title co \"${query}\"`);
        }

        const querySuffix = queryParams.toString()
          ? `?${queryParams.toString()}`
          : "";
        let items = await opFetch(
          `/vaults/${encodeURIComponent(vaultId)}/items${querySuffix}`,
        );
        if (!Array.isArray(items)) {
          items = [];
        }

        if (typeof limit !== "undefined") {
          if (!Number.isInteger(limit) || limit < 1) {
            throw new McpError(
              ErrorCode.InvalidParams,
              "limit must be a positive integer",
            );
          }
          items = items.slice(0, limit);
        }

        return toJsonResponse({
          items: items.map((item) => ({
            id: item.id,
            title: item.title,
            category: item.category,
            vault_id: item.vault?.id ?? item.vault?.vaultId ?? vaultId,
          })),
        });
      }

      case "item_delete": {
        const { vaultId, itemId } = args;
        requireString(vaultId, "vaultId");
        requireString(itemId, "itemId");

        await opFetch(
          `/vaults/${encodeURIComponent(vaultId)}/items/${encodeURIComponent(itemId)}`,
          { method: "DELETE" },
        );
        return toJsonResponse({ success: true });
      }

      case "password_create": {
        const {
          vaultId,
          title,
          password,
          username,
          category = "Login",
          tags,
          notes,
          url,
          returnSecret = false,
        } = args;

        requireString(vaultId, "vaultId");
        requireString(title, "title");
        requireString(password, "password");

        if (category !== "Login" && category !== "Password") {
          throw new McpError(
            ErrorCode.InvalidParams,
            "category must be either Login or Password",
          );
        }

        const created = await opFetch(
          `/vaults/${encodeURIComponent(vaultId)}/items`,
          {
            method: "POST",
            body: JSON.stringify({
              vault: { id: vaultId },
              title,
              category: category === "Password" ? "PASSWORD" : "LOGIN",
              fields: [
                ...(typeof username === "string" && username.length > 0
                  ? [
                      {
                        id: "username",
                        type: "STRING",
                        label: "username",
                        value: username,
                      },
                    ]
                  : []),
                {
                  id: "password",
                  type: "CONCEALED",
                  label: "password",
                  value: password,
                },
                ...(typeof notes === "string" && notes.length > 0
                  ? [
                      {
                        id: "notesPlain",
                        type: "STRING",
                        label: "notesPlain",
                        value: notes,
                        purpose: "NOTES",
                      },
                    ]
                  : []),
              ],
              urls:
                typeof url === "string" && url.length > 0
                  ? [{ primary: true, href: url }]
                  : [],
              tags: Array.isArray(tags) ? tags : [],
            }),
          },
        );

        return toJsonResponse(
          returnSecret ? created : redactItemSecrets(created, "password"),
        );
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
          const item = await opFetch(
            `/vaults/${encodeURIComponent(vaultId)}/items/${encodeURIComponent(itemId)}`,
          );
          if (!reveal) {
            return toJsonResponse(metadataOnlyItem(item));
          }
          if (typeof field === "string" && field.length > 0) {
            return toJsonResponse(item);
          }
          return toJsonResponse(item);
        }

        throw new McpError(
          ErrorCode.InvalidParams,
          "Provide either secretReference or both vaultId and itemId",
        );
      }

      case "password_update": {
        const {
          vaultId,
          itemId,
          newPassword,
          field = "password",
          returnSecret = false,
        } = args;

        requireString(vaultId, "vaultId");
        requireString(itemId, "itemId");
        requireString(newPassword, "newPassword");
        requireString(field, "field");

        const item = await opFetch(
          `/vaults/${encodeURIComponent(vaultId)}/items/${encodeURIComponent(itemId)}`,
        );
        const targetField = item.fields?.find(
          (candidate) => candidate.label === field || candidate.id === field,
        );
        if (!targetField) {
          throw new Error(`Field \"${field}\" not found`);
        }
        targetField.value = newPassword;

        const updated = await opFetch(
          `/vaults/${encodeURIComponent(vaultId)}/items/${encodeURIComponent(itemId)}`,
          {
            method: "PUT",
            body: JSON.stringify(item),
          },
        );

        return toJsonResponse(
          returnSecret ? updated : redactItemSecrets(updated, field),
        );
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
