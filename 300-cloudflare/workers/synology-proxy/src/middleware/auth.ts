import type { Context, Next } from 'hono'
import type { HonoEnv } from '../env'
import { AuthenticationError } from './error-handler'

/**
 * Bearer token auth middleware for programmatic API access.
 * Validates `Authorization: Bearer <API_KEY>` header against
 * the API_KEY secret binding.
 *
 * CF Access (email-based) protects browser access at the edge;
 * this middleware adds a second layer for machine-to-machine calls.
 */
export const bearerAuth = async (c: Context<HonoEnv>, next: Next): Promise<void> => {
  const apiKey = c.env.API_KEY
  if (!apiKey) {
    // No API_KEY configured — skip auth (CF Access still protects)
    await next()
    return
  }

  const authHeader = c.req.header('Authorization')
  if (!authHeader) {
    throw new AuthenticationError('Missing Authorization header', 'MISSING_AUTH_HEADER')
  }

  const [scheme, token] = authHeader.split(' ')
  if (scheme !== 'Bearer' || !token) {
    throw new AuthenticationError(
      'Invalid Authorization header format. Expected: Bearer <token>',
      'INVALID_AUTH_FORMAT'
    )
  }

  if (token !== apiKey) {
    throw new AuthenticationError('Invalid API key', 'INVALID_API_KEY')
  }

  await next()
}
