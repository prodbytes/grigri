// A tiny router: "METHOD /path/{param}" patterns to handlers.
import { ApiError } from './domain/errors.js';

export type Params = Record<string, string>;

interface Route<T> {
  method: string;
  parts: string[];
  handler: T;
}

export class Router<T> {
  private readonly routes: Route<T>[] = [];

  add(pattern: string, handler: T): this {
    const [method, path] = pattern.split(' ');
    this.routes.push({ method: method!, parts: split(path!), handler });
    return this;
  }

  /** The handler and path parameters, or a 404 (no path) / 405 (no method). */
  match(method: string, path: string): { handler: T; params: Params } {
    const parts = split(path);
    let pathMatched = false;
    for (const route of this.routes) {
      const params = matchParts(route.parts, parts);
      if (!params) continue;
      pathMatched = true;
      if (route.method === method) return { handler: route.handler, params };
    }
    if (pathMatched) throw new ApiError(404, `${method} isn't supported here`);
    throw new ApiError(404, 'no such route');
  }
}

function split(path: string): string[] {
  return path.split('/').filter((p) => p.length > 0);
}

function matchParts(pattern: string[], parts: string[]): Params | undefined {
  if (pattern.length !== parts.length) return undefined;
  const params: Params = {};
  for (const [i, p] of pattern.entries()) {
    const part = parts[i]!;
    if (p.startsWith('{') && p.endsWith('}')) {
      let value: string;
      try {
        value = decodeURIComponent(part);
      } catch {
        return undefined;
      }
      params[p.slice(1, -1)] = value;
    } else if (p !== part) {
      return undefined;
    }
  }
  return params;
}
