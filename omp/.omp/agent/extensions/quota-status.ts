import type { UsageLimit, UsageReport } from "@oh-my-pi/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

const PROVIDERS = [
	{ id: "openai-codex", label: "Codex", limits: ["openai-codex:primary", "openai-codex:secondary", "openai-codex:spend-cap"] },
	{ id: "opencode-go", label: "OpenCode Go", limits: ["rolling-5h", "weekly", "monthly"] },
] as const;
const POLL_MS = 60_000;
const STALE_MS = 10 * 60_000;

function duration(ms: number): string {
	const minutes = Math.max(1, Math.ceil(ms / 60_000));
	if (minutes < 60) return `${minutes}m`;
	const hours = Math.floor(minutes / 60);
	if (hours < 24) return `${hours}h${minutes % 60 || ""}${minutes % 60 ? "m" : ""}`;
	return `${Math.floor(hours / 24)}d${hours % 24 || ""}${hours % 24 ? "h" : ""}`;
}

function percent(limit: UsageLimit): string {
	const amount = limit.amount;
	const fraction = amount.usedFraction ??
		(amount.used !== undefined && amount.limit !== undefined && amount.limit > 0
			? amount.used / amount.limit
			: amount.unit === "percent" && amount.used !== undefined
				? amount.used / 100
				: amount.remainingFraction !== undefined ? 1 - amount.remainingFraction : undefined);
	return fraction !== undefined && Number.isFinite(fraction) && fraction >= 0
		? `${Math.round(fraction * 100)}%` : "?";
}

function summary(report: UsageReport, provider: (typeof PROVIDERS)[number], now: number): string {
	const limits = provider.limits.flatMap(id => report.limits.filter(limit => limit.id === id));
	if (limits.length === 0) return "unavailable";
	const windows = limits.map(limit => {
		// Use normalized window ids, never account metadata or raw provider text.
		const id = limit.window?.id;
		const label = id && /^(?:\d+[hd]|monthly|primary|secondary)$/.test(id) ? id : "cap";
		const reset = limit.window?.resetsAt;
		const countdown = reset !== undefined && Number.isFinite(reset)
			? reset > now ? ` ↻${duration(reset - now)}` : " ↻due"
			: "";
		return `${label} ${percent(limit)}${countdown}`;
	});
	const age = now - report.fetchedAt;
	const freshness = !Number.isFinite(age) || age < 0 ? "age unknown"
		: `${age >= STALE_MS ? "stale " : ""}${Math.floor(age / 60_000)}m old`;
	return `used: ${windows.join(" · ")} · ${freshness}`;
}

export default function quotaStatus(pi: ExtensionAPI) {
	let stop: (() => void) | undefined;

	function start(ctx: ExtensionContext): void {
		stop?.();
		if (ctx.mode !== "tui" || ctx.agent.kind !== "main") return;
		const controller = new AbortController();
		const keys = new Map<string, Set<string>>();
		let inFlight = false;

		function publish(provider: (typeof PROVIDERS)[number], reports: UsageReport[] | null): void {
			if (controller.signal.aborted) return;
			const previous = keys.get(provider.id) ?? new Set<string>();
			const next = new Set<string>();
			const accounts = reports?.filter(report => report.provider === provider.id) ?? [];
			const rows = accounts.length ? accounts.map(report => summary(report, provider, Date.now())) : ["unavailable"];
			rows.forEach((text, index) => {
				const key = `quota-${provider.id}-${index}`;
				next.add(key);
				const account = rows.length > 1 ? ` #${index + 1}` : "";
				ctx.ui.setStatus(key, `${provider.label}${account} · ${text}`);
			});
			for (const key of previous) if (!next.has(key)) ctx.ui.setStatus(key, undefined);
			keys.set(provider.id, next);
		}

		async function refresh(): Promise<void> {
			if (inFlight || controller.signal.aborted) return;
			inFlight = true;
			try {
				await Promise.all(PROVIDERS.map(async provider => {
					try {
						const reports = await ctx.modelRegistry.authStorage.usage.reports({
							provider: provider.id,
							baseUrlResolver: id => ctx.modelRegistry.getProviderBaseUrl(id),
							signal: controller.signal,
						});
						publish(provider, reports);
					} catch {
						// Do not expose provider errors, credentials, or raw responses in the UI.
						publish(provider, null);
					}
				}));
			} finally {
				inFlight = false;
			}
		}

		for (const provider of PROVIDERS) {
			const key = `quota-${provider.id}-0`;
			keys.set(provider.id, new Set([key]));
			ctx.ui.setStatus(key, `${provider.label} · quota pending`);
		}
		const timer = ctx.setInterval(() => void refresh(), POLL_MS);
		stop = () => {
			controller.abort();
			ctx.clearTimer(timer);
			for (const entries of keys.values()) for (const key of entries) ctx.ui.setStatus(key, undefined);
		};
		void refresh();
	}

	pi.on("session_start", (_event, ctx) => start(ctx));
	pi.on("session_switch", (_event, ctx) => start(ctx));
	pi.on("session_shutdown", () => stop?.());
}
