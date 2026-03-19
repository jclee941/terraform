import type { Context } from 'hono';
import type { StatusCode } from 'hono/utils/http-status';
import type { HonoEnv } from '../env';

export interface ErrorResponse {
  success: false;
  error: {
    message: string;
    code?: string;
    statusCode: number;
    details?: unknown;
  };
  timestamp: string;
  requestId?: string;
}

export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code?: string;
  public readonly details?: unknown;

  public constructor(message: string, statusCode: number, code?: string, details?: unknown) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}

export class ValidationError extends AppError {
  public constructor(message: string, code = 'VALIDATION_ERROR', details?: unknown) {
    super(message, 400, code, details);
    this.name = 'ValidationError';
  }
}

export class NotFoundError extends AppError {
  public constructor(message: string, code = 'NOT_FOUND', details?: unknown) {
    super(message, 404, code, details);
    this.name = 'NotFoundError';
  }
}

export class ExternalServiceError extends AppError {
  public constructor(
    message: string,
    statusCode = 502,
    code = 'EXTERNAL_SERVICE_ERROR',
    details?: unknown
  ) {
    super(message, statusCode, code, details);
    this.name = 'ExternalServiceError';
  }
}

export class AuthenticationError extends AppError {
  public constructor(message: string, code = 'AUTHENTICATION_ERROR', details?: unknown) {
    super(message, 401, code, details);
    this.name = 'AuthenticationError';
  }
}

export const isAppError = (error: unknown): error is AppError => {
  return error instanceof AppError;
};

export const getErrorMessage = (error: unknown): string => {
  if (error instanceof Error) {
    return error.message;
  }

  if (typeof error === 'string') {
    return error;
  }

  return 'Unknown error';
};

const buildErrorResponse = (error: AppError, c: Context<HonoEnv>): ErrorResponse => {
  const requestId = c.req.header('cf-ray');

  return {
    success: false,
    error: {
      message: error.message,
      code: error.code,
      statusCode: error.statusCode,
      details: error.details,
    },
    timestamp: new Date().toISOString(),
    requestId,
  };
};

export const errorHandler = (error: unknown, c: Context<HonoEnv>): Response => {
  const appError = isAppError(error)
    ? error
    : new AppError(getErrorMessage(error), 500, 'INTERNAL_SERVER_ERROR');

  const requestId = c.req.header('cf-ray');
  console.warn(
    JSON.stringify({
      event: 'worker_error',
      requestId,
      method: c.req.method,
      path: new URL(c.req.url).pathname,
      statusCode: appError.statusCode,
      code: appError.code,
      message: appError.message,
    })
  );

  const response = buildErrorResponse(appError, c);
  return c.newResponse(JSON.stringify(response), appError.statusCode as StatusCode, {
    'content-type': 'application/json',
  });
};

export const notFoundHandler = (c: Context<HonoEnv>): Response => {
  const error = new NotFoundError('Route not found');
  const response = buildErrorResponse(error, c);
  return c.newResponse(JSON.stringify(response), 404, {
    'content-type': 'application/json',
  });
};
