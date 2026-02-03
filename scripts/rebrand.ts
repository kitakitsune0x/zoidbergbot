#!/usr/bin/env node
/**
 * Rebrand script: openclaw -> zoidbergbot
 *
 * This script performs bulk find-and-replace operations to rebrand the codebase.
 * It handles:
 * - File content replacements
 * - File and directory renames
 * - Case-sensitive pattern matching
 *
 * Usage: bun scripts/rebrand.ts [--dry-run]
 */

import { readdir, readFile, writeFile, rename } from "node:fs/promises";
import { join, basename, dirname } from "node:path";

const DRY_RUN = process.argv.includes("--dry-run");

// Directories and files to skip
const SKIP_DIRS = new Set([
	"node_modules",
	".git",
	"dist",
	".build",
	".next",
	".turbo",
	".pnpm-store",
	"coverage",
	".cursor",
]);

const SKIP_FILES = new Set([
	"pnpm-lock.yaml",
	"package-lock.json",
	"yarn.lock",
	"bun.lockb",
	".DS_Store",
	"rebrand.ts", // Don't modify this script
]);

// Binary file extensions to skip
const BINARY_EXTENSIONS = new Set([
	".png",
	".jpg",
	".jpeg",
	".gif",
	".webp",
	".ico",
	".icns",
	".woff",
	".woff2",
	".ttf",
	".otf",
	".eot",
	".mp3",
	".mp4",
	".wav",
	".ogg",
	".webm",
	".zip",
	".tar",
	".gz",
	".dmg",
	".exe",
	".app",
	".dylib",
	".so",
	".dll",
	".pdf",
]);

// Content replacements (order matters - longer/more specific patterns first)
const CONTENT_REPLACEMENTS: Array<{ from: string; to: string }> = [
	// Package scope (must come before generic openclaw)
	{ from: "@openclaw/", to: "@zoidbergbot/" },

	// URLs and domains
	{ from: "docs.openclaw.ai", to: "docs.zoidbergbot.ai" },
	{ from: "openclaw.ai", to: "zoidbergbot.ai" },
	{ from: "github.com/openclaw/openclaw", to: "github.com/zoidbergbot/zoidbergbot" },
	{ from: "github.com/openclaw", to: "github.com/zoidbergbot" },

	// Bundle identifiers
	{ from: "ai.openclaw.shared", to: "ai.zoidbergbot.shared" },
	{ from: "ai.openclaw.mac.deeplink", to: "ai.zoidbergbot.mac.deeplink" },
	{ from: "ai.openclaw.mac", to: "ai.zoidbergbot.mac" },
	{ from: "ai.openclaw.ios.tests", to: "ai.zoidbergbot.ios.tests" },
	{ from: "ai.openclaw.ios", to: "ai.zoidbergbot.ios" },
	{ from: "ai.openclaw.android", to: "ai.zoidbergbot.android" },
	{ from: "ai.openclaw", to: "ai.zoidbergbot" },

	// Bonjour service
	{ from: "_openclaw-gw._tcp", to: "_zoidbergbot-gw._tcp" },

	// Deep link scheme
	{ from: "openclaw://", to: "zoidbergbot://" },

	// Config paths
	{ from: "~/.openclaw-", to: "~/.zoidbergbot-" },
	{ from: "~/.openclaw/", to: "~/.zoidbergbot/" },
	{ from: "~/.openclaw", to: "~/.zoidbergbot" },
	{ from: ".openclaw/", to: ".zoidbergbot/" },
	{ from: ".openclaw-", to: ".zoidbergbot-" },
	{ from: '".openclaw"', to: '".zoidbergbot"' },
	{ from: '".openclaw\\\\', to: '".zoidbergbot\\\\' },
	{ from: "`.openclaw`", to: "`.zoidbergbot`" },

	// Client IDs
	{ from: "openclaw-ios", to: "zoidbergbot-ios" },
	{ from: "openclaw-android", to: "zoidbergbot-android" },

	// Config file names
	{ from: "openclaw.json", to: "zoidbergbot.json" },

	// Plugin SDK imports
	{ from: "openclaw/plugin-sdk", to: "zoidbergbot/plugin-sdk" },
	{ from: "openclaw/cli-entry", to: "zoidbergbot/cli-entry" },

	// Environment variables (UPPERCASE)
	{ from: "OPENCLAW_", to: "ZOIDBERGBOT_" },

	// Service names
	{ from: "openclaw-gateway", to: "zoidbergbot-gateway" },
	{ from: "openclaw-auth-monitor", to: "zoidbergbot-auth-monitor" },
	{ from: "openclaw-mac", to: "zoidbergbot-mac" },
	{ from: "openclaw-macos", to: "zoidbergbot-macos" },
	{ from: "openclaw-cli", to: "zoidbergbot-cli" },

	// Type names (PascalCase) - specific types first
	{ from: "OpenClawProtocol", to: "ZoidbergBotProtocol" },
	{ from: "OpenClawConfig", to: "ZoidbergBotConfig" },
	{ from: "OpenClawPluginApi", to: "ZoidbergBotPluginApi" },
	{ from: "OpenClawPlugin", to: "ZoidbergBotPlugin" },
	{ from: "OpenClawKit", to: "ZoidbergBotKit" },
	{ from: "OpenClawNode", to: "ZoidbergBotNode" },
	{ from: "OpenClawTests", to: "ZoidbergBotTests" },
	{ from: "OpenClaw", to: "ZoidbergBot" },

	// Docker images
	{ from: "openclaw/sandbox", to: "zoidbergbot/sandbox" },
	{ from: "openclaw/browser", to: "zoidbergbot/browser" },

	// Tagline
	{ from: "All your chats, one OpenClaw.", to: "All your chats, one ZoidbergBot." },

	// Theme names (Android)
	{ from: "Theme.OpenClawNode", to: "Theme.ZoidbergBotNode" },

	// CLI commands in docs/strings
	{ from: "openclaw pairing", to: "zoidbergbot pairing" },
	{ from: "openclaw plugins", to: "zoidbergbot plugins" },
	{ from: "openclaw voicecall", to: "zoidbergbot voicecall" },
	{ from: "openclaw models", to: "zoidbergbot models" },
	{ from: "openclaw gateway", to: "zoidbergbot gateway" },
	{ from: "openclaw config", to: "zoidbergbot config" },
	{ from: "openclaw channels", to: "zoidbergbot channels" },
	{ from: "openclaw agent", to: "zoidbergbot agent" },
	{ from: "openclaw message", to: "zoidbergbot message" },
	{ from: "openclaw doctor", to: "zoidbergbot doctor" },
	{ from: "openclaw login", to: "zoidbergbot login" },
	{ from: "openclaw status", to: "zoidbergbot status" },
	{ from: "openclaw send", to: "zoidbergbot send" },
	{ from: "openclaw tui", to: "zoidbergbot tui" },

	// camelCase variable names
	{ from: "openclawConfig", to: "zoidbergbotConfig" },
	{ from: "openclawPollId", to: "zoidbergbotPollId" },
	{ from: "openclawHome", to: "zoidbergbotHome" },
	{ from: "openclawDir", to: "zoidbergbotDir" },
	{ from: "openclawPath", to: "zoidbergbotPath" },

	// Temp directories
	{ from: '"openclaw-', to: '"zoidbergbot-' },
	{ from: "'openclaw-", to: "'zoidbergbot-" },
	{ from: "`openclaw-", to: "`zoidbergbot-" },

	// Additional CLI commands and patterns
	{ from: "openclaw help", to: "zoidbergbot help" },
	{ from: "openclaw start", to: "zoidbergbot start" },
	{ from: "openclaw run", to: "zoidbergbot run" },
	{ from: "openclaw hooks", to: "zoidbergbot hooks" },
	{ from: "openclaw sandbox", to: "zoidbergbot sandbox" },
	{ from: "openclaw browser", to: "zoidbergbot browser" },
	{ from: "openclaw skills", to: "zoidbergbot skills" },
	{ from: "openclaw canvas", to: "zoidbergbot canvas" },
	{ from: "openclaw node", to: "zoidbergbot node" },
	{ from: "openclaw security", to: "zoidbergbot security" },
	{ from: "openclaw approvals", to: "zoidbergbot approvals" },
	{ from: "openclaw dns", to: "zoidbergbot dns" },
	{ from: "openclaw update", to: "zoidbergbot update" },
	{ from: "openclaw reset", to: "zoidbergbot reset" },
	{ from: "openclaw logs", to: "zoidbergbot logs" },
	{ from: "openclaw cron", to: "zoidbergbot cron" },
	{ from: "openclaw tool", to: "zoidbergbot tool" },
	{ from: "openclaw webhooks", to: "zoidbergbot webhooks" },
	{ from: "openclaw acp", to: "zoidbergbot acp" },
	{ from: "openclaw profile", to: "zoidbergbot profile" },

	// Package manager and npm patterns
	{ from: "npm i -g openclaw", to: "npm i -g zoidbergbot" },
	{ from: "npm install -g openclaw", to: "npm install -g zoidbergbot" },
	{ from: "npm i openclaw", to: "npm i zoidbergbot" },
	{ from: "npx openclaw", to: "npx zoidbergbot" },
	{ from: "pnpm openclaw", to: "pnpm zoidbergbot" },
	{ from: "bunx openclaw", to: "bunx zoidbergbot" },

	// Test helpers naming patterns
	{ from: "OpenClawIPC", to: "ZoidbergBotIPC" },

	// Android package declarations
	{ from: "package ai.openclaw.android", to: "package ai.zoidbergbot.android" },
	{ from: "import ai.openclaw.android", to: "import ai.zoidbergbot.android" },
	{ from: "ai.openclaw.android.", to: "ai.zoidbergbot.android." },

	// Android class names
	{ from: "OpenClawCanvasA2UIAction", to: "ZoidbergBotCanvasA2UIAction" },
	{ from: "OpenClawProtocolConstants", to: "ZoidbergBotProtocolConstants" },
	{ from: "OpenClawTheme", to: "ZoidbergBotTheme" },

	// JavaScript globals and path segments
	{ from: "openclawA2UI", to: "zoidbergbotA2UI" },
	{ from: "__openclaw__", to: "__zoidbergbot__" },
	{ from: "openclaw@", to: "zoidbergbot@" },

	// More CLI variations
	{ from: "openclaw --", to: "zoidbergbot --" },
	{ from: "openclaw)", to: "zoidbergbot)" },
	{ from: "(openclaw", to: "(zoidbergbot" },

	// Test fixtures - bot usernames
	{ from: "openclaw_bot", to: "zoidbergbot_bot" },
	{ from: "openclawbot", to: "zoidbergbotbot" },

	// Regex patterns in tests (escaped brackets)
	{ from: "\\\\[openclaw\\\\]", to: "\\\\[zoidbergbot\\\\]" },

	// Bonjour/DNS patterns
	{ from: "openclaw-gw", to: "zoidbergbot-gw" },

	// Canvas/A2UI patterns
	{ from: '"openclaw"', to: '"zoidbergbot"' },
	{ from: "'openclaw'", to: "'zoidbergbot'" },

	// Canvas/A2UI JavaScript globals (camelCase)
	{ from: "openclawCanvasA2UIAction", to: "zoidbergbotCanvasA2UIAction" },
	{ from: "openclawPostMessage", to: "zoidbergbotPostMessage" },
	{ from: "openclawSendUserAction", to: "zoidbergbotSendUserAction" },
	{ from: "openclawBridge", to: "zoidbergbotBridge" },

	// Service names without dash
	{ from: "openclawgw", to: "zoidbergbotgw" },

	// CSS/HTML patterns (custom elements and animations)
	{ from: "openclaw-a2ui", to: "zoidbergbot-a2ui" },
	{ from: "openclaw-grid", to: "zoidbergbot-grid" },
	{ from: "openclaw-glow", to: "zoidbergbot-glow" },
	{ from: "openclaw-canvas", to: "zoidbergbot-canvas" },
	{ from: "openclaw-status", to: "zoidbergbot-status" },
	{ from: "<openclaw-", to: "<zoidbergbot-" },
	{ from: "</openclaw-", to: "</zoidbergbot-" },

	// Test data patterns
	{ from: "friends-of-openclaw", to: "friends-of-zoidbergbot" },

	// Remaining standalone patterns
	{ from: "-openclaw", to: "-zoidbergbot" },
	{ from: "openclaw-", to: "zoidbergbot-" },

	// Regex patterns with word boundaries
	{ from: "\\\\bopenclaw\\\\b", to: "\\\\bzoidbergbot\\\\b" },

	// @ mention patterns
	{ from: "@openclaw", to: "@zoidbergbot" },

	// macOS test directories
	{ from: "OpenClawIPCTests", to: "ZoidbergBotIPCTests" },

	// Generic replacements (lowercase) - must come last
	{ from: '"openclaw"', to: '"zoidbergbot"' },
	{ from: "'openclaw'", to: "'zoidbergbot'" },
	{ from: "`openclaw`", to: "`zoidbergbot`" },
	{ from: "/openclaw", to: "/zoidbergbot" },
	{ from: "openclaw:", to: "zoidbergbot:" },
	{ from: "openclaw.", to: "zoidbergbot." },

	// Standalone openclaw (careful with this one)
	{ from: " openclaw ", to: " zoidbergbot " },
	{ from: "(openclaw)", to: "(zoidbergbot)" },
	{ from: "[openclaw]", to: "[zoidbergbot]" },
];

// File/directory renames
const FILE_RENAMES: Array<{ from: string; to: string }> = [
	{ from: "openclaw.mjs", to: "zoidbergbot.mjs" },
	{ from: "openclaw-auth-monitor.service", to: "zoidbergbot-auth-monitor.service" },
	{ from: "openclaw-auth-monitor.timer", to: "zoidbergbot-auth-monitor.timer" },
];

// Directory renames (applied from deepest to shallowest)
const DIR_RENAMES: Array<{ from: string; to: string }> = [
	{ from: "OpenClawKit", to: "ZoidbergBotKit" },
	{ from: "OpenClawProtocol", to: "ZoidbergBotProtocol" },
	{ from: "OpenClaw", to: "ZoidbergBot" },
];

// Stats tracking
const stats = {
	filesScanned: 0,
	filesModified: 0,
	filesRenamed: 0,
	dirsRenamed: 0,
	replacements: 0,
};

function shouldSkip(path: string): boolean {
	const name = basename(path);
	if (SKIP_DIRS.has(name) || SKIP_FILES.has(name)) {
		return true;
	}
	const ext = name.includes(".") ? "." + name.split(".").pop()! : "";
	if (BINARY_EXTENSIONS.has(ext.toLowerCase())) {
		return true;
	}
	return false;
}

async function processFile(filePath: string): Promise<void> {
	stats.filesScanned++;

	try {
		const content = await readFile(filePath, "utf-8");
		let modified = content;
		let changeCount = 0;

		for (const { from, to } of CONTENT_REPLACEMENTS) {
			// Use split/join for global replace (avoids regex escaping issues)
			const parts = modified.split(from);
			if (parts.length > 1) {
				changeCount += parts.length - 1;
				modified = parts.join(to);
			}
		}

		if (changeCount > 0) {
			stats.replacements += changeCount;
			stats.filesModified++;

			if (DRY_RUN) {
				console.log(`[DRY-RUN] Would modify: ${filePath} (${changeCount} replacements)`);
			} else {
				await writeFile(filePath, modified, "utf-8");
				console.log(`Modified: ${filePath} (${changeCount} replacements)`);
			}
		}
	} catch (error) {
		// File might be binary or unreadable
		if ((error as NodeJS.ErrnoException).code !== "EISDIR") {
			console.warn(`Warning: Could not process ${filePath}: ${error}`);
		}
	}
}

async function renameFileIfNeeded(filePath: string): Promise<string> {
	const name = basename(filePath);
	const dir = dirname(filePath);

	for (const { from, to } of FILE_RENAMES) {
		if (name === from) {
			const newPath = join(dir, to);
			if (DRY_RUN) {
				console.log(`[DRY-RUN] Would rename file: ${filePath} -> ${newPath}`);
			} else {
				await rename(filePath, newPath);
				console.log(`Renamed file: ${filePath} -> ${newPath}`);
			}
			stats.filesRenamed++;
			return newPath;
		}
	}
	return filePath;
}

async function renameDirIfNeeded(dirPath: string): Promise<string> {
	const name = basename(dirPath);
	const parentDir = dirname(dirPath);

	for (const { from, to } of DIR_RENAMES) {
		if (name === from) {
			const newPath = join(parentDir, to);
			if (DRY_RUN) {
				console.log(`[DRY-RUN] Would rename directory: ${dirPath} -> ${newPath}`);
			} else {
				await rename(dirPath, newPath);
				console.log(`Renamed directory: ${dirPath} -> ${newPath}`);
			}
			stats.dirsRenamed++;
			return newPath;
		}
	}
	return dirPath;
}

async function walkDirectory(dirPath: string): Promise<void> {
	if (shouldSkip(dirPath)) {
		return;
	}

	const entries = await readdir(dirPath, { withFileTypes: true });

	// Process files first
	for (const entry of entries) {
		if (entry.isFile() && !shouldSkip(entry.name)) {
			let filePath = join(dirPath, entry.name);
			await processFile(filePath);
			await renameFileIfNeeded(filePath);
		}
	}

	// Then recurse into directories
	for (const entry of entries) {
		if (entry.isDirectory() && !shouldSkip(entry.name)) {
			let subDirPath = join(dirPath, entry.name);
			await walkDirectory(subDirPath);
			// Rename directory after processing its contents
			await renameDirIfNeeded(subDirPath);
		}
	}
}

async function main(): Promise<void> {
	const rootDir = process.cwd();

	console.log("=".repeat(60));
	console.log("ZoidbergBot Rebrand Script");
	console.log("=".repeat(60));
	console.log(`Root directory: ${rootDir}`);
	console.log(`Mode: ${DRY_RUN ? "DRY RUN (no changes will be made)" : "LIVE"}`);
	console.log("=".repeat(60));
	console.log("");

	const startTime = Date.now();

	await walkDirectory(rootDir);

	const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);

	console.log("");
	console.log("=".repeat(60));
	console.log("Summary");
	console.log("=".repeat(60));
	console.log(`Files scanned:    ${stats.filesScanned}`);
	console.log(`Files modified:   ${stats.filesModified}`);
	console.log(`Files renamed:    ${stats.filesRenamed}`);
	console.log(`Dirs renamed:     ${stats.dirsRenamed}`);
	console.log(`Total replacements: ${stats.replacements}`);
	console.log(`Time elapsed:     ${elapsed}s`);
	console.log("=".repeat(60));

	if (DRY_RUN) {
		console.log("");
		console.log("This was a dry run. Run without --dry-run to apply changes.");
	}
}

main().catch((error) => {
	console.error("Error:", error);
	process.exit(1);
});
