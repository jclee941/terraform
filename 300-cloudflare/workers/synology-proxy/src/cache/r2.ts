export class R2Cache {
  private readonly bucket: R2Bucket;
  private readonly ttlDays: number;

  public constructor(bucket: R2Bucket, ttlDays = 7) {
    this.bucket = bucket;
    this.ttlDays = ttlDays;
  }

  public async get(key: string): Promise<R2ObjectBody | null> {
    const object = await this.bucket.get(key);
    if (object === null) {
      return null;
    }

    if (this.isExpired(object)) {
      await this.delete(key);
      return null;
    }

    return object;
  }

  public async put(
    key: string,
    value: ReadableStream | ArrayBuffer | ArrayBufferView,
    metadata?: Record<string, string>
  ): Promise<void> {
    const expiresAt = Date.now() + this.ttlDays * 24 * 60 * 60 * 1000;
    const customMetadata: Record<string, string> = {
      expiresAt: String(expiresAt),
      ...(metadata ?? {}),
    };

    await this.bucket.put(key, value, {
      customMetadata,
    });
  }

  public async delete(key: string): Promise<void> {
    await this.bucket.delete(key);
  }

  public async invalidateByPrefix(prefix: string): Promise<void> {
    let cursor: string | undefined;

    do {
      const listed = await this.bucket.list({ prefix, cursor });
      await Promise.all(listed.objects.map(async (object) => this.bucket.delete(object.key)));
      cursor = listed.truncated ? listed.cursor : undefined;
    } while (cursor !== undefined);
  }

  public generateCacheKey(filePath: string): string {
    return `downloads/${encodeURIComponent(filePath)}`;
  }

  public isExpired(object: R2Object): boolean {
    const expiresAtValue = object.customMetadata?.expiresAt;
    if (!expiresAtValue) {
      return false;
    }

    const expiresAt = Number(expiresAtValue);
    if (Number.isNaN(expiresAt)) {
      return false;
    }

    return Date.now() > expiresAt;
  }
}
