import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthenticationError } from '../../middleware/error-handler';
import { SynologyAuth } from '../../synology/auth';

describe('SynologyAuth', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('logs in successfully and returns SID', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: { sid: 'sid-123' },
        }),
        { status: 200 }
      )
    );
    vi.stubGlobal('fetch', fetchMock);

    const auth = new SynologyAuth('https://nas.example.com', 'user', 'pass');
    const sid = await auth.login();

    expect(sid).toBe('sid-123');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('throws AuthenticationError when login fails', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          success: false,
          error: { code: 101 },
        }),
        { status: 200 }
      )
    );
    vi.stubGlobal('fetch', fetchMock);

    const auth = new SynologyAuth('https://nas.example.com', 'user', 'pass');
    await expect(auth.login()).rejects.toBeInstanceOf(AuthenticationError);
  });

  it('reuses cached SID before expiry', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          success: true,
          data: { sid: 'sid-123' },
        }),
        { status: 200 }
      )
    );
    vi.stubGlobal('fetch', fetchMock);

    const auth = new SynologyAuth('https://nas.example.com', 'user', 'pass');
    const sid1 = await auth.getSid();
    const sid2 = await auth.getSid();

    expect(sid1).toBe('sid-123');
    expect(sid2).toBe('sid-123');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('refreshes SID after cache expiration', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: { sid: 'sid-old' },
          }),
          { status: 200 }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: { sid: 'sid-new' },
          }),
          { status: 200 }
        )
      );
    vi.stubGlobal('fetch', fetchMock);

    const nowSpy = vi.spyOn(Date, 'now');
    nowSpy.mockReturnValueOnce(0);
    nowSpy.mockReturnValueOnce(0);
    nowSpy.mockReturnValueOnce(51 * 60 * 1000);
    nowSpy.mockReturnValueOnce(51 * 60 * 1000);

    const auth = new SynologyAuth('https://nas.example.com', 'user', 'pass');
    const sid1 = await auth.getSid();
    const sid2 = await auth.getSid();

    expect(sid1).toBe('sid-old');
    expect(sid2).toBe('sid-new');
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('retries once on invalid SID error code', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: false,
            error: { code: 117 },
          }),
          { status: 200 }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: { sid: 'sid-retry' },
          }),
          { status: 200 }
        )
      );
    vi.stubGlobal('fetch', fetchMock);

    const auth = new SynologyAuth('https://nas.example.com', 'user', 'pass');
    const sid = await auth.login();

    expect(sid).toBe('sid-retry');
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });
});
