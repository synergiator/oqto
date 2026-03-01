import { authFetch, controlPlaneApiUrl, readApiError } from "./client";

export type OAuthProviderInfo = {
	id: string;
	name: string;
	connected: boolean;
};

export type OAuthProvidersResponse = {
	enabled: boolean;
	providers: OAuthProviderInfo[];
};

export type OAuthLoginResponse = {
	auth_url?: string | null;
	instructions: string;
	verification_uri?: string | null;
	user_code?: string | null;
	device_code?: string | null;
	interval?: number | null;
	expires_in?: number | null;
	state?: string | null;
	code_verifier?: string | null;
};

export type OAuthStatusResponse = {
	status: string;
	provider: string;
	user_id: string;
};

export type OAuthPollResponse = {
	status: string;
	interval?: number | null;
};

export async function listOAuthProviders(): Promise<OAuthProvidersResponse> {
	const res = await authFetch(controlPlaneApiUrl("/api/oauth/providers"), {
		credentials: "include",
	});
	if (!res.ok) throw new Error(await readApiError(res));
	return res.json();
}

export async function startOAuthLogin(
	provider: string,
): Promise<OAuthLoginResponse> {
	const res = await authFetch(
		controlPlaneApiUrl(`/api/oauth/login/${provider}`),
		{
			method: "POST",
			credentials: "include",
		},
	);
	if (!res.ok) throw new Error(await readApiError(res));
	return res.json();
}

export async function submitOAuthCallback(
	code: string,
	state: string,
): Promise<OAuthStatusResponse> {
	const res = await authFetch(controlPlaneApiUrl("/api/oauth/callback"), {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify({ code, state }),
		credentials: "include",
	});
	if (!res.ok) throw new Error(await readApiError(res));
	return res.json();
}

export async function pollOAuthDevice(
	provider: string,
	deviceCode: string,
): Promise<OAuthPollResponse> {
	const res = await authFetch(
		controlPlaneApiUrl(`/api/oauth/poll/${provider}`),
		{
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({ device_code: deviceCode }),
			credentials: "include",
		},
	);
	if (!res.ok) throw new Error(await readApiError(res));
	return res.json();
}

export async function deleteOAuthProvider(provider: string): Promise<void> {
	const res = await authFetch(controlPlaneApiUrl(`/api/oauth/${provider}`), {
		method: "DELETE",
		credentials: "include",
	});
	if (res.status === 404) return;
	if (!res.ok) throw new Error(await readApiError(res));
}
