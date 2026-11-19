#!/bin/bash
set -f

# ── Per-model weekly limits (optional cache) ────────────
# Claude Code passes the statusline only the all-model windows. When an
# optional helper, ~/.claude/statusline-usage.sh, is installed, each redraw
# starts it in the background, and it keeps per-model weekly windows in
# usage.json below. Without it the statusline reads only its own input.
usage_helper="$HOME/.claude/statusline-usage.sh"
usage_cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline/usage.json"
usage_stale_after=1800

# GNU stat first: its -f prints filesystem details to stdout before failing.
file_mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ── Catppuccin Mocha ────────────────────────────────────
blue='\033[38;2;137;180;250m'
green='\033[38;2;166;227;161m'
teal='\033[38;2;148;226;213m'
peach='\033[38;2;250;179;135m'
yellow='\033[38;2;249;226;175m'
red='\033[38;2;243;139;168m'
mauve='\033[38;2;203;166;247m'
text='\033[38;2;205;214;244m'
subtext='\033[38;2;166;173;200m'
overlay='\033[38;2;108;112;134m'
dim='\033[2m'
reset='\033[0m'


# ── Helpers ─────────────────────────────────────────────
color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf "$red"
    elif [ "$pct" -ge 70 ]; then printf "$yellow"
    elif [ "$pct" -ge 50 ]; then printf "$peach"
    else printf "$green"
    fi
}

build_bar() {
    local pct=$1
    local width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100

    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color=$3
    [ -z "$bar_color" ] && bar_color=$(color_for_pct "$pct")

    local filled_str="" empty_str=""
    for ((i=0; i<filled; i++)); do filled_str+="●"; done
    for ((i=0; i<empty; i++)); do empty_str+="○"; done

    printf "${bar_color}${filled_str}${overlay}${empty_str}${reset}"
}

format_epoch_time() {
    local epoch=$1
    local style=$2
    [ -z "$epoch" ] || [ "$epoch" = "null" ] || [ "$epoch" = "0" ] && return

    local fmt="%l:%M%p"
    [ "$style" = "weekday" ] && fmt="%a %l:%M%p"
    local result
    result=$(date -j -r "$epoch" +"$fmt" 2>/dev/null)
    [ -z "$result" ] && result=$(date -d "@$epoch" +"$fmt" 2>/dev/null)
    printf "%s" "$result" | sed 's/  */ /g; s/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]'
}

iso_to_epoch() {
    local iso_str="$1"

    local epoch
    epoch=$(date -d "${iso_str}" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then
        echo "$epoch"
        return 0
    fi

    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"

    if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]] || [[ "$iso_str" == *"-00:00"* ]]; then
        epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
        [ -z "$epoch" ] && epoch=$(env TZ=UTC date -d "${stripped/T/ }" +%s 2>/dev/null)
    else
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
        [ -z "$epoch" ] && epoch=$(date -d "${stripped/T/ }" +%s 2>/dev/null)
    fi

    if [ -n "$epoch" ]; then
        echo "$epoch"
        return 0
    fi

    return 1
}

# ── Layout ──────────────────────────────────────────────
# A header line (model, effort, duration, cost, directory), then a table of
# meters: a dim label gutter, a 10-dot bar, a right-aligned value and a dim
# detail, with a spacer above the plan limits. Claude Code drops empty lines,
# so the spacer is a blank braille cell.
bar_width=10
dot="${overlay}·${reset}"
spacer=$'⠀'

fmt_tokens() {
    local n=$1
    if [ "$n" -ge 1000000 ]; then
        awk "BEGIN {printf \"%gM\", int($n / 100000) / 10}"
    elif [ "$n" -ge 1000 ]; then
        printf "%dk" $(( (n + 500) / 1000 ))
    else
        printf "%d" "$n"
    fi
}

# row LABEL BAR VALUE VALUE_COLOR [DETAIL]
row() {
    local value
    value=$(printf "%4s" "$3")
    printf "%s" "${subtext}$(printf "%-9s" "$1")${reset}$2  ${4}${value}${reset}"
    [ -n "$5" ] && printf "  %s" "$5"
}

rows=()
now_epoch=$(date +%s)

# ── Header ──────────────────────────────────────────────
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
effort=$(echo "$input" | jq -r '.effort.level // "default"')

cost=""
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$session_cost" ] && awk "BEGIN {exit !($session_cost > 0)}"; then
    cost=$(printf '$%.2f' "$session_cost")
fi

session_duration=""
elapsed=$(echo "$input" | jq -r '(.cost.total_duration_ms // 0) / 1000 | floor')
if [ "$elapsed" -ge 3600 ]; then
    session_duration="$(( elapsed / 3600 ))h$(( (elapsed % 3600) / 60 ))m"
elif [ "$elapsed" -ge 60 ]; then
    session_duration="$(( elapsed / 60 ))m"
elif [ "$elapsed" -gt 0 ]; then
    session_duration="${elapsed}s"
fi

cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
[ -z "$cwd" ] && cwd=$(pwd)
dirname=$(basename "$cwd")
git_branch=""
git_dirty=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
        git_dirty="*"
    fi
fi

header="${blue}${model_name}${reset}  "
case "$effort" in
    max)    header+="${red}● max${reset}" ;;
    xhigh)  header+="${peach}● xhigh${reset}" ;;
    high)   header+="${mauve}● high${reset}" ;;
    medium) header+="${subtext}◑ medium${reset}" ;;
    low)    header+="${overlay}◔ low${reset}" ;;
    *)      header+="${subtext}◑ default${reset}" ;;
esac
[ -n "$session_duration" ] && header+=" ${dot} ${text}${session_duration}${reset}"
[ -n "$cost" ] && header+=" ${dot} ${peach}${cost}${reset}"
header+=" ${dot} ${teal}${dirname}${reset}"
[ -n "$git_branch" ] && header+=" ${green}(${git_branch}${red}${git_dirty}${green})${reset}"

# ── Context ─────────────────────────────────────────────
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0 | floor')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
ctx_tokens=$(echo "$input" | jq -r '(.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)')
ctx_detail=""
if [ "$ctx_tokens" -gt 0 ] 2>/dev/null; then
    ctx_detail="${subtext}$(fmt_tokens "$ctx_tokens")"
    [ "$ctx_size" -gt 0 ] 2>/dev/null && ctx_detail+=" of $(fmt_tokens "$ctx_size")"
    ctx_detail+="${reset}"
fi
rows+=("$(row context "$(build_bar "$ctx_pct" "$bar_width")" "${ctx_pct}%" "$(color_for_pct "$ctx_pct")" "$ctx_detail")")

# ── Prompt cache ────────────────────────────────────────
# From prompt_cache, which appears after the main conversation's first API
# response; fields the running version lacks are skipped. Like every meter,
# the bar fills toward the bad end: it shows how much of the TTL has elapsed,
# full and red once cold. Warm: time left (yellow under 20%), hit ratio,
# misses. Cold: tokens the next message writes back to the cache. A miss cause
# sits with the miss count, since a cache also goes cold from idle time alone.
if echo "$input" | jq -e '.prompt_cache | type == "object"' >/dev/null 2>&1; then
    # One field per line, so an absent field stays an empty line.
    pc=()
    while IFS= read -r field; do pc+=("$field"); done < <(echo "$input" | jq -r '.prompt_cache
        | def s: if . == null then "" else tostring end;
          (.warm | s), (.caching_observed | s), (.ttl | s), (.expires_at | s),
          (if .hit_ratio == null then "" else (.hit_ratio * 100 | round | tostring) end),
          (.misses | s),
          ((.last_miss_cause.causes // []) | map(gsub("_"; " ")) | join(", ")),
          (.recache_tokens_if_cold | s)')
    pc_warm="${pc[0]}" pc_observed="${pc[1]}" pc_ttl="${pc[2]}" pc_expires="${pc[3]}"
    pc_hit="${pc[4]}" pc_misses="${pc[5]}" pc_cause="${pc[6]}" pc_recache="${pc[7]}"

    misses_part=""
    if [ -n "$pc_misses" ]; then
        if [ "$pc_misses" = "1" ]; then misses_part="1 miss"; else misses_part="${pc_misses} misses"; fi
        [ "$pc_misses" -gt 0 ] 2>/dev/null && [ -n "$pc_cause" ] && misses_part+=" (${pc_cause})"
    fi

    pc_left=""
    [ -n "$pc_expires" ] && pc_left=$(( pc_expires - now_epoch ))
    case "$pc_ttl" in
        5m) ttl_seconds=300 ;;
        1h) ttl_seconds=3600 ;;
        *)  ttl_seconds="" ;;
    esac
    empty_bar=$(build_bar 0 "$bar_width" "$overlay")

    if [ "$pc_observed" = "false" ]; then
        rows+=("$(row cache "$empty_bar" off "$overlay" "${subtext}no cache tokens reported${reset}")")
    elif [ "$pc_warm" != "false" ] && [ -n "$pc_left" ] && [ "$pc_left" -gt 0 ]; then
        cache_color="$green"
        cache_bar="$empty_bar"
        if [ -n "$ttl_seconds" ]; then
            elapsed_pct=$(( (ttl_seconds - pc_left) * 100 / ttl_seconds ))
            [ "$elapsed_pct" -lt 0 ] && elapsed_pct=0
            [ "$elapsed_pct" -gt 80 ] && cache_color="$yellow"
            cache_bar=$(build_bar "$elapsed_pct" "$bar_width" "$cache_color")
        fi
        if [ "$pc_left" -ge 60 ]; then left="$(( pc_left / 60 ))m"; else left="${pc_left}s"; fi
        detail=""
        [ -n "$pc_ttl" ] && detail="${subtext}of ${pc_ttl}${reset}"
        [ -n "$pc_hit" ] && detail+="${detail:+ ${dot} }${text}hit ${pc_hit}%${reset}"
        [ -n "$misses_part" ] && detail+="${detail:+ ${dot} }${text}${misses_part}${reset}"
        rows+=("$(row cache "$cache_bar" "$left" "$cache_color" "$detail")")
    else
        detail=""
        [ -n "$pc_recache" ] && detail="${text}next message re-caches $(fmt_tokens "$pc_recache")${reset}"
        [ "$pc_misses" -gt 0 ] 2>/dev/null && detail+="${detail:+ ${dot} }${text}${misses_part}${reset}"
        rows+=("$(row cache "$(build_bar 100 "$bar_width" "$red")" cold "$red" "$detail")")
    fi
fi

# ── Plan limits ─────────────────────────────────────────
# 5h and weekly windows come from stdin, present only while the plan has them
# and after the session's first API response. Per-model weekly windows come
# from the optional usage cache. Weekly rows that reset within two minutes of each
# other join one connector that ends on the last row with the shared reset
# time; otherwise each row has its own.
limits_start=${#rows[@]}
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | awk '{printf "%.0f", $1}')
five_hour_reset_epoch=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | awk '{printf "%.0f", $1}')
seven_day_reset_epoch=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$five_hour_pct" ]; then
    five_hour_reset=$(format_epoch_time "$five_hour_reset_epoch" "time")
    rows+=("$(row 5h "$(build_bar "$five_hour_pct" "$bar_width")" "${five_hour_pct}%" "$(color_for_pct "$five_hour_pct")" "${five_hour_reset:+${subtext}⟳ ${five_hour_reset}${reset}}")")
fi

weekly_labels=()
weekly_pcts=()
weekly_resets=()
if [ -n "$seven_day_pct" ]; then
    weekly_labels+=("weekly")
    weekly_pcts+=("$seven_day_pct")
    weekly_resets+=("$seven_day_reset_epoch")
fi

if [ -n "$five_hour_pct" ] || [ -n "$seven_day_pct" ]; then
    [ -x "$usage_helper" ] && nohup "$usage_helper" </dev/null >/dev/null 2>&1 &
    if [ -f "$usage_cache" ]; then
        cache_mtime=$(file_mtime "$usage_cache")
        stale=""
        [ -n "$cache_mtime" ] && [ $(( now_epoch - cache_mtime )) -gt "$usage_stale_after" ] && stale=" (stale)"
        while IFS=$'\t' read -r model_label model_pct model_reset_iso; do
            [ -n "$model_label" ] || continue
            model_reset_epoch=$(iso_to_epoch "$model_reset_iso")
            [ -n "$model_reset_epoch" ] && [ "$model_reset_epoch" -le "$now_epoch" ] && continue
            # The endpoint's reset times jitter by fractions of a second around the hour.
            [ -n "$model_reset_epoch" ] && model_reset_epoch=$(( (model_reset_epoch + 30) / 60 * 60 ))
            weekly_labels+=("${model_label}${stale}")
            weekly_pcts+=("$model_pct")
            weekly_resets+=("$model_reset_epoch")
        done < <(jq -r '.limits[]?
            | select(.kind == "weekly_scoped" and .scope.model.display_name != null and .scope.surface == null)
            | [(.scope.model.display_name | ascii_downcase), (.percent // 0 | floor), (.resets_at // "")]
            | @tsv' "$usage_cache" 2>/dev/null)
    fi
fi

weekly_count=${#weekly_labels[@]}
if [ "$weekly_count" -gt 0 ]; then
    shared_reset=""
    for epoch in "${weekly_resets[@]}"; do
        [ -n "$epoch" ] || continue
        if [ -z "$shared_reset" ]; then
            shared_reset="$epoch"
        else
            gap=$(( epoch - shared_reset ))
            [ "${gap#-}" -gt 120 ] && shared_reset="mixed" && break
        fi
    done

    for i in "${!weekly_labels[@]}"; do
        label="${weekly_labels[$i]}"
        pct="${weekly_pcts[$i]}"
        detail=""
        if [ "$shared_reset" = "mixed" ]; then
            [ -n "${weekly_resets[$i]}" ] && detail="${subtext}⟳ $(format_epoch_time "${weekly_resets[$i]}" "weekday")${reset}"
        elif [ -n "$shared_reset" ]; then
            reset_text="${subtext}⟳ $(format_epoch_time "$shared_reset" "weekday")${reset}"
            if [ "$weekly_count" -eq 1 ]; then
                detail="$reset_text"
            elif [ "$i" -eq 0 ]; then
                detail="${overlay}─┐${reset}"
            elif [ "$i" -lt $(( weekly_count - 1 )) ]; then
                detail="${overlay}─┤${reset}"
            else
                detail="${overlay}─┴${reset} ${reset_text}"
            fi
        fi
        # A stale marker rides on the label, so the label column keeps its width.
        stale_note=""
        case "$label" in *" (stale)") label="${label% (stale)}"; stale_note=" ${overlay}stale${reset}" ;; esac
        rows+=("$(row "$label" "$(build_bar "$pct" "$bar_width")" "${pct}%" "$(color_for_pct "$pct")" "${detail}${stale_note}")")
    done
fi

# ── Output ──────────────────────────────────────────────
printf "%b" "$header"
for i in "${!rows[@]}"; do
    [ "$i" -eq "$limits_start" ] && printf "\n%s" "$spacer"
    printf "\n%b" "${rows[$i]}"
done

exit 0
