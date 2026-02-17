import { Hono } from 'hono'
import type { HonoEnv } from '../env'
import { NotFoundError } from '../middleware/error-handler'
import { R2Cache } from '../cache/r2'

export const publicRoutes = new Hono<HonoEnv>()

publicRoutes.get('/download/:key', async (c) => {
  const key = c.req.param('key')
  const cache = new R2Cache(c.env.SYNOLOGY_CACHE)
  const cacheKey = `public/${key}`

  const cached = await cache.get(cacheKey)
  if (cached === null) {
    throw new NotFoundError('File not found or share link has expired', 'PUBLIC_FILE_NOT_FOUND')
  }

  const contentType = cached.customMetadata?.contentType ?? 'application/octet-stream'
  const fileName = cached.customMetadata?.fileName ?? key

  return new Response(cached.body, {
    status: 200,
    headers: {
      'Content-Type': contentType,
      'Content-Disposition': `inline; filename="${fileName}"`,
      'Cache-Control': 'public, max-age=3600',
      'X-Source': 'r2-public',
    },
  })
})
