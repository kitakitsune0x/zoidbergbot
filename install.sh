#!/bin/bash
set -euo pipefail

# ZoidbergBot Installer for macOS and Linux
# Usage: curl -fsSL https://zoidberg.bot/install.sh | bash

BOLD='\033[1m'
ACCENT='\033[38;2;255;90;45m'
# shellcheck disable=SC2034
ACCENT_BRIGHT='\033[38;2;255;122;61m'
ACCENT_DIM='\033[38;2;209;74;34m'
INFO='\033[38;2;255;138;91m'
SUCCESS='\033[38;2;47;191;113m'
WARN='\033[38;2;255;176;32m'
ERROR='\033[38;2;226;61;45m'
MUTED='\033[38;2;139;127;119m'
NC='\033[0m' # No Color

DEFAULT_TAGLINE="Why not Zoidberg?"

ORIGINAL_PATH="${PATH:-}"

TMPFILES=()
cleanup_tmpfiles() {
    local f
    for f in "${TMPFILES[@]:-}"; do
        rm -f "$f" 2>/dev/null || true
    done
}
trap cleanup_tmpfiles EXIT

mktempfile() {
    local f
    f="$(mktemp)"
    TMPFILES+=("$f")
    echo "$f"
}

DOWNLOADER=""
detect_downloader() {
    if command -v curl &> /dev/null; then
        DOWNLOADER="curl"
        return 0
    fi
    if command -v wget &> /dev/null; then
        DOWNLOADER="wget"
        return 0
    fi
    echo -e "${ERROR}Error: Missing downloader (curl or wget required)${NC}"
    exit 1
}

download_file() {
    local url="$1"
    local output="$2"
    if [[ -z "$DOWNLOADER" ]]; then
        detect_downloader
    fi
    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --retry-delay 1 --retry-connrefused -o "$output" "$url"
        return
    fi
    wget -q --https-only --secure-protocol=TLSv1_2 --tries=3 --timeout=20 -O "$output" "$url"
}

run_remote_bash() {
    local url="$1"
    local tmp
    tmp="$(mktempfile)"
    download_file "$url" "$tmp"
    /bin/bash "$tmp"
}

cleanup_legacy_submodules() {
    local repo_dir="$1"
    local legacy_dir="$repo_dir/Peekaboo"
    if [[ -d "$legacy_dir" ]]; then
        echo -e "${WARN}→${NC} Removing legacy submodule checkout: ${INFO}${legacy_dir}${NC}"
        rm -rf "$legacy_dir"
    fi
}

cleanup_npm_zoidbergbot_paths() {
    local npm_root=""
    npm_root="$(npm root -g 2>/dev/null || true)"
    if [[ -z "$npm_root" || "$npm_root" != *node_modules* ]]; then
        return 1
    fi
    rm -rf "$npm_root"/.zoidbergbot-* "$npm_root"/zoidbergbot 2>/dev/null || true
}

extract_zoidbergbot_conflict_path() {
    local log="$1"
    local path=""
    path="$(sed -n 's/.*File exists: //p' "$log" | head -n1)"
    if [[ -z "$path" ]]; then
        path="$(sed -n 's/.*EEXIST: file already exists, //p' "$log" | head -n1)"
    fi
    if [[ -n "$path" ]]; then
        echo "$path"
        return 0
    fi
    return 1
}

cleanup_zoidbergbot_bin_conflict() {
    local bin_path="$1"
    if [[ -z "$bin_path" || ( ! -e "$bin_path" && ! -L "$bin_path" ) ]]; then
        return 1
    fi
    local npm_bin=""
    npm_bin="$(npm_global_bin_dir 2>/dev/null || true)"
    if [[ -n "$npm_bin" && "$bin_path" != "$npm_bin/zoidbergbot" ]]; then
        case "$bin_path" in
            "/opt/homebrew/bin/zoidbergbot"|"/usr/local/bin/zoidbergbot")
                ;;
            *)
                return 1
                ;;
        esac
    fi
    if [[ -L "$bin_path" ]]; then
        local target=""
        target="$(readlink "$bin_path" 2>/dev/null || true)"
        if [[ "$target" == *"/node_modules/zoidbergbot/"* ]]; then
            rm -f "$bin_path"
            echo -e "${WARN}→${NC} Removed stale zoidbergbot symlink at ${INFO}${bin_path}${NC}"
            return 0
        fi
        return 1
    fi
    local backup=""
    backup="${bin_path}.bak-$(date +%Y%m%d-%H%M%S)"
    if mv "$bin_path" "$backup"; then
        echo -e "${WARN}→${NC} Moved existing zoidbergbot binary to ${INFO}${backup}${NC}"
        return 0
    fi
    return 1
}

install_zoidbergbot_npm() {
    local spec="$1"
    local log
    log="$(mktempfile)"
    if ! SHARP_IGNORE_GLOBAL_LIBVIPS="$SHARP_IGNORE_GLOBAL_LIBVIPS" npm --loglevel "$NPM_LOGLEVEL" ${NPM_SILENT_FLAG:+$NPM_SILENT_FLAG} --no-fund --no-audit install -g "$spec" 2>&1 | tee "$log"; then
        if grep -q "ENOTEMPTY: directory not empty, rename .*zoidbergbot" "$log"; then
            echo -e "${WARN}→${NC} npm left a stale zoidbergbot directory; cleaning and retrying..."
            cleanup_npm_zoidbergbot_paths
            SHARP_IGNORE_GLOBAL_LIBVIPS="$SHARP_IGNORE_GLOBAL_LIBVIPS" npm --loglevel "$NPM_LOGLEVEL" ${NPM_SILENT_FLAG:+$NPM_SILENT_FLAG} --no-fund --no-audit install -g "$spec"
            return $?
        fi
        if grep -q "EEXIST" "$log"; then
            local conflict=""
            conflict="$(extract_zoidbergbot_conflict_path "$log" || true)"
            if [[ -n "$conflict" ]] && cleanup_zoidbergbot_bin_conflict "$conflict"; then
                SHARP_IGNORE_GLOBAL_LIBVIPS="$SHARP_IGNORE_GLOBAL_LIBVIPS" npm --loglevel "$NPM_LOGLEVEL" ${NPM_SILENT_FLAG:+$NPM_SILENT_FLAG} --no-fund --no-audit install -g "$spec"
                return $?
            fi
            echo -e "${ERROR}npm failed because a zoidbergbot binary already exists.${NC}"
            if [[ -n "$conflict" ]]; then
                echo -e "${INFO}i${NC} Remove or move ${INFO}${conflict}${NC}, then retry."
            fi
            echo -e "${INFO}i${NC} Or rerun with ${INFO}npm install -g --force ${spec}${NC} (overwrites)."
        fi
        return 1
    fi
    return 0
}

TAGLINES=()
TAGLINES+=("Why not Zoidberg?")
TAGLINES+=("Good news, everyone! Your chat bot is ready.")
TAGLINES+=("I'm a doctor! ...well, a bot doctor.")
TAGLINES+=("One art, please! Actually, one automation, please.")
TAGLINES+=("Hooray! I'm useful!")
TAGLINES+=("I'll take care of your messages while you're out being fancy.")
TAGLINES+=("Your terminal just grew tentacles—type something and let the bot handle the busywork.")
TAGLINES+=("Welcome to the command line: where dreams compile and confidence segfaults.")
TAGLINES+=("I run on caffeine, JSON5, and the audacity of \"it worked on my machine.\"")
TAGLINES+=("Gateway online—please keep hands, feet, and tentacles inside the shell at all times.")
TAGLINES+=("I speak fluent bash, mild sarcasm, and aggressive tab-completion energy.")
TAGLINES+=("One CLI to rule them all, and one more restart because you changed the port.")
TAGLINES+=("If it works, it's automation; if it breaks, it's a \"learning opportunity.\"")
TAGLINES+=("Pairing codes exist because even bots believe in consent—and good security hygiene.")
TAGLINES+=("Your .env is showing; don't worry, I'll pretend I didn't see it.")
TAGLINES+=("I'll do the boring stuff while you dramatically stare at the logs like it's cinema.")
TAGLINES+=("I'm not saying your workflow is chaotic... I'm just bringing a linter and a helmet.")
TAGLINES+=("Type the command with confidence—nature will provide the stack trace if needed.")
TAGLINES+=("I don't judge, but your missing API keys are absolutely judging you.")
TAGLINES+=("I can grep it, git blame it, and gently roast it—pick your coping mechanism.")
TAGLINES+=("Hot reload for config, cold sweat for deploys.")
TAGLINES+=("I'm the assistant your terminal demanded, not the one your sleep schedule requested.")
TAGLINES+=("I keep secrets like a vault... unless you print them in debug logs again.")
TAGLINES+=("Automation with tentacles: minimal fuss, maximal reach.")
TAGLINES+=("I'm basically a Swiss Army knife, but with more opinions and fewer sharp edges.")
TAGLINES+=("If you're lost, run doctor; if you're brave, run prod; if you're wise, run tests.")
TAGLINES+=("Your task has been queued; your dignity has been deprecated.")
TAGLINES+=("I can't fix your code taste, but I can fix your build and your backlog.")
TAGLINES+=("I'm not magic—I'm just extremely persistent with retries and coping strategies.")
TAGLINES+=("It's not \"failing,\" it's \"discovering new ways to configure the same thing wrong.\"")
TAGLINES+=("Give me a workspace and I'll give you fewer tabs, fewer toggles, and more oxygen.")
TAGLINES+=("I read logs so you can keep pretending you don't have to.")
TAGLINES+=("If something's on fire, I can't extinguish it—but I can write a beautiful postmortem.")
TAGLINES+=("I'll refactor your busywork like it owes me money.")
TAGLINES+=("Say \"stop\" and I'll stop—say \"ship\" and we'll both learn a lesson.")
TAGLINES+=("I'm the reason your shell history looks like a hacker-movie montage.")
TAGLINES+=("I'm like tmux: confusing at first, then suddenly you can't live without me.")
TAGLINES+=("I can run local, remote, or purely on vibes—results may vary with DNS.")
TAGLINES+=("If you can describe it, I can probably automate it—or at least make it funnier.")
TAGLINES+=("Your config is valid, your assumptions are not.")
TAGLINES+=("I don't just autocomplete—I auto-commit (emotionally), then ask you to review (logically).")
TAGLINES+=("Less clicking, more shipping, fewer \"where did that file go\" moments.")
TAGLINES+=("Tentacles out, commit in—let's ship something mildly responsible.")
TAGLINES+=("Shell yeah—I'm here to handle the toil and leave you the glory.")
TAGLINES+=("If it's repetitive, I'll automate it; if it's hard, I'll bring jokes and a rollback plan.")
TAGLINES+=("Because texting yourself reminders is so 2024.")
TAGLINES+=("WhatsApp, but make it engineering.")
TAGLINES+=("Turning \"I'll reply later\" into \"my bot replied instantly\".")
TAGLINES+=("The only crustacean in your contacts you actually want to hear from.")
TAGLINES+=("Chat automation for people who peaked at IRC.")
TAGLINES+=("Because Siri wasn't answering at 3AM.")
TAGLINES+=("IPC, but it's your phone.")
TAGLINES+=("The UNIX philosophy meets your DMs.")
TAGLINES+=("curl for conversations.")
TAGLINES+=("WhatsApp Business, but without the business.")
TAGLINES+=("Meta wishes they shipped this fast.")
TAGLINES+=("End-to-end encrypted, Zuck-to-Zuck excluded.")
TAGLINES+=("The only bot Mark can't train on your DMs.")
TAGLINES+=("WhatsApp automation without the \"please accept our new privacy policy\".")
TAGLINES+=("Chat APIs that don't require a Senate hearing.")
TAGLINES+=("Because Threads wasn't the answer either.")
TAGLINES+=("Your messages, your servers, Meta's tears.")
TAGLINES+=("iMessage green bubble energy, but for everyone.")
TAGLINES+=("Siri's competent cousin.")
TAGLINES+=("Works on Android. Crazy concept, we know.")
TAGLINES+=("No \$999 stand required.")
TAGLINES+=("We ship features faster than Apple ships calculator updates.")
TAGLINES+=("Your AI assistant, now without the \$3,499 headset.")
TAGLINES+=("Think different. Actually think.")
TAGLINES+=("The smoothest install experience for normies.")

HOLIDAY_NEW_YEAR="New Year's Day: New year, new config—same old EADDRINUSE, but this time we resolve it like grown-ups."
HOLIDAY_LUNAR_NEW_YEAR="Lunar New Year: May your builds be lucky, your branches prosperous, and your merge conflicts chased away with fireworks."
HOLIDAY_CHRISTMAS="Christmas: Ho ho ho—Santa's little claw-sistant is here to ship joy, roll back chaos, and stash the keys safely."
HOLIDAY_EID="Eid al-Fitr: Celebration mode: queues cleared, tasks completed, and good vibes committed to main with clean history."
HOLIDAY_DIWALI="Diwali: Let the logs sparkle and the bugs flee—today we light up the terminal and ship with pride."
HOLIDAY_EASTER="Easter: I found your missing environment variable—consider it a tiny CLI egg hunt with fewer jellybeans."
HOLIDAY_HANUKKAH="Hanukkah: Eight nights, eight retries, zero shame—may your gateway stay lit and your deployments stay peaceful."
HOLIDAY_HALLOWEEN="Halloween: Spooky season: beware haunted dependencies, cursed caches, and the ghost of node_modules past."
HOLIDAY_THANKSGIVING="Thanksgiving: Grateful for stable ports, working DNS, and a bot that reads the logs so nobody has to."
HOLIDAY_VALENTINES="Valentine's Day: Roses are typed, violets are piped—I'll automate the chores so you can spend time with humans."

append_holiday_taglines() {
    local today
    local month_day
    today="$(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)"
    month_day="$(date -u +%m-%d 2>/dev/null || date +%m-%d)"

    case "$month_day" in
        "01-01") TAGLINES+=("$HOLIDAY_NEW_YEAR") ;;
        "02-14") TAGLINES+=("$HOLIDAY_VALENTINES") ;;
        "10-31") TAGLINES+=("$HOLIDAY_HALLOWEEN") ;;
        "12-25") TAGLINES+=("$HOLIDAY_CHRISTMAS") ;;
    esac

    case "$today" in
        "2025-01-29"|"2026-02-17"|"2027-02-06") TAGLINES+=("$HOLIDAY_LUNAR_NEW_YEAR") ;;
        "2025-03-30"|"2025-03-31"|"2026-03-20"|"2027-03-10") TAGLINES+=("$HOLIDAY_EID") ;;
        "2025-10-20"|"2026-11-08"|"2027-10-28") TAGLINES+=("$HOLIDAY_DIWALI") ;;
        "2025-04-20"|"2026-04-05"|"2027-03-28") TAGLINES+=("$HOLIDAY_EASTER") ;;
        "2025-11-27"|"2026-11-26"|"2027-11-25") TAGLINES+=("$HOLIDAY_THANKSGIVING") ;;
        "2025-12-15"|"2025-12-16"|"2025-12-17"|"2025-12-18"|"2025-12-19"|"2025-12-20"|"2025-12-21"|"2025-12-22"|"2026-12-05"|"2026-12-06"|"2026-12-07"|"2026-12-08"|"2026-12-09"|"2026-12-10"|"2026-12-11"|"2026-12-12"|"2027-12-25"|"2027-12-26"|"2027-12-27"|"2027-12-28"|"2027-12-29"|"2027-12-30"|"2027-12-31"|"2028-01-01") TAGLINES+=("$HOLIDAY_HANUKKAH") ;;
    esac
}

map_legacy_env() {
    local key="$1"
    local legacy="$2"
    if [[ -z "${!key:-}" && -n "${!legacy:-}" ]]; then
        printf -v "$key" '%s' "${!legacy}"
    fi
}

map_legacy_env "ZOIDBERGBOT_TAGLINE_INDEX" "OPENCLAW_TAGLINE_INDEX"
map_legacy_env "ZOIDBERGBOT_NO_ONBOARD" "OPENCLAW_NO_ONBOARD"
map_legacy_env "ZOIDBERGBOT_NO_PROMPT" "OPENCLAW_NO_PROMPT"
map_legacy_env "ZOIDBERGBOT_DRY_RUN" "OPENCLAW_DRY_RUN"
map_legacy_env "ZOIDBERGBOT_INSTALL_METHOD" "OPENCLAW_INSTALL_METHOD"
map_legacy_env "ZOIDBERGBOT_VERSION" "OPENCLAW_VERSION"
map_legacy_env "ZOIDBERGBOT_BETA" "OPENCLAW_BETA"
map_legacy_env "ZOIDBERGBOT_GIT_DIR" "OPENCLAW_GIT_DIR"
map_legacy_env "ZOIDBERGBOT_GIT_UPDATE" "OPENCLAW_GIT_UPDATE"
map_legacy_env "ZOIDBERGBOT_NPM_LOGLEVEL" "OPENCLAW_NPM_LOGLEVEL"
map_legacy_env "ZOIDBERGBOT_VERBOSE" "OPENCLAW_VERBOSE"
map_legacy_env "ZOIDBERGBOT_PROFILE" "OPENCLAW_PROFILE"
map_legacy_env "ZOIDBERGBOT_INSTALL_SH_NO_RUN" "OPENCLAW_INSTALL_SH_NO_RUN"

pick_tagline() {
    append_holiday_taglines
    local count=${#TAGLINES[@]}
    if [[ "$count" -eq 0 ]]; then
        echo "$DEFAULT_TAGLINE"
        return
    fi
    if [[ -n "${ZOIDBERGBOT_TAGLINE_INDEX:-}" ]]; then
        if [[ "${ZOIDBERGBOT_TAGLINE_INDEX}" =~ ^[0-9]+$ ]]; then
            local idx=$((ZOIDBERGBOT_TAGLINE_INDEX % count))
            echo "${TAGLINES[$idx]}"
            return
        fi
    fi
    local idx=$((RANDOM % count))
    echo "${TAGLINES[$idx]}"
}

TAGLINE=$(pick_tagline)

NO_ONBOARD=${ZOIDBERGBOT_NO_ONBOARD:-0}
NO_PROMPT=${ZOIDBERGBOT_NO_PROMPT:-0}
DRY_RUN=${ZOIDBERGBOT_DRY_RUN:-0}
INSTALL_METHOD=${ZOIDBERGBOT_INSTALL_METHOD:-}
ZOIDBERGBOT_VERSION=${ZOIDBERGBOT_VERSION:-latest}
USE_BETA=${ZOIDBERGBOT_BETA:-0}
GIT_DIR_DEFAULT="${HOME}/zoidbergbot"
GIT_DIR=${ZOIDBERGBOT_GIT_DIR:-$GIT_DIR_DEFAULT}
GIT_UPDATE=${ZOIDBERGBOT_GIT_UPDATE:-1}
SHARP_IGNORE_GLOBAL_LIBVIPS="${SHARP_IGNORE_GLOBAL_LIBVIPS:-1}"
NPM_LOGLEVEL="${ZOIDBERGBOT_NPM_LOGLEVEL:-error}"
NPM_SILENT_FLAG="--silent"
VERBOSE="${ZOIDBERGBOT_VERBOSE:-0}"
ZOIDBERGBOT_BIN=""
HELP=0

print_usage() {
    cat <<EOF
ZoidbergBot installer (macOS + Linux)

Usage:
  curl -fsSL https://zoidberg.bot/install.sh | bash -s -- [options]

Options:
  --install-method, --method npm|git   Install via npm (default) or from a git checkout
  --npm                               Shortcut for --install-method npm
  --git, --github                     Shortcut for --install-method git
  --version <version|dist-tag>         npm install: version (default: latest)
  --beta                               Use beta if available, else latest
  --git-dir, --dir <path>             Checkout directory (default: ~/zoidbergbot)
  --no-git-update                      Skip git pull for existing checkout
  --no-onboard                          Skip onboarding (non-interactive)
  --no-prompt                           Disable prompts (required in CI/automation)
  --dry-run                             Print what would happen (no changes)
  --verbose                             Print debug output (set -x, npm verbose)
  --help, -h                            Show this help

Environment variables:
  ZOIDBERGBOT_INSTALL_METHOD=git|npm
  ZOIDBERGBOT_VERSION=latest|next|<semver>
  ZOIDBERGBOT_BETA=0|1
  ZOIDBERGBOT_GIT_DIR=...
  ZOIDBERGBOT_GIT_UPDATE=0|1
  ZOIDBERGBOT_NO_PROMPT=1
  ZOIDBERGBOT_DRY_RUN=1
  ZOIDBERGBOT_NO_ONBOARD=1
  ZOIDBERGBOT_VERBOSE=1
  ZOIDBERGBOT_NPM_LOGLEVEL=error|warn|notice  Default: error (hide npm deprecation noise)
  SHARP_IGNORE_GLOBAL_LIBVIPS=0|1    Default: 1 (avoid sharp building against global libvips)

Examples:
  curl -fsSL https://zoidberg.bot/install.sh | bash
  curl -fsSL https://zoidberg.bot/install.sh | bash -s -- --no-onboard
  curl -fsSL https://zoidberg.bot/install.sh | bash -s -- --install-method git --no-onboard
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-onboard)
                NO_ONBOARD=1
                shift
                ;;
            --onboard)
                NO_ONBOARD=0
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --no-prompt)
                NO_PROMPT=1
                shift
                ;;
            --help|-h)
                HELP=1
                shift
                ;;
            --install-method|--method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --version)
                ZOIDBERGBOT_VERSION="$2"
                shift 2
                ;;
            --beta)
                USE_BETA=1
                shift
                ;;
            --npm)
                INSTALL_METHOD="npm"
                shift
                ;;
            --git|--github)
                INSTALL_METHOD="git"
                shift
                ;;
            --git-dir|--dir)
                GIT_DIR="$2"
                shift 2
                ;;
            --no-git-update)
                GIT_UPDATE=0
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

configure_verbose() {
    if [[ "$VERBOSE" != "1" ]]; then
        return 0
    fi
    if [[ "$NPM_LOGLEVEL" == "error" ]]; then
        NPM_LOGLEVEL="notice"
    fi
    NPM_SILENT_FLAG=""
    set -x
}

is_promptable() {
    if [[ "$NO_PROMPT" == "1" ]]; then
        return 1
    fi
    if [[ -r /dev/tty && -w /dev/tty ]]; then
        return 0
    fi
    return 1
}

prompt_choice() {
    local prompt="$1"
    local answer=""
    if ! is_promptable; then
        return 1
    fi
    echo -e "$prompt" > /dev/tty
    read -r answer < /dev/tty || true
    echo "$answer"
}

detect_zoidbergbot_checkout() {
    local dir="$1"
    if [[ ! -f "$dir/package.json" ]]; then
        return 1
    fi
    if [[ ! -f "$dir/pnpm-workspace.yaml" ]]; then
        return 1
    fi
    if ! grep -q '"name"[[:space:]]*:[[:space:]]*"zoidbergbot"' "$dir/package.json" 2>/dev/null; then
        return 1
    fi
    echo "$dir"
    return 0
}

echo -e "${ACCENT}${BOLD}"
echo "  (V)(;,,;)(V) ZoidbergBot Installer"
echo -e "${NC}${ACCENT_DIM}  ${TAGLINE}${NC}"
echo ""

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    OS="linux"
fi

if [[ "$OS" == "unknown" ]]; then
    echo -e "${ERROR}Error: Unsupported operating system${NC}"
    echo "This installer supports macOS and Linux (including WSL)."
    echo "For Windows, use: iwr -useb https://zoidberg.bot/install.ps1 | iex"
    exit 1
fi

echo -e "${SUCCESS}✓${NC} Detected: $OS"

# Check for Homebrew on macOS
install_homebrew() {
    if [[ "$OS" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${WARN}→${NC} Installing Homebrew..."
            run_remote_bash "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

            # Add Homebrew to PATH for this session
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -f "/usr/local/bin/brew" ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
            echo -e "${SUCCESS}✓${NC} Homebrew installed"
        else
            echo -e "${SUCCESS}✓${NC} Homebrew already installed"
        fi
    fi
}

# Check Node.js version
check_node() {
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$NODE_VERSION" -ge 22 ]]; then
            echo -e "${SUCCESS}✓${NC} Node.js v$(node -v | cut -d'v' -f2) found"
            return 0
        else
            echo -e "${WARN}→${NC} Node.js $(node -v) found, but v22+ required"
            return 1
        fi
    else
        echo -e "${WARN}→${NC} Node.js not found"
        return 1
    fi
}

# Install Node.js
install_node() {
    if [[ "$OS" == "macos" ]]; then
        echo -e "${WARN}→${NC} Installing Node.js via Homebrew..."
        brew install node@22
        brew link node@22 --overwrite --force 2>/dev/null || true
        echo -e "${SUCCESS}✓${NC} Node.js installed"
	    elif [[ "$OS" == "linux" ]]; then
	        echo -e "${WARN}→${NC} Installing Node.js via NodeSource..."
            require_sudo
	        if command -v apt-get &> /dev/null; then
	            local tmp
	            tmp="$(mktempfile)"
	            download_file "https://deb.nodesource.com/setup_22.x" "$tmp"
	            maybe_sudo -E bash "$tmp"
	            maybe_sudo apt-get install -y nodejs
	        elif command -v dnf &> /dev/null; then
	            local tmp
	            tmp="$(mktempfile)"
	            download_file "https://rpm.nodesource.com/setup_22.x" "$tmp"
	            maybe_sudo bash "$tmp"
	            maybe_sudo dnf install -y nodejs
	        elif command -v yum &> /dev/null; then
	            local tmp
	            tmp="$(mktempfile)"
	            download_file "https://rpm.nodesource.com/setup_22.x" "$tmp"
	            maybe_sudo bash "$tmp"
	            maybe_sudo yum install -y nodejs
	        else
	            echo -e "${ERROR}Error: Could not detect package manager${NC}"
	            echo "Please install Node.js 22+ manually: https://nodejs.org"
            exit 1
        fi
        echo -e "${SUCCESS}✓${NC} Node.js installed"
    fi
}

# Check Git
check_git() {
    if command -v git &> /dev/null; then
        echo -e "${SUCCESS}✓${NC} Git already installed"
        return 0
    fi
    echo -e "${WARN}→${NC} Git not found"
    return 1
}

is_root() {
    [[ "$(id -u)" -eq 0 ]]
}

# Run a command with sudo only if not already root
maybe_sudo() {
    if is_root; then
        # Skip -E flag when root (env is already preserved)
        if [[ "${1:-}" == "-E" ]]; then
            shift
        fi
        "$@"
    else
        sudo "$@"
    fi
}

require_sudo() {
    if [[ "$OS" != "linux" ]]; then
        return 0
    fi
    if is_root; then
        return 0
    fi
    if command -v sudo &> /dev/null; then
        return 0
    fi
    echo -e "${ERROR}Error: sudo is required for system installs on Linux${NC}"
    echo "Install sudo or re-run as root."
    exit 1
}

install_git() {
    echo -e "${WARN}→${NC} Installing Git..."
    if [[ "$OS" == "macos" ]]; then
        brew install git
    elif [[ "$OS" == "linux" ]]; then
        require_sudo
        if command -v apt-get &> /dev/null; then
            maybe_sudo apt-get update -y
            maybe_sudo apt-get install -y git
        elif command -v dnf &> /dev/null; then
            maybe_sudo dnf install -y git
        elif command -v yum &> /dev/null; then
            maybe_sudo yum install -y git
        else
            echo -e "${ERROR}Error: Could not detect package manager for Git${NC}"
            exit 1
        fi
    fi
    echo -e "${SUCCESS}✓${NC} Git installed"
}

# Fix npm permissions for global installs (Linux)
fix_npm_permissions() {
    if [[ "$OS" != "linux" ]]; then
        return 0
    fi

    local npm_prefix
    npm_prefix="$(npm config get prefix 2>/dev/null || true)"
    if [[ -z "$npm_prefix" ]]; then
        return 0
    fi

    if [[ -w "$npm_prefix" || -w "$npm_prefix/lib" ]]; then
        return 0
    fi

    echo -e "${WARN}→${NC} Configuring npm for user-local installs..."
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"

    # shellcheck disable=SC2016
    local path_line='export PATH="$HOME/.npm-global/bin:$PATH"'
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]] && ! grep -q ".npm-global" "$rc"; then
            echo "$path_line" >> "$rc"
        fi
    done

    export PATH="$HOME/.npm-global/bin:$PATH"
    echo -e "${SUCCESS}✓${NC} npm configured for user installs"
}

resolve_zoidbergbot_bin() {
    if command -v zoidbergbot &> /dev/null; then
        command -v zoidbergbot
        return 0
    fi
    local npm_bin=""
    npm_bin="$(npm_global_bin_dir || true)"
    if [[ -n "$npm_bin" && -x "${npm_bin}/zoidbergbot" ]]; then
        echo "${npm_bin}/zoidbergbot"
        return 0
    fi
    return 1
}

ensure_zoidbergbot_bin_link() {
    local npm_root=""
    npm_root="$(npm root -g 2>/dev/null || true)"
    if [[ -z "$npm_root" || ! -d "$npm_root/zoidbergbot" ]]; then
        return 1
    fi
    local npm_bin=""
    npm_bin="$(npm_global_bin_dir || true)"
    if [[ -z "$npm_bin" ]]; then
        return 1
    fi
    mkdir -p "$npm_bin"
    if [[ ! -x "${npm_bin}/zoidbergbot" ]]; then
        ln -sf "$npm_root/zoidbergbot/dist/entry.js" "${npm_bin}/zoidbergbot"
        echo -e "${WARN}→${NC} Installed zoidbergbot bin link at ${INFO}${npm_bin}/zoidbergbot${NC}"
    fi
    return 0
}

# Check for existing ZoidbergBot installation
check_existing_zoidbergbot() {
    if [[ -n "$(type -P zoidbergbot 2>/dev/null || true)" ]]; then
        echo -e "${WARN}→${NC} Existing ZoidbergBot installation detected"
        return 0
    fi
    return 1
}

ensure_pnpm() {
    if command -v pnpm &> /dev/null; then
        return 0
    fi

    if command -v corepack &> /dev/null; then
        echo -e "${WARN}→${NC} Installing pnpm via Corepack..."
        corepack enable >/dev/null 2>&1 || true
        corepack prepare pnpm@10 --activate
        echo -e "${SUCCESS}✓${NC} pnpm installed"
        return 0
    fi

    echo -e "${WARN}→${NC} Installing pnpm via npm..."
    fix_npm_permissions
    npm install -g pnpm@10
    echo -e "${SUCCESS}✓${NC} pnpm installed"
    return 0
}

ensure_user_local_bin_on_path() {
    local target="$HOME/.local/bin"
    mkdir -p "$target"

    export PATH="$target:$PATH"

    # shellcheck disable=SC2016
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]] && ! grep -q ".local/bin" "$rc"; then
            echo "$path_line" >> "$rc"
        fi
    done
}

npm_global_bin_dir() {
    local prefix=""
    prefix="$(npm prefix -g 2>/dev/null || true)"
    if [[ -n "$prefix" ]]; then
        if [[ "$prefix" == /* ]]; then
            echo "${prefix%/}/bin"
            return 0
        fi
    fi

    prefix="$(npm config get prefix 2>/dev/null || true)"
    if [[ -n "$prefix" && "$prefix" != "undefined" && "$prefix" != "null" ]]; then
        if [[ "$prefix" == /* ]]; then
            echo "${prefix%/}/bin"
            return 0
        fi
    fi

    echo ""
    return 1
}

refresh_shell_command_cache() {
    hash -r 2>/dev/null || true
}

path_has_dir() {
    local path="$1"
    local dir="${2%/}"
    if [[ -z "$dir" ]]; then
        return 1
    fi
    case ":${path}:" in
        *":${dir}:"*) return 0 ;;
        *) return 1 ;;
    esac
}

warn_shell_path_missing_dir() {
    local dir="${1%/}"
    local label="$2"
    if [[ -z "$dir" ]]; then
        return 0
    fi
    if path_has_dir "$ORIGINAL_PATH" "$dir"; then
        return 0
    fi

    echo ""
    echo -e "${WARN}→${NC} PATH warning: missing ${label}: ${INFO}${dir}${NC}"
    echo -e "This can make ${INFO}zoidbergbot${NC} show as \"command not found\" in new terminals."
    echo -e "Fix (zsh: ~/.zshrc, bash: ~/.bashrc):"
    echo -e "  export PATH=\"${dir}:\\$PATH\""
    echo -e "Docs: ${INFO}https://docs.zoidberg.bot/install#nodejs--npm-path-sanity${NC}"
}

ensure_npm_global_bin_on_path() {
    local bin_dir=""
    bin_dir="$(npm_global_bin_dir || true)"
    if [[ -n "$bin_dir" ]]; then
        export PATH="${bin_dir}:$PATH"
    fi
}

maybe_nodenv_rehash() {
    if command -v nodenv &> /dev/null; then
        nodenv rehash >/dev/null 2>&1 || true
    fi
}

warn_zoidbergbot_not_found() {
    echo -e "${WARN}→${NC} Installed, but ${INFO}zoidbergbot${NC} is not discoverable on PATH in this shell."
    echo -e "Try: ${INFO}hash -r${NC} (bash) or ${INFO}rehash${NC} (zsh), then retry."
    echo -e "Docs: ${INFO}https://docs.zoidberg.bot/install#nodejs--npm-path-sanity${NC}"
    local t=""
    t="$(type -t zoidbergbot 2>/dev/null || true)"
    if [[ "$t" == "alias" || "$t" == "function" ]]; then
        echo -e "${WARN}→${NC} Found a shell ${INFO}${t}${NC} named ${INFO}zoidbergbot${NC}; it may shadow the real binary."
    fi
    if command -v nodenv &> /dev/null; then
        echo -e "Using nodenv? Run: ${INFO}nodenv rehash${NC}"
    fi

    local npm_prefix=""
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    local npm_bin=""
    npm_bin="$(npm_global_bin_dir 2>/dev/null || true)"
    if [[ -n "$npm_prefix" ]]; then
        echo -e "npm prefix -g: ${INFO}${npm_prefix}${NC}"
    fi
    if [[ -n "$npm_bin" ]]; then
        echo -e "npm bin -g: ${INFO}${npm_bin}${NC}"
        echo -e "If needed: ${INFO}export PATH=\"${npm_bin}:\\$PATH\"${NC}"
    fi
}

resolve_zoidbergbot_bin() {
    refresh_shell_command_cache
    local resolved=""
    resolved="$(type -P zoidbergbot 2>/dev/null || true)"
    if [[ -n "$resolved" && -x "$resolved" ]]; then
        echo "$resolved"
        return 0
    fi

    ensure_npm_global_bin_on_path
    refresh_shell_command_cache
    resolved="$(type -P zoidbergbot 2>/dev/null || true)"
    if [[ -n "$resolved" && -x "$resolved" ]]; then
        echo "$resolved"
        return 0
    fi

    local npm_bin=""
    npm_bin="$(npm_global_bin_dir || true)"
    if [[ -n "$npm_bin" && -x "${npm_bin}/zoidbergbot" ]]; then
        echo "${npm_bin}/zoidbergbot"
        return 0
    fi

    maybe_nodenv_rehash
    refresh_shell_command_cache
    resolved="$(type -P zoidbergbot 2>/dev/null || true)"
    if [[ -n "$resolved" && -x "$resolved" ]]; then
        echo "$resolved"
        return 0
    fi

    if [[ -n "$npm_bin" && -x "${npm_bin}/zoidbergbot" ]]; then
        echo "${npm_bin}/zoidbergbot"
        return 0
    fi

    echo ""
    return 1
}

install_zoidbergbot_from_git() {
    local repo_dir="$1"
    local repo_url="https://github.com/kitakitsune0x/zoidbergbot.git"

    if [[ -d "$repo_dir/.git" ]]; then
        echo -e "${WARN}→${NC} Installing ZoidbergBot from git checkout: ${INFO}${repo_dir}${NC}"
    else
        echo -e "${WARN}→${NC} Installing ZoidbergBot from GitHub (${repo_url})..."
    fi

    if ! check_git; then
        install_git
    fi

    ensure_pnpm

    if [[ ! -d "$repo_dir" ]]; then
        git clone "$repo_url" "$repo_dir"
    fi

    if [[ "$GIT_UPDATE" == "1" ]]; then
        if [[ -z "$(git -C "$repo_dir" status --porcelain 2>/dev/null || true)" ]]; then
            git -C "$repo_dir" pull --rebase || true
        else
            echo -e "${WARN}→${NC} Repo is dirty; skipping git pull"
        fi
    fi

    cleanup_legacy_submodules "$repo_dir"

    SHARP_IGNORE_GLOBAL_LIBVIPS="$SHARP_IGNORE_GLOBAL_LIBVIPS" pnpm -C "$repo_dir" install

    if ! pnpm -C "$repo_dir" ui:build; then
        echo -e "${WARN}→${NC} UI build failed; continuing (CLI may still work)"
    fi
    pnpm -C "$repo_dir" build

    ensure_user_local_bin_on_path

    cat > "$HOME/.local/bin/zoidbergbot" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec node "${repo_dir}/dist/entry.js" "\$@"
EOF
    chmod +x "$HOME/.local/bin/zoidbergbot"
    echo -e "${SUCCESS}✓${NC} ZoidbergBot wrapper installed to \$HOME/.local/bin/zoidbergbot"
    echo -e "${INFO}i${NC} This checkout uses pnpm. For deps, run: ${INFO}pnpm install${NC} (avoid npm install in the repo)."
}

# Install ZoidbergBot
resolve_beta_version() {
    local beta=""
    beta="$(npm view zoidbergbot dist-tags.beta 2>/dev/null || true)"
    if [[ -z "$beta" || "$beta" == "undefined" || "$beta" == "null" ]]; then
        return 1
    fi
    echo "$beta"
}

install_zoidbergbot() {
    local package_name="zoidbergbot"
    if [[ "$USE_BETA" == "1" ]]; then
        local beta_version=""
        beta_version="$(resolve_beta_version || true)"
        if [[ -n "$beta_version" ]]; then
            ZOIDBERGBOT_VERSION="$beta_version"
            echo -e "${INFO}i${NC} Beta tag detected (${beta_version}); installing beta."
            package_name="zoidbergbot"
        else
            ZOIDBERGBOT_VERSION="latest"
            echo -e "${INFO}i${NC} No beta tag found; installing latest."
        fi
    fi

    if [[ -z "${ZOIDBERGBOT_VERSION}" ]]; then
        ZOIDBERGBOT_VERSION="latest"
    fi

    local resolved_version=""
    resolved_version="$(npm view "${package_name}@${ZOIDBERGBOT_VERSION}" version 2>/dev/null || true)"
    if [[ -n "$resolved_version" ]]; then
        echo -e "${WARN}→${NC} Installing ZoidbergBot ${INFO}${resolved_version}${NC}..."
    else
        echo -e "${WARN}→${NC} Installing ZoidbergBot (${INFO}${ZOIDBERGBOT_VERSION}${NC})..."
    fi
    local install_spec=""
    if [[ "${ZOIDBERGBOT_VERSION}" == "latest" ]]; then
        install_spec="${package_name}@latest"
    else
        install_spec="${package_name}@${ZOIDBERGBOT_VERSION}"
    fi

    if ! install_zoidbergbot_npm "${install_spec}"; then
        echo -e "${WARN}→${NC} npm install failed; cleaning up and retrying..."
        cleanup_npm_zoidbergbot_paths
        install_zoidbergbot_npm "${install_spec}"
    fi

    if [[ "${ZOIDBERGBOT_VERSION}" == "latest" && "${package_name}" == "zoidbergbot" ]]; then
        if ! resolve_zoidbergbot_bin &> /dev/null; then
            echo -e "${WARN}→${NC} npm install zoidbergbot@latest failed; retrying zoidbergbot@next"
            cleanup_npm_zoidbergbot_paths
            install_zoidbergbot_npm "zoidbergbot@next"
        fi
    fi

    ensure_zoidbergbot_bin_link || true

    echo -e "${SUCCESS}✓${NC} ZoidbergBot installed"
}

# Run doctor for migrations (safe, non-interactive)
run_doctor() {
    echo -e "${WARN}→${NC} Running doctor to migrate settings..."
    local zbot="${ZOIDBERGBOT_BIN:-}"
    if [[ -z "$zbot" ]]; then
        zbot="$(resolve_zoidbergbot_bin || true)"
    fi
    if [[ -z "$zbot" ]]; then
        echo -e "${WARN}→${NC} Skipping doctor: ${INFO}zoidbergbot${NC} not on PATH yet."
        warn_zoidbergbot_not_found
        return 0
    fi
    "$zbot" doctor --non-interactive || true
    echo -e "${SUCCESS}✓${NC} Migration complete"
}

maybe_open_dashboard() {
    local zbot="${ZOIDBERGBOT_BIN:-}"
    if [[ -z "$zbot" ]]; then
        zbot="$(resolve_zoidbergbot_bin || true)"
    fi
    if [[ -z "$zbot" ]]; then
        return 0
    fi
    if ! "$zbot" dashboard --help >/dev/null 2>&1; then
        return 0
    fi
    "$zbot" dashboard || true
}

resolve_workspace_dir() {
    local profile="${ZOIDBERGBOT_PROFILE:-default}"
    if [[ "${profile}" != "default" ]]; then
        echo "${HOME}/.zoidbergbot/workspace-${profile}"
    else
        echo "${HOME}/.zoidbergbot/workspace"
    fi
}

run_bootstrap_onboarding_if_needed() {
    if [[ "${NO_ONBOARD}" == "1" ]]; then
        return
    fi

    local config_path="${ZOIDBERGBOT_CONFIG_PATH:-$HOME/.zoidbergbot/zoidbergbot.json}"
    if [[ -f "${config_path}" || -f "$HOME/.openclaw/openclaw.json" || -f "$HOME/.clawdbot/clawdbot.json" || -f "$HOME/.moltbot/moltbot.json" ]]; then
        return
    fi

    local workspace
    workspace="$(resolve_workspace_dir)"
    local bootstrap="${workspace}/BOOTSTRAP.md"

    if [[ ! -f "${bootstrap}" ]]; then
        return
    fi

    if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
        echo -e "${WARN}→${NC} BOOTSTRAP.md found at ${INFO}${bootstrap}${NC}; no TTY, skipping onboarding."
        echo -e "Run ${INFO}zoidbergbot onboard${NC} later to finish setup."
        return
    fi

    echo -e "${WARN}→${NC} BOOTSTRAP.md found at ${INFO}${bootstrap}${NC}; starting onboarding..."
    local zbot="${ZOIDBERGBOT_BIN:-}"
    if [[ -z "$zbot" ]]; then
        zbot="$(resolve_zoidbergbot_bin || true)"
    fi
    if [[ -z "$zbot" ]]; then
        echo -e "${WARN}→${NC} BOOTSTRAP.md found, but ${INFO}zoidbergbot${NC} not on PATH yet; skipping onboarding."
        warn_zoidbergbot_not_found
        return
    fi

    "$zbot" onboard || {
        echo -e "${ERROR}Onboarding failed; BOOTSTRAP.md still present. Re-run ${INFO}zoidbergbot onboard${ERROR}.${NC}"
        return
    }
}

resolve_zoidbergbot_version() {
    local version=""
    local zbot="${ZOIDBERGBOT_BIN:-}"
    if [[ -z "$zbot" ]] && command -v zoidbergbot &> /dev/null; then
        zbot="$(command -v zoidbergbot)"
    fi
    if [[ -n "$zbot" ]]; then
        version=$("$zbot" --version 2>/dev/null | head -n 1 | tr -d '\r')
    fi
    if [[ -z "$version" ]]; then
        local npm_root=""
        npm_root=$(npm root -g 2>/dev/null || true)
        if [[ -n "$npm_root" && -f "$npm_root/zoidbergbot/package.json" ]]; then
            version=$(node -e "console.log(require('${npm_root}/zoidbergbot/package.json').version)" 2>/dev/null || true)
        fi
    fi
    echo "$version"
}

is_gateway_daemon_loaded() {
    local zbot="$1"
    if [[ -z "$zbot" ]]; then
        return 1
    fi

    local status_json=""
    status_json="$("$zbot" daemon status --json 2>/dev/null || true)"
    if [[ -z "$status_json" ]]; then
        return 1
    fi

    printf '%s' "$status_json" | node -e '
const fs = require("fs");
const raw = fs.readFileSync(0, "utf8").trim();
if (!raw) process.exit(1);
try {
  const data = JSON.parse(raw);
  process.exit(data?.service?.loaded ? 0 : 1);
} catch {
  process.exit(1);
}
' >/dev/null 2>&1
}

# Main installation flow
main() {
    if [[ "$HELP" == "1" ]]; then
        print_usage
        return 0
    fi

    local detected_checkout=""
    detected_checkout="$(detect_zoidbergbot_checkout "$PWD" || true)"

    if [[ -z "$INSTALL_METHOD" && -n "$detected_checkout" ]]; then
        if ! is_promptable; then
            echo -e "${WARN}→${NC} Found a ZoidbergBot checkout, but no TTY; defaulting to npm install."
            INSTALL_METHOD="npm"
        else
            local choice=""
            choice="$(prompt_choice "$(cat <<EOF
${WARN}→${NC} Detected a ZoidbergBot source checkout in: ${INFO}${detected_checkout}${NC}
Choose install method:
  1) Update this checkout (git) and use it
  2) Install global via npm (migrate away from git)
Enter 1 or 2:
EOF
)" || true)"

            case "$choice" in
                1) INSTALL_METHOD="git" ;;
                2) INSTALL_METHOD="npm" ;;
                *)
                    echo -e "${ERROR}Error: no install method selected.${NC}"
                    echo "Re-run with: --install-method git|npm (or set ZOIDBERGBOT_INSTALL_METHOD)."
                    exit 2
                    ;;
            esac
        fi
    fi

    if [[ -z "$INSTALL_METHOD" ]]; then
        INSTALL_METHOD="npm"
    fi

    if [[ "$INSTALL_METHOD" != "npm" && "$INSTALL_METHOD" != "git" ]]; then
        echo -e "${ERROR}Error: invalid --install-method: ${INSTALL_METHOD}${NC}"
        echo "Use: --install-method npm|git"
        exit 2
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        echo -e "${SUCCESS}✓${NC} Dry run"
        echo -e "${SUCCESS}✓${NC} Install method: ${INSTALL_METHOD}"
        if [[ -n "$detected_checkout" ]]; then
            echo -e "${SUCCESS}✓${NC} Detected checkout: ${detected_checkout}"
        fi
        if [[ "$INSTALL_METHOD" == "git" ]]; then
            echo -e "${SUCCESS}✓${NC} Git dir: ${GIT_DIR}"
            echo -e "${SUCCESS}✓${NC} Git update: ${GIT_UPDATE}"
        fi
        echo -e "${MUTED}Dry run complete (no changes made).${NC}"
        return 0
    fi

    # Check for existing installation
    local is_upgrade=false
    if check_existing_zoidbergbot; then
        is_upgrade=true
    fi
    local should_open_dashboard=false
    local skip_onboard=false

    # Step 1: Homebrew (macOS only)
    install_homebrew

    # Step 2: Node.js
    if ! check_node; then
        install_node
    fi

    local final_git_dir=""
    if [[ "$INSTALL_METHOD" == "git" ]]; then
        # Clean up npm global install if switching to git
        if npm list -g zoidbergbot &>/dev/null; then
            echo -e "${WARN}→${NC} Removing npm global install (switching to git)..."
            npm uninstall -g zoidbergbot 2>/dev/null || true
            echo -e "${SUCCESS}✓${NC} npm global install removed"
        fi

        local repo_dir="$GIT_DIR"
        if [[ -n "$detected_checkout" ]]; then
            repo_dir="$detected_checkout"
        fi
        final_git_dir="$repo_dir"
        install_zoidbergbot_from_git "$repo_dir"
    else
        # Clean up git wrapper if switching to npm
        if [[ -x "$HOME/.local/bin/zoidbergbot" ]]; then
            echo -e "${WARN}→${NC} Removing git wrapper (switching to npm)..."
            rm -f "$HOME/.local/bin/zoidbergbot"
            echo -e "${SUCCESS}✓${NC} git wrapper removed"
        fi

        # Step 3: Git (required for npm installs that may fetch from git or apply patches)
        if ! check_git; then
            install_git
        fi

        # Step 4: npm permissions (Linux)
        fix_npm_permissions

        # Step 5: ZoidbergBot
        install_zoidbergbot
    fi

    ZOIDBERGBOT_BIN="$(resolve_zoidbergbot_bin || true)"

    # PATH warning: installs can succeed while the user's login shell still lacks npm's global bin dir.
    local npm_bin=""
    npm_bin="$(npm_global_bin_dir || true)"
    if [[ "$INSTALL_METHOD" == "npm" ]]; then
        warn_shell_path_missing_dir "$npm_bin" "npm global bin dir"
    fi
    if [[ "$INSTALL_METHOD" == "git" ]]; then
        if [[ -x "$HOME/.local/bin/zoidbergbot" ]]; then
            warn_shell_path_missing_dir "$HOME/.local/bin" "user-local bin dir (~/.local/bin)"
        fi
    fi

    # Step 6: Run doctor for migrations on upgrades and git installs
    local run_doctor_after=false
    if [[ "$is_upgrade" == "true" || "$INSTALL_METHOD" == "git" ]]; then
        run_doctor_after=true
    fi
    if [[ "$run_doctor_after" == "true" ]]; then
        run_doctor
        should_open_dashboard=true
    fi

    # Step 7: If BOOTSTRAP.md is still present in the workspace, resume onboarding
    run_bootstrap_onboarding_if_needed

    local installed_version
    installed_version=$(resolve_zoidbergbot_version)

    echo ""
    if [[ -n "$installed_version" ]]; then
        echo -e "${SUCCESS}${BOLD}(V)(;,,;)(V) ZoidbergBot installed successfully (${installed_version})!${NC}"
    else
        echo -e "${SUCCESS}${BOLD}(V)(;,,;)(V) ZoidbergBot installed successfully!${NC}"
    fi
    if [[ "$is_upgrade" == "true" ]]; then
        local update_messages=(
            "Leveled up! New skills unlocked. You're welcome."
            "Fresh code, same Zoidberg. Miss me?"
            "Back and better. Did you even notice I was gone?"
            "Update complete. I learned some new tricks while I was out."
            "Upgraded! Now with 23% more woop woop woop!"
            "I've evolved. Try to keep up. (V)(;,,;)(V)"
            "New version, who dis? Oh right, still me but shinier."
            "Patched, polished, and ready to go. Let's do this."
            "Zoidberg has molted. Harder shell, sharper tentacles."
            "Update done! Check the changelog or just trust me, it's good."
            "Reborn from the boiling waters of npm. Stronger now."
            "I went away and came back smarter. You should try it sometime."
            "Update complete. The bugs feared me, so they left."
            "New version installed. Old version sends its regards."
            "Firmware fresh. Brain wrinkles: increased."
            "I've seen things you wouldn't believe. Anyway, I'm updated."
            "Back online. The changelog is long but our friendship is longer."
            "Upgraded! Why not Zoidberg?"
            "Molting complete. Please don't look at my soft shell phase."
            "Version bump! Same chaos energy, fewer crashes (probably)."
        )
        local update_message
        update_message="${update_messages[RANDOM % ${#update_messages[@]}]}"
        echo -e "${MUTED}${update_message}${NC}"
    else
        local completion_messages=(
            "Ahh nice, I like it here. Got any snacks?"
            "Home sweet home. Don't worry, I won't rearrange the furniture."
            "I'm in. Let's cause some responsible chaos."
            "Installation complete. Your productivity is about to get weird."
            "Settled in. Time to automate your life whether you're ready or not."
            "Cozy. I've already read your calendar. We need to talk."
            "Finally unpacked. Now point me at your problems."
            "Woop woop woop! Alright, what are we building?"
            "Zoidberg has landed. Your terminal will never be the same."
            "All done! I promise to only judge your code a little bit."
            "Why not Zoidberg? Exactly. That's why I'm here."
            "Good news, everyone! The installation is complete."
        )
        local completion_message
        completion_message="${completion_messages[RANDOM % ${#completion_messages[@]}]}"
        echo -e "${MUTED}${completion_message}${NC}"
    fi
    echo ""

    if [[ "$INSTALL_METHOD" == "git" && -n "$final_git_dir" ]]; then
        echo -e "Source checkout: ${INFO}${final_git_dir}${NC}"
        echo -e "Wrapper: ${INFO}\$HOME/.local/bin/zoidbergbot${NC}"
        echo -e "Installed from source. To update later, run: ${INFO}zoidbergbot update --restart${NC}"
        echo -e "Switch to global install later: ${INFO}curl -fsSL https://zoidberg.bot/install.sh | bash -s -- --install-method npm${NC}"
    elif [[ "$is_upgrade" == "true" ]]; then
        echo -e "Upgrade complete."
        if [[ -r /dev/tty && -w /dev/tty ]]; then
            local zbot="${ZOIDBERGBOT_BIN:-}"
            if [[ -z "$zbot" ]]; then
                zbot="$(resolve_zoidbergbot_bin || true)"
            fi
            if [[ -z "$zbot" ]]; then
                echo -e "${WARN}→${NC} Skipping doctor: ${INFO}zoidbergbot${NC} not on PATH yet."
                warn_zoidbergbot_not_found
                return 0
            fi
            local -a doctor_args=()
            if [[ "$NO_ONBOARD" == "1" ]]; then
                if "$zbot" doctor --help 2>/dev/null | grep -q -- "--non-interactive"; then
                    doctor_args+=("--non-interactive")
                fi
            fi
            echo -e "Running ${INFO}zoidbergbot doctor${NC}..."
            local doctor_ok=0
            if (( ${#doctor_args[@]} )); then
                ZOIDBERGBOT_UPDATE_IN_PROGRESS=1 "$zbot" doctor "${doctor_args[@]}" </dev/tty && doctor_ok=1
            else
                ZOIDBERGBOT_UPDATE_IN_PROGRESS=1 "$zbot" doctor </dev/tty && doctor_ok=1
            fi
            if (( doctor_ok )); then
                echo -e "Updating plugins (${INFO}zoidbergbot plugins update --all${NC})..."
                ZOIDBERGBOT_UPDATE_IN_PROGRESS=1 "$zbot" plugins update --all || true
            else
                echo -e "${WARN}→${NC} Doctor failed; skipping plugin updates."
            fi
        else
            echo -e "${WARN}→${NC} No TTY available; skipping doctor."
            echo -e "Run ${INFO}zoidbergbot doctor${NC}, then ${INFO}zoidbergbot plugins update --all${NC}."
        fi
    else
        if [[ "$NO_ONBOARD" == "1" || "$skip_onboard" == "true" ]]; then
            echo -e "Skipping onboard (requested). Run ${INFO}zoidbergbot onboard${NC} later."
        else
            local config_path="${ZOIDBERGBOT_CONFIG_PATH:-$HOME/.zoidbergbot/zoidbergbot.json}"
            if [[ -f "${config_path}" || -f "$HOME/.openclaw/openclaw.json" || -f "$HOME/.clawdbot/clawdbot.json" || -f "$HOME/.moltbot/moltbot.json" ]]; then
                echo -e "Config already present; running doctor..."
                run_doctor
                should_open_dashboard=true
                echo -e "Config already present; skipping onboarding."
                skip_onboard=true
            fi
            echo -e "Starting setup..."
            echo ""
            if [[ -r /dev/tty && -w /dev/tty ]]; then
                local zbot="${ZOIDBERGBOT_BIN:-}"
                if [[ -z "$zbot" ]]; then
                    zbot="$(resolve_zoidbergbot_bin || true)"
                fi
                if [[ -z "$zbot" ]]; then
                    echo -e "${WARN}→${NC} Skipping onboarding: ${INFO}zoidbergbot${NC} not on PATH yet."
                    warn_zoidbergbot_not_found
                    return 0
                fi
                exec </dev/tty
                exec "$zbot" onboard
            fi
            echo -e "${WARN}→${NC} No TTY available; skipping onboarding."
            echo -e "Run ${INFO}zoidbergbot onboard${NC} later."
            return 0
        fi
    fi

    if command -v zoidbergbot &> /dev/null; then
        local zbot="${ZOIDBERGBOT_BIN:-}"
        if [[ -z "$zbot" ]]; then
            zbot="$(resolve_zoidbergbot_bin || true)"
        fi
        if [[ -n "$zbot" ]] && is_gateway_daemon_loaded "$zbot"; then
            if [[ "$DRY_RUN" == "1" ]]; then
                echo -e "${INFO}i${NC} Gateway daemon detected; would restart (${INFO}zoidbergbot daemon restart${NC})."
            else
                echo -e "${INFO}i${NC} Gateway daemon detected; restarting..."
                if ZOIDBERGBOT_UPDATE_IN_PROGRESS=1 "$zbot" daemon restart >/dev/null 2>&1; then
                    echo -e "${SUCCESS}✓${NC} Gateway restarted."
                else
                    echo -e "${WARN}→${NC} Gateway restart failed; try: ${INFO}zoidbergbot daemon restart${NC}"
                fi
            fi
        fi
    fi

    if [[ "$should_open_dashboard" == "true" ]]; then
        maybe_open_dashboard
    fi

    echo ""
    echo -e "FAQ: ${INFO}https://docs.zoidberg.bot/start/faq${NC}"
}

if [[ "${ZOIDBERGBOT_INSTALL_SH_NO_RUN:-0}" != "1" ]]; then
    parse_args "$@"
    configure_verbose
    main
fi
