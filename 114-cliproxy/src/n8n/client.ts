/**
 * Typed HTTP client for the n8n REST API.
 * Uses Bun-native fetch. All methods throw on non-OK responses.
 */

import { n8n as config } from "../config.js";
import type {
  Credential,
  CredentialCreatePayload,
  CredentialSchema,
  CredentialUpdatePayload,
  Execution,
  ExecutionDetail,
  ListCredentialsParams,
  ListExecutionsParams,
  ListWorkflowsParams,
  PaginatedResponse,
  TestCredentialResult,
  WebhookResponse,
  Workflow,
  WorkflowCreatePayload,
  WorkflowUpdatePayload,
} from "./types.js";

class N8nClientError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly body: unknown,
  ) {
    super(message);
    this.name = "N8nClientError";
  }
}

function headers(): Record<string, string> {
  const h: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json",
  };
  if (config.apiKey) {
    h["X-N8N-API-KEY"] = config.apiKey;
  }
  return h;
}

function url(path: string, params?: Record<string, string | undefined>): string {
  const base = `${config.baseUrl}${path}`;
  if (!params) return base;

  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined) qs.set(k, v);
  }
  const str = qs.toString();
  return str ? `${base}?${str}` : base;
}

async function request<T>(input: string, init?: RequestInit): Promise<T> {
  const res = await fetch(input, {
    ...init,
    headers: { ...headers(), ...init?.headers },
  });
  if (!res.ok) {
    let body: unknown;
    try {
      body = await res.json();
    } catch {
      body = await res.text();
    }
    throw new N8nClientError(
      `n8n API ${res.status}: ${init?.method ?? "GET"} ${input}`,
      res.status,
      body,
    );
  }
  const text = await res.text();
  if (!text) return undefined as T;
  return JSON.parse(text) as T;
}

export async function listWorkflows(
  params?: ListWorkflowsParams,
): Promise<PaginatedResponse<Workflow>> {
  return request<PaginatedResponse<Workflow>>(
    url("/api/v1/workflows", {
      active: params?.active?.toString(),
      cursor: params?.cursor,
      limit: params?.limit?.toString(),
      tags: params?.tags,
      name: params?.name,
    }),
  );
}

export async function getWorkflow(id: string): Promise<Workflow> {
  return request<Workflow>(url(`/api/v1/workflows/${id}`));
}

export async function createWorkflow(
  payload: WorkflowCreatePayload,
): Promise<Workflow> {
  return request<Workflow>(url("/api/v1/workflows"), {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function updateWorkflow(
  id: string,
  payload: WorkflowUpdatePayload,
): Promise<Workflow> {
  return request<Workflow>(url(`/api/v1/workflows/${id}`), {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export async function deleteWorkflow(id: string): Promise<void> {
  await request<void>(url(`/api/v1/workflows/${id}`), {
    method: "DELETE",
  });
}

export async function activateWorkflow(id: string): Promise<Workflow> {
  return request<Workflow>(url(`/api/v1/workflows/${id}/activate`), {
    method: "POST",
  });
}

export async function deactivateWorkflow(id: string): Promise<Workflow> {
  return request<Workflow>(url(`/api/v1/workflows/${id}/deactivate`), {
    method: "POST",
  });
}

export async function listExecutions(
  params?: ListExecutionsParams,
): Promise<PaginatedResponse<Execution>> {
  return request<PaginatedResponse<Execution>>(
    url("/api/v1/executions", {
      workflowId: params?.workflowId,
      status: params?.status,
      cursor: params?.cursor,
      limit: params?.limit?.toString(),
      includeData: params?.includeData?.toString(),
    }),
  );
}

export async function getExecution(id: string): Promise<ExecutionDetail> {
  return request<ExecutionDetail>(url(`/api/v1/executions/${id}`));
}

export async function deleteExecution(id: string): Promise<void> {
  await request<void>(url(`/api/v1/executions/${id}`), {
    method: "DELETE",
  });
}

export async function runWebhook(
  path: string,
  data?: Record<string, unknown>,
  extraHeaders?: Record<string, string>,
): Promise<WebhookResponse> {
  return request<WebhookResponse>(url(`/webhook/${path}`), {
    method: "POST",
    body: data ? JSON.stringify(data) : undefined,
    headers: extraHeaders,
  });
}

export async function listCredentials(
  params?: ListCredentialsParams,
): Promise<PaginatedResponse<Credential>> {
  return request<PaginatedResponse<Credential>>(
    url("/api/v1/credentials", {
      includeScopes: params?.includeScopes?.toString(),
      includeData: params?.includeData?.toString(),
      cursor: params?.cursor,
      limit: params?.limit?.toString(),
    }),
  );
}

export async function createCredential(
  payload: CredentialCreatePayload,
): Promise<Credential> {
  return request<Credential>(url("/api/v1/credentials"), {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function updateCredential(
  id: string,
  payload: CredentialUpdatePayload,
): Promise<Credential> {
  return request<Credential>(url(`/api/v1/credentials/${id}`), {
    method: "PATCH",
    body: JSON.stringify(payload),
  });
}

export async function deleteCredential(id: string): Promise<void> {
  await request<void>(url(`/api/v1/credentials/${id}`), {
    method: "DELETE",
  });
}

export async function getCredentialSchema(
  typeName: string,
): Promise<CredentialSchema> {
  return request<CredentialSchema>(
    url(`/api/v1/credentials/schema/${typeName}`),
  );
}

export async function testCredential(
  credentialId: string,
  credentialType: string,
): Promise<TestCredentialResult> {
  return request<TestCredentialResult>(url("/api/v1/credentials/test"), {
    method: "POST",
    body: JSON.stringify({
      credentials: { id: credentialId, type: credentialType },
    }),
  });
}
