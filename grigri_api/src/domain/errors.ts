/** An error the API answers as `{"error": message}` with this status. */
export class ApiError extends Error {
  constructor(
    readonly status: 400 | 401 | 403 | 404 | 409 | 413 | 415,
    message: string,
  ) {
    super(message);
  }
}

export const badRequest = (message: string) => new ApiError(400, message);
export const forbidden = (message = 'not allowed') => new ApiError(403, message);
export const notFound = (message = 'not found') => new ApiError(404, message);
export const conflict = (message: string) => new ApiError(409, message);
