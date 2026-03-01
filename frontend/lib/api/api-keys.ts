import { authFetch, controlPlaneApiUrl, readApiError } from "./client";

export type ApiKeyListItem = {
	id: string;
	name: string;
	key_prefix: string;
	scopes: string[];
	last_used_at?: string | null;
	expires_at?: string | null;
	created_at: string;
	revoked_at?: string | null;
};

export type ApiKeyListResponse = {
	keys: ApiKeyListItem[];
};

export type CreateApiKeyRequest = {
	name: string;
	scopes?: string[];
	expires_at?: string | null;
};

export type CreateApiKeyResponse = {
	api_key: string;
	id: string;
	name: string;
	key_prefix: string;
	scopes: string[];
	last_used_at?: string | null;
	expires_at?: string | null;
	created_at: string;
	revoked_at?: string | null;
};

export async function listApiKeys(): Promise<ApiKeyListItem[]> {
	const res = await authFetch(controlPlaneApiUrl("/api/keys"), {
		credentials: "include",
	});
	if (!res.ok) throw new Error(await readApiError(res));
	const data = (await res.json()) as ApiKeyListResponse;
	return data.keys ?? [];
}

export async function createApiKey(
	request: CreateApiKeyRequest,
): Promise<CreateApiKeyResponse> {
	const res = await authFetch(controlPlaneApiUrl("/api/keys"), {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(request),
		credentials: "include",
	});
	if (!res.ok) throw new Error(await readApiError(res));
	return res.json();
}

export async function revokeApiKey(id: string): Promise<void> {
	const res = await authFetch(controlPlaneApiUrl(`/api/keys/${id}/revoke`), {
		method: "DELETE",
		credentials: "include",
	});
	if (res.status === 404) return;
	if (!res.ok) throw new Error(await readApiError(res));
}

export async function deleteApiKey(id: string): Promise<void> {
	const res = await authFetch(controlPlaneApiUrl(`/api/keys/${id}`), {
		method: "DELETE",
		credentials: "include",
	});
	if (res.status === 404) return;
	if (!res.ok) throw new Error(await readApiError(res));
}
