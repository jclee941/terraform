import { describe, it, expect } from 'vitest';
import { createApp } from '../../app';

describe('Health Routes', () => {
  it('GET /health should return 200 OK', async () => {
    const app = createApp();
    const res = await app.request('/health');

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body).toHaveProperty('status', 'ok');
    expect(body).toHaveProperty('service', 'issue-form');
    expect(body).toHaveProperty('version');
    expect(body).toHaveProperty('timestamp');
  });
});
