export interface SynologyResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: number;
  };
}

export interface SynologyAuthResponse {
  sid: string;
}

export interface SynologyFileInfo {
  path: string;
  name: string;
  isdir: boolean;
  additional?: {
    size: number;
    time: {
      atime: number;
      mtime: number;
      ctime: number;
      crtime: number;
    };
    type: string;
  };
}

export interface SynologyFileList {
  files: SynologyFileInfo[];
  total: number;
  offset: number;
}

export interface SynologyShareLink {
  id: string;
  url: string;
  path: string;
  date_expired: string;
}

export enum SynologyErrorCode {
  UNKNOWN = 100,
  INVALID_PARAM = 101,
  INVALID_SID = 117,
  EXPIRED_SID = 119,
  INVALID_PATH = 400,
  NOT_EXIST = 401,
  FILE_EXISTS = 414,
  NO_SPACE = 418,
}

export interface SynologyFileStationInfo {
  hostname?: string;
  support_sharing?: boolean;
  is_manager?: boolean;
}

export interface ListFilesOptions {
  folderPath: string;
  offset?: number;
  limit?: number;
  sortBy?: string;
  sortDirection?: 'asc' | 'desc';
  additional?: string[];
}
