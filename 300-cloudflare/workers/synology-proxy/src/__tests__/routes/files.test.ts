import { Hono } from 'hono';
import { describe, expect, it, vi } from 'vitest';
import type { Env, HonoEnv } from '../../env';
import { errorHandler } from '../../middleware/error-handler';
import { createFilesRoutes } from '../../routes/files';

type MockClient = {
  listFiles: ReturnType<typeof vi.fn>;
  downloadFile: ReturnType<typeof vi.fn>;
  uploadFile: ReturnType<typeof vi.fn>;
  createFolder: ReturnType<typeof vi.fn>;
  deleteFiles: ReturnType<typeof vi.fn>;
  getInfo: ReturnType<typeof vi.fn>;
  createShareLink: ReturnType<typeof vi.fn>;
};

type MockCache = {
  get: ReturnType<typeof vi.fn>;
  put: ReturnType<typeof vi.fn>;
  delete: ReturnType<typeof vi.fn>;
  invalidateByPrefix: ReturnType<typeof vi.fn>;
  generateCacheKey: ReturnType<typeof vi.fn>;
};

const createBucketMock = (): R2Bucket => {
  const bucket = {
    get: async () => null,
    put: async () => {},
    delete: async () => {},
    list: async () => ({ objects: [], truncated: false }),
  };
  return bucket as unknown as R2Bucket;
};

const createEnv = (): Env => {
  return {
    SYNOLOGY_CACHE: createBucketMock(),
    SYNOLOGY_API_URL: 'https://nas.example.com',
    SYNOLOGY_USERNAME: 'user',
    SYNOLOGY_PASSWORD: 'pass',
    ENVIRONMENT: 'test',
  };
};

const createAppWithMocks = (client: MockClient, cache: MockCache) => {
  const app = new Hono<HonoEnv>();
  app.onError(errorHandler);
  app.route(
    '/api/files',
    createFilesRoutes({
      createAuth: () => ({}) as never,
      createClient: () => client as never,
      createCache: () => cache as never,
    })
  );
  return app;
};

describe('files routes', () => {
  it('returns validation error for missing path in list endpoint', async () => {
    const client: MockClient = {
      listFiles: vi.fn(),
      downloadFile: vi.fn(),
      uploadFile: vi.fn(),
      createFolder: vi.fn(),
      deleteFiles: vi.fn(),
      getInfo: vi.fn(),
      createShareLink: vi.fn(),
    };
    const cache: MockCache = {
      get: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
      invalidateByPrefix: vi.fn(),
      generateCacheKey: vi.fn().mockReturnValue('downloads/key'),
    };

    const app = createAppWithMocks(client, cache);
    const response = await app.request('/api/files/list', { method: 'GET' }, createEnv());
    const body = (await response.json()) as {
      success: boolean;
      error: { code?: string };
    };

    expect(response.status).toBe(400);
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('MISSING_PATH');
  });

  it('handles list files request successfully', async () => {
    const client: MockClient = {
      listFiles: vi.fn().mockResolvedValue({ files: [], total: 0, offset: 0 }),
      downloadFile: vi.fn(),
      uploadFile: vi.fn(),
      createFolder: vi.fn(),
      deleteFiles: vi.fn(),
      getInfo: vi.fn(),
      createShareLink: vi.fn(),
    };
    const cache: MockCache = {
      get: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
      invalidateByPrefix: vi.fn(),
      generateCacheKey: vi.fn().mockReturnValue('downloads/key'),
    };

    const app = createAppWithMocks(client, cache);
    const response = await app.request('/api/files/list?path=%2F', { method: 'GET' }, createEnv());
    const body = (await response.json()) as {
      success: boolean;
      data: { total: number };
    };

    expect(response.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.total).toBe(0);
  });

  it('returns cached download when available', async () => {
    const cachedResponse = new Response('cached-data');
    const cachedObject = {
      body: cachedResponse.body,
      customMetadata: {
        contentType: 'text/plain',
        contentDisposition: 'attachment; filename="a.txt"',
      },
    };

    const client: MockClient = {
      listFiles: vi.fn(),
      downloadFile: vi.fn(),
      uploadFile: vi.fn(),
      createFolder: vi.fn(),
      deleteFiles: vi.fn(),
      getInfo: vi.fn(),
      createShareLink: vi.fn(),
    };
    const cache: MockCache = {
      get: vi.fn().mockResolvedValue(cachedObject),
      put: vi.fn(),
      delete: vi.fn(),
      invalidateByPrefix: vi.fn(),
      generateCacheKey: vi.fn().mockReturnValue('downloads/key'),
    };

    const app = createAppWithMocks(client, cache);
    const response = await app.request(
      '/api/files/download?path=%2Fa.txt',
      { method: 'GET' },
      createEnv()
    );

    expect(response.status).toBe(200);
    expect(response.headers.get('x-cache')).toBe('HIT');
    expect(await response.text()).toBe('cached-data');
    expect(client.downloadFile).not.toHaveBeenCalled();
  });

  it('downloads from Synology and stores in cache on miss', async () => {
    const client: MockClient = {
      listFiles: vi.fn(),
      downloadFile: vi.fn().mockResolvedValue(
        new Response('origin-data', {
          status: 200,
          headers: {
            'content-type': 'application/octet-stream',
            'content-disposition': 'attachment; filename="origin.bin"',
          },
        })
      ),
      uploadFile: vi.fn(),
      createFolder: vi.fn(),
      deleteFiles: vi.fn(),
      getInfo: vi.fn(),
      createShareLink: vi.fn(),
    };
    const cache: MockCache = {
      get: vi.fn().mockResolvedValue(null),
      put: vi.fn().mockResolvedValue(undefined),
      delete: vi.fn(),
      invalidateByPrefix: vi.fn(),
      generateCacheKey: vi.fn().mockReturnValue('downloads/key'),
    };

    const app = createAppWithMocks(client, cache);
    const response = await app.request(
      '/api/files/download?path=%2Fa.bin',
      { method: 'GET' },
      createEnv()
    );

    expect(response.status).toBe(200);
    expect(response.headers.get('x-cache')).toBe('MISS');
    expect(await response.text()).toBe('origin-data');
    expect(cache.put).toHaveBeenCalledTimes(1);
  });

  it('uploads file successfully', async () => {
    const client: MockClient = {
      listFiles: vi.fn(),
      downloadFile: vi.fn(),
      uploadFile: vi.fn().mockResolvedValue(undefined),
      createFolder: vi.fn(),
      deleteFiles: vi.fn(),
      getInfo: vi.fn(),
      createShareLink: vi.fn(),
    };
    const cache: MockCache = {
      get: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
      invalidateByPrefix: vi.fn().mockResolvedValue(undefined),
      generateCacheKey: vi.fn().mockReturnValue('downloads/key'),
    };

    const app = createAppWithMocks(client, cache);
    const formData = new FormData();
    formData.set('dest_folder_path', '/uploads');
    formData.set('file', new File(['hello'], 'hello.txt', { type: 'text/plain' }));

    const response = await app.request(
      '/api/files/upload',
      { method: 'POST', body: formData },
      createEnv()
    );
    const body = (await response.json()) as {
      success: boolean;
      data: { uploaded: boolean };
    };

    expect(response.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.uploaded).toBe(true);
    expect(client.uploadFile).toHaveBeenCalledTimes(1);
  });

  it('creates folder successfully', async () => {
    const client: MockClient = {
      listFiles: vi.fn(),
      downloadFile: vi.fn(),
      uploadFile: vi.fn(),
      createFolder: vi.fn().mockResolvedValue(undefined),
      deleteFiles: vi.fn(),
      getInfo: vi.fn(),
      createShareLink: vi.fn(),
    };
    const cache: MockCache = {
      get: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
      invalidateByPrefix: vi.fn(),
      generateCacheKey: vi.fn().mockReturnValue('downloads/key'),
    };

    const app = createAppWithMocks(client, cache);
    const response = await app.request(
      '/api/files/folder',
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ folderPath: '/home', name: 'new-folder' }),
      },
      createEnv()
    );

    expect(response.status).toBe(200);
    expect(client.createFolder).toHaveBeenCalledWith('/home', 'new-folder');
  });

  it('deletes files successfully', async () => {
    const client: MockClient = {
      listFiles: vi.fn(),
      downloadFile: vi.fn(),
      uploadFile: vi.fn(),
      createFolder: vi.fn(),
      deleteFiles: vi.fn().mockResolvedValue(undefined),
      getInfo: vi.fn(),
      createShareLink: vi.fn(),
    };
    const cache: MockCache = {
      get: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
      invalidateByPrefix: vi.fn().mockResolvedValue(undefined),
      generateCacheKey: vi.fn().mockReturnValue('downloads/key'),
    };

    const app = createAppWithMocks(client, cache);
    const response = await app.request(
      '/api/files?path=%2Fa.txt,%2Fb.txt',
      { method: 'DELETE' },
      createEnv()
    );

    expect(response.status).toBe(200);
    expect(client.deleteFiles).toHaveBeenCalledWith(['/a.txt', '/b.txt']);
  });

  it('returns FileStation info', async () => {
    const client: MockClient = {
      listFiles: vi.fn(),
      downloadFile: vi.fn(),
      uploadFile: vi.fn(),
      createFolder: vi.fn(),
      deleteFiles: vi.fn(),
      getInfo: vi.fn().mockResolvedValue({ version: '1.0' }),
      createShareLink: vi.fn(),
    };
    const cache: MockCache = {
      get: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
      invalidateByPrefix: vi.fn(),
      generateCacheKey: vi.fn().mockReturnValue('downloads/key'),
    };

    const app = createAppWithMocks(client, cache);
    const response = await app.request('/api/files/info', { method: 'GET' }, createEnv());
    const body = (await response.json()) as {
      success: boolean;
      data: { version: string };
    };

    expect(response.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.version).toBe('1.0');
  });

  it('creates share link successfully', async () => {
    const client: MockClient = {
      listFiles: vi.fn(),
      downloadFile: vi.fn(),
      uploadFile: vi.fn(),
      createFolder: vi.fn(),
      deleteFiles: vi.fn(),
      getInfo: vi.fn(),
      createShareLink: vi.fn().mockResolvedValue({
        id: 'share-1',
        url: 'https://nas.example.com/s/share-1',
        path: '/a.txt',
        date_expired: '2030-01-01',
      }),
    };
    const cache: MockCache = {
      get: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
      invalidateByPrefix: vi.fn(),
      generateCacheKey: vi.fn().mockReturnValue('downloads/key'),
    };

    const app = createAppWithMocks(client, cache);
    const response = await app.request(
      '/api/files/share',
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ path: '/a.txt', expireDays: 7 }),
      },
      createEnv()
    );

    const body = (await response.json()) as {
      success: boolean;
      data: { id: string };
    };

    expect(response.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.id).toBe('share-1');
  });
});
