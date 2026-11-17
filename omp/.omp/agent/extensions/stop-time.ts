import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

type Block = { type: string; text?: string };
type Reply = { content: Block[]; stopReason?: string; completedAt?: number };

function stamp(at: number, now: Date): string {
	const time = new Date(at);
	const pad = (value: number) => String(value).padStart(2, "0");
	const clock = `${pad(time.getHours())}:${pad(time.getMinutes())}`;
	if (time.toDateString() === now.toDateString()) return clock;
	return `${time.getFullYear()}-${pad(time.getMonth() + 1)}-${pad(time.getDate())} ${clock}`;
}

// Mark when the agent yielded, so the age of the provider prompt cache is visible.
export default function stopTime(pi: ExtensionAPI) {
	pi.registerAssistantTextRenderer(({ message, contentIndex, text, streaming }) => {
		const reply = message as Reply;
		// omp sets completedAt at message_end, so a reply in progress has none.
		if (streaming || reply.completedAt === undefined || reply.stopReason === "toolUse") return;
		if (reply.content.some(block => block.type === "toolCall")) return;
		const last = reply.content.findLastIndex(block => block.type === "text" && !!block.text);
		if (contentIndex !== last) return;
		return `${text}\n\n_stopped at ${stamp(reply.completedAt, new Date())}_`;
	});
}
