import { homedir } from "node:os";
import { basename, sep } from "node:path";
import { resolveUsedFraction, type UsageLimit, type UsageReport } from "@oh-my-pi/pi-ai";
import { theme, type ExtensionAPI, type ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import { getComposerStyle, truncateToWidth, visibleWidth } from "@oh-my-pi/pi-tui";

const WIDGET = "compact-status";
const MINUTE = 60_000;
const WEEK = 7 * 24 * 60 * MINUTE;
type Identity = { email?: string; accountId?: string; orgId?: string; projectId?: string };

function clean(text: string): string {
	return text.replace(/[\u0000-\u001f\u007f-\u009f]/g, "");
}

function countdown(reset: number | undefined, now: number): string {
	if (reset === undefined || !Number.isFinite(reset)) return "?";
	if (reset <= now) return "now";
	const minutes = Math.ceil((reset - now) / MINUTE);
	if (minutes < 60) return `${minutes}m`;
	const hours = Math.floor(minutes / 60);
	if (hours < 24) return `${hours}h${minutes % 60 ? `${minutes % 60}m` : ""}`;
	return `${Math.floor(hours / 24)}d${hours % 24 ? `${hours % 24}h` : ""}`;
}

function matchesAccount(report: UsageReport, limit: UsageLimit, identity: Identity | undefined): boolean {
	if (!identity) return true;
	const normalize = (value: unknown) => typeof value === "string" ? value.trim().toLowerCase() : "";
	const metadata = report.metadata ?? {};
	const org = normalize(identity.orgId);
	if (org !== normalize(metadata.orgId ?? limit.scope.orgId)) return false;
	if (identity.email && metadata.email) return normalize(identity.email) === normalize(metadata.email);
	for (const field of ["accountId", "projectId"] as const) {
		const active = normalize(identity[field]);
		if (active && (active === normalize(metadata[field]) || active === normalize(limit.scope[field]))) return true;
	}
	return !!org && !identity.email && !identity.accountId && !identity.projectId;
}

function quotaWindow(reports: UsageReport[], ctx: ExtensionContext, duration: number, label: string, now: number): string {
	const model = ctx.models.current();
	if (!model) return "";
	const identity = ctx.modelRegistry.authStorage.oauth.identity(model.provider, ctx.sessionManager.getSessionId());
	// Without a selected identity, multiple accounts cannot produce one honest percentage.
	if (!identity && reports.length > 1) return `${label} ?`;
	const limits = reports.flatMap(report => report.limits
		.filter(limit => matchesAccount(report, limit, identity))
		.filter(limit => !limit.scope.modelId || limit.scope.modelId.toLowerCase() === model.id.toLowerCase())
		.filter(limit => limit.scope.windowId === label || limit.window?.id === label ||
			(limit.window?.durationMs !== undefined && Math.abs(limit.window.durationMs - duration) <= MINUTE))
		.map(limit => ({ limit, fetchedAt: report.fetchedAt })));
	// An overall limit and a model-specific limit can both constrain the same model.
	const known = limits.filter(({ limit }) => Number.isFinite(resolveUsedFraction(limit)));
	known.sort((a, b) => resolveUsedFraction(b.limit)! - resolveUsedFraction(a.limit)!);
	const selected = known[0];
	if (!selected) return `${label} ?`;
	const { limit, fetchedAt } = selected;
	const reset = limit.window?.resetsAt;
	const expired = reset !== undefined && reset <= now;
	const stale = !Number.isFinite(fetchedAt) || now - fetchedAt > 10 * MINUTE;
	const remaining = Math.max(0, Math.min(100, Math.round((1 - resolveUsedFraction(limit)!) * 100)));
	const color = expired || stale || remaining <= 20 ? "warning" : remaining <= 50 ? "accent" : "success";
	const amount = expired ? "?" : `${stale ? "~" : ""}${remaining}%`;
	return `${label} ${theme.fg(color, amount)} ${theme.fg("dim", `(${countdown(reset, now)})`)}`;
}

function fit(parts: string[], width: number): string {
	if (parts.length === 0) return "";
	const total = parts.reduce((sum, part) => sum + visibleWidth(part), 0);
	const gap = parts.length > 1 ? Math.max(2, Math.floor((width - total) / (parts.length - 1))) : 0;
	return truncateToWidth(parts.join(" ".repeat(gap)), width);
}

export default function compactStatus(pi: ExtensionAPI) {
	// Reuse the built-in input chrome; only replace its detached status bar.
	pi.registerComposerShape({
		label: "Accent Rail · Compact Status",
		description: "Rail input with model, path, context left, and active-provider quota left",
		style: { ...getComposerStyle("rail"), id: WIDGET, bottomBar: "none", bottomBarGap: false },
	});

	let stop: (() => void) | undefined;
	function start(ctx: ExtensionContext): void {
		stop?.();
		if (ctx.mode !== "tui" || ctx.agent.kind !== "main") return;
		let disposed = false;
		let reports: UsageReport[] = [];
		let request: AbortController | undefined;
		let requestKey = "";
		let refreshedAt = 0;
		let branch = "";
		let branchCwd = "";
		let branchAt = 0;
		let branchInFlight = false;
		let repaint: () => void;
		let lastFrame = "";

		function render(width: number): string[] {
			const now = Date.now();
			const model = ctx.models.current();
			const level = model?.thinking ? pi.getThinkingLevel() : "off";
			const thinking = theme.thinking[level as keyof typeof theme.thinking] ?? level;
			const modelText = theme.fg("statusLineModel",
				`${theme.icon.model} ${clean(model?.name ?? "No model")}${theme.sep.dot}${thinking}`);
			const cwd = ctx.cwd;
			const home = homedir();
			const path = cwd === home ? "~" : cwd.startsWith(home + sep) ? "~" + cwd.slice(home.length) : cwd;
			const shortened = path.split(sep).map((part, index, parts) =>
				index < parts.length - 1 && part !== "~" ? part.slice(0, 1) : part).join(sep);
			const suffix = branchCwd === cwd && branch
				? ` ${theme.fg("statusLineGitClean", `${theme.icon.branch} ${clean(branch)}`)}` : "";
			const paths = [path, shortened, basename(cwd) || cwd].map(value =>
				`${theme.fg("statusLinePath", `${theme.icon.folder} ${clean(value)}`)}${suffix}`);
			const context = ctx.getContextUsage();
			const left = context && Number.isFinite(context.percent)
				? Math.max(0, Math.min(100, Math.round(100 - context.percent))) : undefined;
			const contextText = theme.fg(left !== undefined && left <= 20 ? "warning" : "statusLineContext",
				`${theme.icon.context} ${left ?? "?"}% ctx left`);
			const provider = model?.provider;
			const active = reports.filter(report => report.provider === provider);
			const quota = provider && ctx.modelRegistry.authStorage.usage.providerFor(provider)
				? `${theme.icon.time} ${quotaWindow(active, ctx, 5 * 60 * MINUTE, "5h", now)}  ${quotaWindow(active, ctx, WEEK, "7d", now)}`
				: "";
			const tail = [contextText, quota].filter(Boolean);
			const available = Math.max(1, width - 2);
			for (const pathText of paths) {
				const parts = [modelText, pathText, ...tail];
				if (parts.reduce((sum, part) => sum + visibleWidth(part), 0) + (parts.length - 1) * 2 <= available)
					return [" " + fit(parts, available)];
			}
			// Keep reset times on small panes instead of silently dropping the quota group.
			return [" " + fit([modelText, paths[2]], available), " " + fit(tail, available)];
		}

		async function refreshUsage(now: number): Promise<void> {
			const model = ctx.models.current();
			const provider = model?.provider;
			const identity = provider
				? ctx.modelRegistry.authStorage.oauth.identity(provider, ctx.sessionManager.getSessionId()) : undefined;
			const key = JSON.stringify([provider, model?.id, identity]);
			if (key !== requestKey) {
				request?.abort();
				request = undefined;
				requestKey = key;
				refreshedAt = 0;
				reports = [];
			}
			if (!provider || !ctx.modelRegistry.authStorage.usage.providerFor(provider) ||
				request || now - refreshedAt < MINUTE) return;
			const controller = new AbortController();
			request = controller;
			refreshedAt = now;
			try {
				const result = await ctx.modelRegistry.authStorage.usage.reports({
					provider, signal: controller.signal,
					baseUrlResolver: id => ctx.modelRegistry.getProviderBaseUrl(id),
				});
				if (!disposed && !controller.signal.aborted && request === controller) {
					reports = result?.filter(report => report.provider === provider) ?? [];
					repaint();
				}
			} catch {
				// Retain only the host's last report, never provider errors or raw responses.
			} finally {
				if (request === controller) request = undefined;
			}
		}

		async function refreshBranch(now: number): Promise<void> {
			if (branchInFlight || (branchCwd === ctx.cwd && now - branchAt < 5_000)) return;
			const cwd = ctx.cwd;
			branchInFlight = true;
			try {
				const result = await pi.exec("git", ["branch", "--show-current"], { cwd, timeout: 2_000 });
				if (!disposed && cwd === ctx.cwd) {
					branch = result.code === 0 ? result.stdout.trim() || "detached" : "";
					branchCwd = cwd;
					branchAt = now;
					repaint();
				}
			} catch {
				branch = "";
				branchCwd = cwd;
				branchAt = now;
			} finally {
				branchInFlight = false;
			}
		}

		ctx.ui.setWidget(WIDGET, tui => {
			repaint = () => tui.requestRender();
			return { render, invalidate() { lastFrame = ""; } };
		}, { placement: "belowEditor" });
		const tick = () => {
			const now = Date.now();
			void refreshUsage(now);
			void refreshBranch(now);
			const model = ctx.models.current();
			const usage = ctx.getContextUsage();
			const frame = JSON.stringify([ctx.cwd, model?.provider, model?.id, pi.getThinkingLevel(), usage?.percent,
				Math.floor(now / MINUTE)]);
			if (frame !== lastFrame) {
				lastFrame = frame;
				repaint();
			}
		};
		const timer = ctx.setInterval(tick, 1_000);
		stop = () => {
			disposed = true;
			request?.abort();
			ctx.clearTimer(timer);
			ctx.ui.setWidget(WIDGET, undefined);
		};
		tick();
	}
	pi.on("session_start", (_event, ctx) => start(ctx));
	pi.on("session_switch", (_event, ctx) => start(ctx));
	pi.on("session_shutdown", () => stop?.());
}
