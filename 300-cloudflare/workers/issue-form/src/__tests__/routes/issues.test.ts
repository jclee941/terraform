import { describe, it, expect, vi } from 'vitest';
import { createApp } from '../../app';

// Mock the global fetch used by GitHubClient
global.fetch = vi.fn();

describe('Issues Routes', () => {
  const env = {
    GITHUB_TOKEN: 'fake-token',
    GITHUB_OWNER: 'owner',
    GITHUB_REPO: 'repo',
    ENVIRONMENT: 'test',
  };

  it('POST /api/issues should fail if body is empty', async () => {
    const app = createApp();
    const res = await app.request('/api/issues', {
      method: 'POST',
    }, env);

    expect(res.status).toBe(400);
    const body = await res.json() as { error: { message: string } };
    expect(body.error.message).toContain('Invalid JSON body');
  });

  it('POST /api/issues should fail if title is missing', async () => {
    const app = createApp();
    const res = await app.request('/api/issues', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        description: 'Valid description'
      })
    }, env);

    expect(res.status).toBe(400);
    const body = await res.json() as { error: { message: string } };
    expect(body.error.message).toContain('제목(title)은 필수입니다.');
  });

  it('POST /api/issues should succeed with valid payload', async () => {
    // Mock fetch response for GitHub API
    vi.mocked(global.fetch).mockResolvedValueOnce(new Response(
      JSON.stringify({
        number: 123,
        html_url: 'https://github.com/owner/repo/issues/123',
        title: 'Valid Title'
      }),
      { status: 201, headers: { 'Content-Type': 'application/json' } }
    ));

    const app = createApp();
    const res = await app.request('/api/issues', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: 'Valid Title',
        description: 'Valid Description',
        type: '🐛 버그',
        priority: '🔴 긴급',
        labels: 'custom1, custom2'
      })
    }, env);

    expect(res.status).toBe(201);
    const body = await res.json() as { success: boolean; issue: { number: number; html_url: string; title: string } };
    expect(body.success).toBe(true);
    expect(body.issue.number).toBe(123);

    // Verify GitHub API was called with mapped labels
    const fetchCalls = vi.mocked(global.fetch).mock.calls;
    expect(fetchCalls.length).toBe(1);
    const reqBody = JSON.parse(fetchCalls[0][1]!.body as string);
    expect(reqBody.labels).toContain('bug');
    expect(reqBody.labels).toContain('priority: critical');
    expect(reqBody.labels).toContain('custom1');
    expect(reqBody.labels).toContain('custom2');
  });
});
