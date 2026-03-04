import { AppError, AuthenticationError, ExternalServiceError, ValidationError } from '../middleware/error-handler';

export interface IssuePayload {
  title: string;
  body: string;
  labels?: string[];
}

export interface IssueResponse {
  number: number;
  html_url: string;
  title: string;
}

export class GitHubClient {
  constructor(
    private readonly token: string,
    private readonly owner: string,
    private readonly repo: string
  ) {}

  public async createIssue(payload: IssuePayload): Promise<IssueResponse> {
    const url = `https://api.github.com/repos/${this.owner}/${this.repo}/issues`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'cloudflare-worker-issue-form',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        title: payload.title,
        body: payload.body,
        labels: payload.labels || [],
      }),
    });

    if (!response.ok) {
      const remaining = response.headers.get('x-ratelimit-remaining');
      if (remaining === '0') {
        throw new ExternalServiceError('GitHub API Rate Limit Exceeded', 429);
      }

      if (response.status === 401 || response.status === 403) {
        throw new AuthenticationError('GitHub API authentication failed');
      }

      if (response.status === 422) {
        throw new ValidationError('Invalid issue payload for GitHub');
      }

      let errorMsg = `GitHub API error: ${response.statusText}`;
      try {
        const errBody = await response.json() as { message?: string };
        if (errBody.message) {
          errorMsg = `GitHub API error: ${errBody.message}`;
        }
      } catch (e) {
        // Ignore JSON parse error on error response
      }

      throw new ExternalServiceError(errorMsg, response.status);
    }

    const data = await response.json() as IssueResponse;
    return data;
  }

  public async searchIssues(
    title: string
  ): Promise<Array<{ number: number; html_url: string }>> {
    const q = encodeURIComponent(
      `repo:${this.owner}/${this.repo} is:issue is:open in:title "${title}"`
    );
    const url = `https://api.github.com/search/issues?q=${q}&per_page=5`;

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${this.token}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'cloudflare-worker-issue-form',
      },
    });

    if (!response.ok) {
      throw new ExternalServiceError(
        `GitHub search API error: ${response.statusText}`,
        response.status
      );
    }

    const data = (await response.json()) as {
      items: Array<{ number: number; html_url: string }>;
    };
    return data.items;
  }

  public async assignIssue(
    issueNumber: number,
    assignees: string[]
  ): Promise<void> {
    const url = `https://api.github.com/repos/${this.owner}/${this.repo}/issues/${issueNumber}`;

    const response = await fetch(url, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${this.token}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'cloudflare-worker-issue-form',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ assignees }),
    });

    if (!response.ok) {
      throw new ExternalServiceError(
        `GitHub assign API error: ${response.statusText}`,
        response.status
      );
    }
  }
}
