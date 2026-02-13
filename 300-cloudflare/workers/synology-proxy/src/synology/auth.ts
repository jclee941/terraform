import { AuthenticationError, ExternalServiceError } from '../middleware/error-handler';
import { SynologyErrorCode, type SynologyAuthResponse, type SynologyResponse } from './types';

const SESSION_CACHE_MS = 50 * 60 * 1000;

export class SynologyAuth {
  private readonly baseUrl: string;
  private readonly username: string;
  private readonly password: string;
  private _sid: string | null;
  private _lastAuth: number;

  public constructor(baseUrl: string, username: string, password: string) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.username = username;
    this.password = password;
    this._sid = null;
    this._lastAuth = 0;
  }

  public async login(): Promise<string> {
    return this.performLogin(true);
  }

  public async getSid(): Promise<string> {
    const now = Date.now();
    if (this._sid !== null && now - this._lastAuth < SESSION_CACHE_MS) {
      return this._sid;
    }

    return this.login();
  }

  public async invalidateSession(): Promise<void> {
    this._sid = null;
    this._lastAuth = 0;
  }

  private async performLogin(allowRetry: boolean): Promise<string> {
    const params = {
      api: 'SYNO.API.Auth',
      version: '6',
      method: 'login',
      account: this.username,
      passwd: this.password,
      format: 'sid',
    };
    const url = this._buildUrl('auth.cgi', params);

    const response = await fetch(url, { method: 'GET' });
    if (!response.ok) {
      throw new ExternalServiceError(
        'Failed to reach Synology authentication endpoint',
        response.status
      );
    }

    const payload = (await response.json()) as SynologyResponse<SynologyAuthResponse>;

    if (!payload.success) {
      const errorCode = payload.error?.code;
      if (
        allowRetry &&
        (errorCode === SynologyErrorCode.INVALID_SID || errorCode === SynologyErrorCode.EXPIRED_SID)
      ) {
        await this.invalidateSession();
        return this.performLogin(false);
      }

      throw new AuthenticationError('Synology authentication failed', 'SYNOLOGY_AUTH_FAILED', {
        errorCode,
      });
    }

    const sid = payload.data?.sid;
    if (!sid) {
      throw new AuthenticationError('Synology authentication did not return SID');
    }

    this._sid = sid;
    this._lastAuth = Date.now();

    return sid;
  }

  private _buildUrl(cgiPath: string, params: Record<string, string>): string {
    const searchParams = new URLSearchParams(params);
    return `${this.baseUrl}/webapi/${cgiPath}?${searchParams.toString()}`;
  }
}
