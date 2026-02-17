import { Hono } from 'hono';
import type { Env, HonoEnv } from '../env';
import { ExternalServiceError, ValidationError } from '../middleware/error-handler';
import { SynologyAuth } from '../synology/auth';
import { SynologyClient } from '../synology/client';
import type { ListFilesOptions } from '../synology/types';
import { R2Cache } from '../cache/r2';

interface FilesRouteDependencies {
  createAuth: (env: Env) => SynologyAuth;
  createClient: (auth: SynologyAuth, env: Env) => SynologyClient;
  createCache: (env: Env) => R2Cache;
}

type UploadFile = {
  name: string;
  stream: () => ReadableStream;
};

const defaultDependencies: FilesRouteDependencies = {
  createAuth: (env) =>
    new SynologyAuth(env.SYNOLOGY_API_URL, env.SYNOLOGY_USERNAME, env.SYNOLOGY_PASSWORD),
  createClient: (auth, env) => new SynologyClient(auth, env.SYNOLOGY_API_URL),
  createCache: (env) => new R2Cache(env.SYNOLOGY_CACHE),
};

const getContentType = (headers: Headers): string => {
  return headers.get('content-type') ?? 'application/octet-stream';
};

const getContentDisposition = (headers: Headers, path: string): string => {
  const headerValue = headers.get('content-disposition');
  if (headerValue) {
    return headerValue;
  }

  const fileName = path.split('/').pop() ?? 'download';
  return `attachment; filename="${fileName}"`;
};

const isUploadFile = (value: unknown): value is UploadFile => {
  if (value === null || typeof value === 'string') {
    return false;
  }

  const candidate = value as Partial<UploadFile>;
  return typeof candidate.name === 'string' && typeof candidate.stream === 'function';
};

export const createFilesRoutes = (overrides?: Partial<FilesRouteDependencies>): Hono<HonoEnv> => {
  const deps = { ...defaultDependencies, ...(overrides ?? {}) };
  const routes = new Hono<HonoEnv>();

  routes.get('/list', async (c) => {
    const path = c.req.query('path');
    if (!path) {
      throw new ValidationError('Query parameter "path" is required', 'MISSING_PATH');
    }

    const rawSortDirection = c.req.query('sort_direction');
    if (
      rawSortDirection !== undefined &&
      rawSortDirection !== 'asc' &&
      rawSortDirection !== 'desc'
    ) {
      throw new ValidationError(
        'Query parameter "sort_direction" must be "asc" or "desc"',
        'INVALID_SORT_DIRECTION'
      );
    }

    const listOptions: ListFilesOptions = {
      folderPath: path,
      offset: c.req.query('offset') ? Number(c.req.query('offset')) : undefined,
      limit: c.req.query('limit') ? Number(c.req.query('limit')) : undefined,
      sortBy: c.req.query('sort_by') ?? undefined,
      sortDirection: rawSortDirection,
      additional: c.req
        .query('additional')
        ?.split(',')
        .filter((value) => value.length > 0),
    };

    const auth = deps.createAuth(c.env);
    const client = deps.createClient(auth, c.env);
    const data = await client.listFiles(listOptions);

    return c.json({ success: true, data });
  });

  routes.get('/download', async (c) => {
    const path = c.req.query('path');
    if (!path) {
      throw new ValidationError('Query parameter "path" is required', 'MISSING_PATH');
    }

    const cache = deps.createCache(c.env);
    const cacheKey = cache.generateCacheKey(path);
    const cached = await cache.get(cacheKey);

    if (cached !== null) {
      const headers = new Headers();
      headers.set('Content-Type', cached.customMetadata?.contentType ?? 'application/octet-stream');
      if (cached.customMetadata?.contentDisposition) {
        headers.set('Content-Disposition', cached.customMetadata.contentDisposition);
      }
      headers.set('X-Cache', 'HIT');

      return new Response(cached.body, {
        status: 200,
        headers,
      });
    }

    const auth = deps.createAuth(c.env);
    const client = deps.createClient(auth, c.env);
    const response = await client.downloadFile(path);

    const contentType = getContentType(response.headers);
    const contentDisposition = getContentDisposition(response.headers, path);

    const cloned = response.clone();
    if (cloned.body === null || response.body === null) {
      throw new ExternalServiceError('Synology download response body is empty', 502);
    }

    await cache.put(cacheKey, cloned.body, {
      contentType,
      contentDisposition,
    });

    const headers = new Headers(response.headers);
    headers.set('Content-Type', contentType);
    headers.set('Content-Disposition', contentDisposition);
    headers.set('X-Cache', 'MISS');

    return new Response(response.body, {
      status: response.status,
      headers,
    });
  });

  routes.post('/upload', async (c) => {
    const formData = await c.req.formData();
    const destFolderPath = formData.get('dest_folder_path');
    const fileEntry = formData.get('file');

    if (typeof destFolderPath !== 'string' || destFolderPath.length === 0) {
      throw new ValidationError(
        'Form field "dest_folder_path" is required',
        'MISSING_DEST_FOLDER_PATH'
      );
    }

    if (!isUploadFile(fileEntry)) {
      throw new ValidationError('Form field "file" must be a file upload', 'MISSING_FILE');
    }

    const auth = deps.createAuth(c.env);
    const client = deps.createClient(auth, c.env);
    await client.uploadFile(destFolderPath, fileEntry.name, fileEntry.stream());

    const cache = deps.createCache(c.env);
    const uploadedCacheKey = cache.generateCacheKey(`${destFolderPath}/${fileEntry.name}`);
    await cache.delete(uploadedCacheKey);

    return c.json({
      success: true,
      data: { uploaded: true, fileName: fileEntry.name, destination: destFolderPath },
    });
  });

  routes.post('/folder', async (c) => {
    const body = await c.req.json<{ folderPath?: string; name?: string }>();
    if (!body.folderPath) {
      throw new ValidationError('Request body "folderPath" is required', 'MISSING_FOLDER_PATH');
    }

    if (!body.name) {
      throw new ValidationError('Request body "name" is required', 'MISSING_FOLDER_NAME');
    }

    const auth = deps.createAuth(c.env);
    const client = deps.createClient(auth, c.env);
    await client.createFolder(body.folderPath, body.name);

    return c.json({
      success: true,
      data: {
        created: true,
        folderPath: body.folderPath,
        name: body.name,
      },
    });
  });

  routes.delete('/', async (c) => {
    const path = c.req.query('path');
    if (!path) {
      throw new ValidationError('Query parameter "path" is required', 'MISSING_PATH');
    }

    const paths = path
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);

    if (paths.length === 0) {
      throw new ValidationError('At least one path must be provided', 'MISSING_PATH');
    }

    const auth = deps.createAuth(c.env);
    const client = deps.createClient(auth, c.env);
    await client.deleteFiles(paths);

    const cache = deps.createCache(c.env);
    await Promise.all(paths.map((p) => cache.delete(cache.generateCacheKey(p))));

    return c.json({
      success: true,
      data: { deleted: true, paths },
    });
  });

  routes.get('/info', async (c) => {
    const auth = deps.createAuth(c.env);
    const client = deps.createClient(auth, c.env);
    const data = await client.getInfo();

    return c.json({ success: true, data });
  });

  routes.post('/share', async (c) => {
    const body = await c.req.json<{ path?: string; expireDays?: number }>();
    if (!body.path) {
      throw new ValidationError('Request body "path" is required', 'MISSING_PATH');
    }

    const auth = deps.createAuth(c.env);
    const client = deps.createClient(auth, c.env);
    const data = await client.createShareLink(body.path, body.expireDays);

    return c.json({ success: true, data });
  });

  routes.post('/publish', async (c) => {
    const body = await c.req.json<{ path?: string; expireDays?: number }>();
    if (!body.path) {
      throw new ValidationError('Request body "path" is required', 'MISSING_PATH');
    }

    const auth = deps.createAuth(c.env);
    const client = deps.createClient(auth, c.env);
    const response = await client.downloadFile(body.path);

    if (response.body === null) {
      throw new ExternalServiceError('Synology download response body is empty', 502);
    }

    const contentType = response.headers.get('content-type') ?? 'application/octet-stream';
    const fileName = body.path.split('/').pop() ?? 'file';
    const shareKey = crypto.randomUUID().replace(/-/g, '').slice(0, 16);
    const ttlDays = body.expireDays ?? 7;
    const expiresAtMs = Date.now() + ttlDays * 24 * 60 * 60 * 1000;

    const cache = deps.createCache(c.env);
    await cache.put(`public/${shareKey}`, response.body, {
      contentType,
      contentDisposition: `inline; filename="${fileName}"`,
      fileName,
      expiresAt: String(expiresAtMs),
    });

    const baseUrl = new URL(c.req.url);
    const publicUrl = `${baseUrl.origin}/public/download/${shareKey}`;

    return c.json({
      success: true,
      data: {
        publicUrl,
        shareKey,
        fileName,
        expiresAt: new Date(expiresAtMs).toISOString(),
      },
    });
  });

  return routes;
};

export const filesRoutes = createFilesRoutes();
