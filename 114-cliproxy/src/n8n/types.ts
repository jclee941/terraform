/**
 * TypeScript type definitions for the n8n REST API.
 * Covers workflows, executions, nodes, connections, and webhook payloads.
 */

// ── Node Types ──────────────────────────────────────────────────────────

/** Parameter value — can be nested arbitrarily */
export type NodeParameterValue =
  | string
  | number
  | boolean
  | null
  | NodeParameterValue[]
  | { [key: string]: NodeParameterValue };

/** A single node in a workflow */
export interface WorkflowNode {
  /** Unique ID within the workflow (usually a UUID) */
  id: string;
  /** Human-readable name */
  name: string;
  /** Node type identifier (e.g. "n8n-nodes-base.httpRequest") */
  type: string;
  /** Type version */
  typeVersion: number;
  /** Canvas position [x, y] */
  position: [number, number];
  /** Node-specific parameters */
  parameters: Record<string, NodeParameterValue>;
  /** Credentials referenced by this node */
  credentials?: Record<string, { id: string; name: string }>;
  /** Whether the node is disabled */
  disabled?: boolean;
  /** Notes attached to the node */
  notes?: string;
  /** Whether to continue on fail */
  continueOnFail?: boolean;
  /** Whether to always output data */
  alwaysOutputData?: boolean;
  /** Retry settings */
  retryOnFail?: boolean;
  maxTries?: number;
  waitBetweenTries?: number;
}

// ── Connection Types ────────────────────────────────────────────────────

/** A single connection endpoint */
export interface ConnectionEndpoint {
  node: string;
  type: string;
  index: number;
}

/** Connection info between two nodes */
export interface ConnectionInfo {
  node: string;
  type: string;
  index: number;
}

/**
 * Workflow connections map.
 * Key = source node name
 * Value = map of output type → array of connection arrays
 */
export type WorkflowConnections = Record<
  string,
  Record<string, ConnectionInfo[][]>
>;

// ── Workflow Types ──────────────────────────────────────────────────────

/** Workflow settings */
export interface WorkflowSettings {
  saveDataErrorExecution?: "all" | "none";
  saveDataSuccessExecution?: "all" | "none";
  saveManualExecutions?: boolean;
  saveExecutionProgress?: boolean;
  executionTimeout?: number;
  timezone?: string;
  errorWorkflow?: string;
  callerPolicy?: "any" | "none" | "workflowsFromAList" | "workflowsFromSameOwner";
  callerIds?: string;
  [key: string]: NodeParameterValue | undefined;
}

/** Tag associated with a workflow */
export interface WorkflowTag {
  id: string;
  name: string;
  createdAt?: string;
  updatedAt?: string;
}

/** Full workflow object as returned by the n8n API */
export interface Workflow {
  id: string;
  name: string;
  active: boolean;
  nodes: WorkflowNode[];
  connections: WorkflowConnections;
  settings?: WorkflowSettings;
  staticData?: Record<string, unknown> | null;
  tags?: WorkflowTag[];
  createdAt: string;
  updatedAt: string;
  versionId?: string;
}

/** Payload for creating a new workflow (name, nodes, connections required) */
export interface WorkflowCreatePayload {
  name: string;
  nodes: WorkflowNode[];
  connections: WorkflowConnections;
  settings?: WorkflowSettings;
  staticData?: Record<string, unknown>;
  tags?: string[];
  active?: boolean;
}

/** Payload for updating an existing workflow (full replace via PUT) */
export interface WorkflowUpdatePayload {
  name: string;
  nodes: WorkflowNode[];
  connections: WorkflowConnections;
  settings?: WorkflowSettings;
  staticData?: Record<string, unknown>;
  tags?: string[];
  active?: boolean;
}

/** Paginated list response from n8n */
export interface PaginatedResponse<T> {
  data: T[];
  nextCursor?: string;
}

// ── Execution Types ─────────────────────────────────────────────────────

/** Execution status */
export type ExecutionStatus =
  | "canceled"
  | "crashed"
  | "error"
  | "new"
  | "running"
  | "success"
  | "unknown"
  | "waiting";

/** Execution data for a single node */
export interface ExecutionNodeData {
  startTime: number;
  executionTime: number;
  executionStatus?: string;
  source?: Array<{ previousNode: string }>;
  data?: {
    main?: Array<
      Array<{
        json: Record<string, unknown>;
        binary?: Record<string, unknown>;
      }>
    >;
  };
}

/** Full execution result data */
export interface ExecutionData {
  resultData: {
    runData: Record<string, ExecutionNodeData[]>;
    lastNodeExecuted?: string;
    error?: {
      message: string;
      stack?: string;
      node?: { name: string };
    };
  };
  startData?: {
    destinationNode?: string;
    runNodeFilter?: string[];
  };
  executionData?: {
    contextData: Record<string, unknown>;
    nodeExecutionStack: unknown[];
    metadata: Record<string, unknown>;
    waitingExecution: Record<string, unknown>;
    waitingExecutionSource: Record<string, unknown>;
  };
}

/** Execution summary (list endpoint) */
export interface Execution {
  id: number;
  finished: boolean;
  mode: string;
  startedAt: string;
  stoppedAt?: string;
  workflowId: string;
  workflowName?: string;
  status: ExecutionStatus;
  retryOf?: number | null;
  retrySuccessId?: number | null;
}

/** Full execution detail (get endpoint) */
export interface ExecutionDetail extends Execution {
  data?: ExecutionData;
}

// ── Webhook Types ───────────────────────────────────────────────────────

/** Webhook trigger response */
export interface WebhookResponse {
  [key: string]: unknown;
}

// ── API Error ───────────────────────────────────────────────────────────

/** Structured error from n8n API */
export interface N8nApiError {
  message: string;
  code?: number;
  httpStatusCode?: number;
  description?: string;
  hint?: string;
}

// ── Credential Types ────────────────────────────────────────────────────

/** Credential object as returned by the n8n API */
export interface Credential {
  id: string;
  name: string;
  type: string;
  createdAt: string;
  updatedAt: string;
  isManaged: boolean;
  isGlobal: boolean;
  isResolvable: boolean;
  resolvableAllowFallback: boolean;
  resolverId: string | null;
  scopes?: string[];
  data?: Record<string, string>;
  shared?: Array<{
    id: string;
    name: string;
    role: string;
    createdAt: string;
    updatedAt: string;
  }>;
}

/** Payload for creating a new credential */
export interface CredentialCreatePayload {
  name: string;
  type: string;
  data: Record<string, unknown>;
  projectId?: string;
  isGlobal?: boolean;
}

/** Payload for updating an existing credential */
export interface CredentialUpdatePayload {
  name?: string;
  data?: Record<string, unknown>;
  isGlobal?: boolean;
}

/** Query parameters for listing credentials */
export interface ListCredentialsParams {
  includeScopes?: boolean;
  includeData?: boolean;
  cursor?: string;
  limit?: number;
}

/** JSON Schema returned by the credential schema endpoint */
export interface CredentialSchema {
  type: string;
  properties: Record<string, { type: string }>;
  required?: string[];
  additionalProperties: boolean;
  allOf?: unknown[];
}

/** Result from testing a credential */
export interface TestCredentialResult {
  status: "success" | "error";
  message: string;
}

// ── List Query Parameters ───────────────────────────────────────────────

/** Query parameters for listing workflows */
export interface ListWorkflowsParams {
  active?: boolean;
  cursor?: string;
  limit?: number;
  tags?: string;
  name?: string;
}

/** Query parameters for listing executions */
export interface ListExecutionsParams {
  workflowId?: string;
  status?: ExecutionStatus;
  cursor?: string;
  limit?: number;
  includeData?: boolean;
}
