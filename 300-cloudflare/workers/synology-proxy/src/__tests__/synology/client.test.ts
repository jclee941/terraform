import { beforeEach, describe, expect, it, vi } from 'vitest';
import { NotFoundError } from '../../middleware/error-handler';
import { SynologyAuth } from '../../synology/auth';
import { SynologyClient } from '../../synology/client';

describe('SynologyClient', () => {
  let auth: SynologyAuth;
  let client: SynologyClient;

  beforeEach(() => {
    vi.restoreAllMocks();
    auth = new SynologyAuth('https://nas.example.com', 'user', 'pass');
    vi.spyOn(auth, 'getSid').mockResolvedValue('sid-123');
    vi.spyOn(auth, 'invalidateSession').mockResolvedValue();
    client = new SynologyClient(auth, 'https://nas.example.com');
  });

  it('lists files successfully', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: {
            files: [{ path: '/a.txt', name: 'a.txt', isdir: false }],
            total: 1,
            offset: 0,
          },
        }),
        { status: 200 }
      )
    );
    vi.stubGlobal('fetch', fetchMock);

    const result = await client.listFiles({ folderPath: '/' });
    expect(result.files).toHaveLength(1);
    expect(result.total).toBe(1);
  });

  it('downloads a file and returns binary response', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(
        new Response('file-content', { status: 200, headers: { 'content-type': 'text/plain' } })
      );
    vi.stubGlobal('fetch', fetchMock);

    const response = await client.downloadFile('/a.txt');
    const text = await response.text();
    expect(text).toBe('file-content');
  });

  it('creates folder successfully', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: {},
        }),
        { status: 200 }
      )
    );
    vi.stubGlobal('fetch', fetchMock);

    await expect(client.createFolder('/home', 'new-folder')).resolves.toBeUndefined();
  });

  it('deletes files successfully', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: {},
        }),
        { status: 200 }
      )
    );
    vi.stubGlobal('fetch', fetchMock);

    await expect(client.deleteFiles(['/a.txt', '/b.txt'])).resolves.toBeUndefined();
  });

  it('maps Synology invalid path error to NotFoundError', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          success: false,
          error: { code: 400 },
        }),
        { status: 200 }
      )
    );
    vi.stubGlobal('fetch', fetchMock);

    await expect(client.listFiles({ folderPath: '/missing' })).rejects.toBeInstanceOf(
      NotFoundError
    );
  });
});
