import {
  AuthenticationError,
  ExternalServiceError,
  NotFoundError,
  ValidationError,
} from '../middleware/error-handler';
import { SynologyAuth } from './auth';
import {
  SynologyErrorCode,
  type ListFilesOptions,
  type SynologyFileList,
  type SynologyFileStationInfo,
  type SynologyResponse,
  type SynologyShareLink,
} from './types';

interface SynologyCreateShareLinkResponse {
  links?: SynologyShareLink[];
}

export class SynologyClient {
  private readonly auth: SynologyAuth;
  private readonly apiUrl: string;

  public constructor(auth: SynologyAuth, apiUrl: string) {
    this.auth = auth;
    this.apiUrl = apiUrl.replace(/\/$/, '');
  }

  public async listFiles(options: ListFilesOptions): Promise<SynologyFileList> {
    const params: Record<string, string> = {
      api: 'SYNO.FileStation.List',
      version: '2',
      method: 'list',
      folder_path: options.folderPath,
      offset: String(options.offset ?? 0),
      limit: String(options.limit ?? 100),
      sort_by: options.sortBy ?? 'name',
      sort_direction: options.sortDirection ?? 'asc',
    };

    if (options.additional && options.additional.length > 0) {
      params.additional = options.additional.join(',');
    }

    return this._request<SynologyFileList>('entry.cgi', params);
  }

  public async downloadFile(path: string, retry = true): Promise<Response> {
    const sid = await this.auth.getSid();
    const params: Record<string, string> = {
      api: 'SYNO.FileStation.Download',
      version: '2',
      method: 'download',
      path,
      mode: 'download',
      _sid: sid,
    };

    const url = this.buildUrl('entry.cgi', params);
    const response = await fetch(url, { method: 'GET' });

    if (!response.ok) {
      throw new ExternalServiceError('Failed to download file from Synology', response.status);
    }

    const contentType = response.headers.get('content-type') ?? '';
    if (contentType.includes('application/json')) {
      const payload = (await response.json()) as SynologyResponse<Record<string, never>>;
      if (!payload.success) {
        const code = payload.error?.code;
        if (
          retry &&
          (code === SynologyErrorCode.INVALID_SID || code === SynologyErrorCode.EXPIRED_SID)
        ) {
          await this.auth.invalidateSession();
          return this.downloadFile(path, false);
        }

        this.throwMappedError(code);
      }
    }

    return response;
  }

  public async uploadFile(
    destFolder: string,
    fileName: string,
    file: ReadableStream | ArrayBuffer
  ): Promise<void> {
    const sid = await this.auth.getSid();
    const formData = new FormData();
    formData.set('api', 'SYNO.FileStation.Upload');
    formData.set('version', '2');
    formData.set('method', 'upload');
    formData.set('dest_folder_path', destFolder);
    formData.set('overwrite', 'true');
    formData.set('_sid', sid);

    const fileBody = file instanceof ReadableStream ? await this.streamToArrayBuffer(file) : file;
    formData.set('file', new Blob([fileBody]), fileName);

    const response = await fetch(`${this.apiUrl}/webapi/entry.cgi`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      throw new ExternalServiceError('Failed to upload file to Synology', response.status);
    }

    const payload = (await response.json()) as SynologyResponse<Record<string, never>>;
    if (!payload.success) {
      this.throwMappedError(payload.error?.code);
    }
  }

  public async createFolder(folderPath: string, name: string): Promise<void> {
    await this._request<Record<string, never>>('entry.cgi', {
      api: 'SYNO.FileStation.CreateFolder',
      version: '2',
      method: 'create',
      folder_path: folderPath,
      name,
    });
  }

  public async deleteFiles(paths: string[]): Promise<void> {
    await this._request<Record<string, never>>('entry.cgi', {
      api: 'SYNO.FileStation.Delete',
      version: '2',
      method: 'delete',
      path: paths.join(','),
    });
  }

  public async getInfo(): Promise<SynologyFileStationInfo> {
    return this._request<SynologyFileStationInfo>('entry.cgi', {
      api: 'SYNO.FileStation.Info',
      version: '2',
      method: 'get',
    });
  }

  public async createShareLink(path: string, expireDays?: number): Promise<SynologyShareLink> {
    const params: Record<string, string> = {
      api: 'SYNO.FileStation.Sharing',
      version: '3',
      method: 'create',
      path,
    };

    if (expireDays !== undefined && expireDays > 0) {
      const expiresAt = Math.floor(Date.now() / 1000) + expireDays * 24 * 60 * 60;
      params.date_expired = String(expiresAt);
    }

    const data = await this._request<SynologyCreateShareLinkResponse>('entry.cgi', params);
    const link = data.links?.[0];
    if (!link) {
      throw new ExternalServiceError('Synology did not return a share link');
    }

    return link;
  }

  private async _request<T>(
    cgiPath: string,
    params: Record<string, string>,
    retry = true
  ): Promise<T> {
    const sid = await this.auth.getSid();
    const requestParams: Record<string, string> = { ...params, _sid: sid };
    const url = this.buildUrl(cgiPath, requestParams);

    const response = await fetch(url, { method: 'GET' });
    if (!response.ok) {
      throw new ExternalServiceError(
        'Failed to call Synology API',
        response.status,
        'SYNOLOGY_HTTP_ERROR',
        {
          cgiPath,
        }
      );
    }

    const payload = (await response.json()) as SynologyResponse<T>;
    if (!payload.success) {
      const code = payload.error?.code;

      if (
        retry &&
        (code === SynologyErrorCode.INVALID_SID || code === SynologyErrorCode.EXPIRED_SID)
      ) {
        await this.auth.invalidateSession();
        return this._request<T>(cgiPath, params, false);
      }

      this.throwMappedError(code);
    }

    // When Synology returns success without data (e.g. createFolder, deleteFiles),
    // callers expect Promise<void> and discard this value.
    if (payload.data === undefined) {
      return {} as T;
    }

    return payload.data;
  }

  private buildUrl(cgiPath: string, params: Record<string, string>): string {
    const searchParams = new URLSearchParams(params);
    return `${this.apiUrl}/webapi/${cgiPath}?${searchParams.toString()}`;
  }

  private throwMappedError(code?: number): never {
    switch (code) {
      case SynologyErrorCode.INVALID_PARAM:
        throw new ValidationError(
          'Invalid request parameters for Synology API',
          'SYNOLOGY_INVALID_PARAM',
          {
            code,
          }
        );
      case SynologyErrorCode.INVALID_SID:
      case SynologyErrorCode.EXPIRED_SID:
        throw new AuthenticationError(
          'Synology session is invalid or expired',
          'SYNOLOGY_INVALID_SESSION',
          {
            code,
          }
        );
      case SynologyErrorCode.INVALID_PATH:
      case SynologyErrorCode.NOT_EXIST:
        throw new NotFoundError(
          'Requested path does not exist in Synology',
          'SYNOLOGY_PATH_NOT_FOUND',
          {
            code,
          }
        );
      case SynologyErrorCode.FILE_EXISTS:
        throw new ValidationError('Target file or folder already exists', 'SYNOLOGY_FILE_EXISTS', {
          code,
        });
      case SynologyErrorCode.NO_SPACE:
        throw new ExternalServiceError(
          'Synology reports no available space',
          507,
          'SYNOLOGY_NO_SPACE',
          {
            code,
          }
        );
      case SynologyErrorCode.UNKNOWN:
        throw new ExternalServiceError(
          'Synology returned an unknown error',
          502,
          'SYNOLOGY_UNKNOWN_ERROR',
          {
            code,
          }
        );
      default:
        throw new ExternalServiceError('Synology API request failed', 502, 'SYNOLOGY_API_ERROR', {
          code,
        });
    }
  }

  private async streamToArrayBuffer(stream: ReadableStream): Promise<ArrayBuffer> {
    const response = new Response(stream);
    return response.arrayBuffer();
  }
}
