import { beforeEach, describe, expect, it, vi } from 'vitest';
import { R2Cache } from '../../cache/r2';

type StoredObject = {
  key: string;
  body: Uint8Array;
  customMetadata: Record<string, string>;
};

type BucketMock = {
  get: ReturnType<typeof vi.fn>;
  put: ReturnType<typeof vi.fn>;
  delete: ReturnType<typeof vi.fn>;
  list: ReturnType<typeof vi.fn>;
};

const toR2ObjectBody = (stored: StoredObject): R2ObjectBody => {
  const response = new Response(stored.body);

  const objectBody = {
    key: stored.key,
    version: 'v1',
    size: stored.body.byteLength,
    etag: 'etag',
    httpEtag: '"etag"',
    uploaded: new Date(),
    checksums: {},
    httpMetadata: {},
    customMetadata: stored.customMetadata,
    body: response.body,
    bodyUsed: false,
    arrayBuffer: () => response.arrayBuffer(),
    text: () => response.text(),
    json: () => response.json(),
    blob: () => response.blob(),
    writeHttpMetadata: () => {},
  };

  return objectBody as unknown as R2ObjectBody;
};

const createBucketMock = () => {
  const storage = new Map<string, StoredObject>();

  const bucketMock: BucketMock = {
    get: vi.fn(async (key: string) => {
      const stored = storage.get(key);
      return stored ? toR2ObjectBody(stored) : null;
    }),
    put: vi.fn(async (key: string, value: ReadableStream | ArrayBuffer, options?: R2PutOptions) => {
      const buffer =
        value instanceof ReadableStream ? await new Response(value).arrayBuffer() : value;
      storage.set(key, {
        key,
        body: new Uint8Array(buffer),
        customMetadata: options?.customMetadata ?? {},
      });
    }),
    delete: vi.fn(async (key: string) => {
      storage.delete(key);
    }),
    list: vi.fn(async ({ prefix }: { prefix?: string } = {}) => {
      const objects = Array.from(storage.values())
        .filter((item) => (prefix ? item.key.startsWith(prefix) : true))
        .map((item) => ({ key: item.key }));
      return {
        objects,
        truncated: false,
      };
    }),
  };

  return {
    bucket: bucketMock as unknown as R2Bucket,
    storage,
    mocks: bucketMock,
  };
};

describe('R2Cache', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('returns null on cache miss', async () => {
    const { bucket } = createBucketMock();
    const cache = new R2Cache(bucket);

    const result = await cache.get('missing');
    expect(result).toBeNull();
  });

  it('returns object on cache hit', async () => {
    const { bucket } = createBucketMock();
    const cache = new R2Cache(bucket);
    await cache.put('k1', new TextEncoder().encode('value'));

    const result = await cache.get('k1');
    expect(result).not.toBeNull();
    if (result !== null) {
      expect(await result.text()).toBe('value');
    }
  });

  it('deletes expired objects and returns null', async () => {
    const { bucket, storage, mocks } = createBucketMock();
    const cache = new R2Cache(bucket);
    storage.set('expired', {
      key: 'expired',
      body: new TextEncoder().encode('old-data'),
      customMetadata: { expiresAt: String(Date.now() - 1000) },
    });

    const result = await cache.get('expired');
    expect(result).toBeNull();
    expect(mocks.delete).toHaveBeenCalledWith('expired');
  });

  it('stores and deletes objects', async () => {
    const { bucket, storage } = createBucketMock();
    const cache = new R2Cache(bucket);

    await cache.put('key-1', new TextEncoder().encode('abc'), {
      contentType: 'text/plain',
    });
    expect(storage.has('key-1')).toBe(true);

    await cache.delete('key-1');
    expect(storage.has('key-1')).toBe(false);
  });

  it('invalidates all objects by prefix', async () => {
    const { bucket, storage } = createBucketMock();
    const cache = new R2Cache(bucket);

    storage.set('downloads/a', {
      key: 'downloads/a',
      body: new TextEncoder().encode('1'),
      customMetadata: {},
    });
    storage.set('downloads/b', {
      key: 'downloads/b',
      body: new TextEncoder().encode('2'),
      customMetadata: {},
    });
    storage.set('other/c', {
      key: 'other/c',
      body: new TextEncoder().encode('3'),
      customMetadata: {},
    });

    await cache.invalidateByPrefix('downloads/');

    expect(storage.has('downloads/a')).toBe(false);
    expect(storage.has('downloads/b')).toBe(false);
    expect(storage.has('other/c')).toBe(true);
  });

  it('generates stable hash-based cache keys', () => {
    const { bucket } = createBucketMock();
    const cache = new R2Cache(bucket);

    const keyA = cache.generateCacheKey('/folder/a.txt');
    const keyB = cache.generateCacheKey('/folder/a.txt');
    const keyC = cache.generateCacheKey('/folder/b.txt');

    expect(keyA).toBe(keyB);
    expect(keyA).not.toBe(keyC);
    expect(keyA.startsWith('downloads/')).toBe(true);
  });
});
