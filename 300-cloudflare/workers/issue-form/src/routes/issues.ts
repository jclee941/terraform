import { Hono } from 'hono';
import type { HonoEnv } from '../env';
import { GitHubClient } from '../github/client';
import { ValidationError } from '../middleware/error-handler';

export const issueRoutes = new Hono<HonoEnv>();

issueRoutes.post('/issues', async (c) => {
  const body = await c.req.json().catch(() => null);

  if (!body) {
    throw new ValidationError('잘못된 요청 양식입니다. (Invalid JSON body)');
  }

  const { title, type, priority, description, labels } = body;

  if (!title || typeof title !== 'string' || title.trim().length === 0) {
    throw new ValidationError('제목(title)은 필수입니다.');
  }

  if (title.length > 256) {
    throw new ValidationError('제목은 256자를 초과할 수 없습니다.');
  }

  if (!description || typeof description !== 'string' || description.trim().length === 0) {
    throw new ValidationError('설명(description)은 필수입니다.');
  }

  if (description.length > 65536) {
    throw new ValidationError('설명이 너무 깁니다.');
  }

  const githubLabels: string[] = [];

  if (type) {
    const typeMap: Record<string, string> = {
      '🐛 버그': 'bug',
      '✨ 기능 요청': 'enhancement',
      '🔧 유지보수': 'maintenance',
      '📝 문서': 'documentation',
    };
    if (typeMap[type]) {
      githubLabels.push(typeMap[type]);
    }
  }

  if (priority) {
    const priorityMap: Record<string, string> = {
      '🔴 긴급': 'priority: critical',
      '🟠 높음': 'priority: high',
      '🟡 보통': 'priority: medium',
      '🟢 낮음': 'priority: low',
    };
    if (priorityMap[priority]) {
      githubLabels.push(priorityMap[priority]);
    }
  }

  if (labels && typeof labels === 'string' && labels.trim().length > 0) {
    const customLabels = labels.split(',').map((l) => l.trim()).filter(Boolean);
    githubLabels.push(...customLabels);
  }

  const issueBody = `### 설명\n\n${description}\n\n---\n*유형:* ${type || '미지정'} | *우선순위:* ${priority || '미지정'}`;

  const client = new GitHubClient(c.env.GITHUB_TOKEN, c.env.GITHUB_OWNER, c.env.GITHUB_REPO);

  const issue = await client.createIssue({
    title: title.trim(),
    body: issueBody,
    labels: githubLabels,
  });

  return c.json(
    {
      success: true,
      issue: {
        number: issue.number,
        html_url: issue.html_url,
        title: issue.title,
      },
    },
    201
  );
});
