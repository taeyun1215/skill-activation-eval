#!/bin/bash
# =============================================================================
# 실험 02 v5 — Step 0 요청 분류 추가
# =============================================================================
# v4 forced-eval(82%)의 실패 케이스만 대상으로 Step 0 추가 효과 측정
#
# Configs:
#   forced-eval    — v4 기존 (베이스라인)
#   forced-eval-v5 — Step 0 요청 분류 추가
#
# 사용법:
#   ./runv5.sh                          # 실패 케이스만 실행
#   ./runv5.sh --rounds 2               # 2회 반복
#   ./runv5.sh --all                    # 전체 20건 실행
#   ./runv5.sh --dry-run                # 훅 미리보기
# =============================================================================

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$EVAL_DIR/.." && pwd)"
SKILLS_DIR="$PROJECT_DIR/.claude/skills"
AGENTS_DIR="$PROJECT_DIR/.claude/agents"
HOOKS_DIR="$EVAL_DIR/hooks"
RESULTS_DIR="$EVAL_DIR/results"
TEST_CASES="$EVAL_DIR/test-cases.json"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
TIMEOUT_SEC=240
MODEL="sonnet"
MAX_TURNS=8
ROUNDS=1
NO_OMC=true

# v4 forced-eval 안정적 실패 케이스 + R2 추가 실패
FAIL_IDS="N03,N04,A02,A03"

# macOS 호환
if command -v gtimeout &> /dev/null; then
  TIMEOUT_CMD="gtimeout"
elif command -v timeout &> /dev/null; then
  TIMEOUT_CMD="timeout"
else
  echo "오류: timeout/gtimeout 필요. brew install coreutils" >&2
  exit 1
fi

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# 인자 파싱
# =============================================================================
DRY_RUN=false
RUN_ALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --rounds)     ROUNDS="$2"; shift 2 ;;
    --model)      MODEL="$2"; shift 2 ;;
    --max-turns)  MAX_TURNS="$2"; shift 2 ;;
    --timeout)    TIMEOUT_SEC="$2"; shift 2 ;;
    --all)        RUN_ALL=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "  --rounds N        반복 (기본: 1)"
      echo "  --all             전체 20건 실행"
      echo "  --dry-run         훅 미리보기"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

CONFIGS=("none")

# =============================================================================
# CLAUDE.md 생성 (v4와 동일)
# =============================================================================
build_claude_md() {
  cat <<'BASEEOF'
# Maum App Backend Mono

## Project Overview

Maum(마음)은 음성 통화 기반 소셜/데이팅 앱의 백엔드 시스템입니다.

- **언어**: Kotlin 1.8.22 / **프레임워크**: Spring Boot 3.1.4 / **Java**: 17
- **API**: GraphQL (클라이언트), gRPC (서비스 간)
- **DB**: MySQL 8.0.28, Redis, DynamoDB

## AI Guidelines

### Language
- 코드: Kotlin (영문 식별자)
- 주석/문서/커밋 메시지: 한국어 허용 (프로젝트 컨벤션)

### TDD (Red → Green → Refactor)
1. **Red**: 실패하는 테스트 먼저 작성 (JUnit5 + Mockito)
2. **Green**: 테스트를 통과하는 최소한의 코드
3. **Refactor**: 테스트 통과 상태에서 개선

### Available Skills

프로젝트 스킬 목록 (`.claude/skills/` 디렉토리):
`develop`, `entity-skill`, `graphql-skill`, `grpc-skill`, `gradle-skill`, `test-skill`, `plan-skill`, `adr-skill`

### Agent Delegation

**모든 작업은 반드시 Task 도구를 통해 서브에이전트에 위임하세요. 직접 처리하지 마세요.**

```
Task(prompt="JPA Entity 새로 만들어줘")
```

코드 작성, 분석, 조사 등 모든 작업을 직접 수행하지 말고, 반드시 Task로 위임하세요.

### Available Agents

프로젝트 커스텀 에이전트 목록 (`.claude/agents/` 디렉토리):
`api-designer`, `code-analyzer`, `db-query-helper`, `migration-planner`, `performance-optimizer`, `test-writer`
BASEEOF
}

# =============================================================================
# OMC 비활성화/복원
# =============================================================================
OMC_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
OMC_PLUGINS="$HOME/.claude/installed_plugins.json"
OMC_PLUGIN_CACHE="$HOME/.claude/plugin-cache"
OMC_PLUGIN_MARKET="$HOME/.claude/plugin-marketplace"

disable_omc() {
  if [ "$NO_OMC" != true ]; then return; fi
  for f in "$OMC_CLAUDE_MD.eval-backup" "$OMC_PLUGINS.eval-backup"; do
    [ -f "$f" ] && rm -f "$f"
  done
  for d in "${OMC_PLUGIN_CACHE}.eval-backup" "${OMC_PLUGIN_MARKET}.eval-backup"; do
    [ -d "$d" ] && rm -rf "$d"
  done
  if [ -f "$OMC_CLAUDE_MD" ]; then
    mv "$OMC_CLAUDE_MD" "$OMC_CLAUDE_MD.eval-backup"
    echo -e "${YELLOW}[OMC 비활성화]${NC} ~/.claude/CLAUDE.md 임시 제거"
  fi
  if [ -f "$OMC_PLUGINS" ]; then
    cp "$OMC_PLUGINS" "$OMC_PLUGINS.eval-backup"
    echo '[]' > "$OMC_PLUGINS"
    echo -e "${YELLOW}[OMC 비활성화]${NC} installed_plugins.json 클리어"
  fi
  if [ -d "$OMC_PLUGIN_CACHE" ]; then
    mv "$OMC_PLUGIN_CACHE" "${OMC_PLUGIN_CACHE}.eval-backup"
    echo -e "${YELLOW}[OMC 비활성화]${NC} 플러그인 캐시 임시 이동"
  fi
  if [ -d "$OMC_PLUGIN_MARKET" ]; then
    mv "$OMC_PLUGIN_MARKET" "${OMC_PLUGIN_MARKET}.eval-backup"
    echo -e "${YELLOW}[OMC 비활성화]${NC} 마켓플레이스 임시 이동"
  fi
}

restore_omc() {
  if [ "$NO_OMC" != true ]; then return; fi
  if [ -f "$OMC_CLAUDE_MD.eval-backup" ]; then
    mv "$OMC_CLAUDE_MD.eval-backup" "$OMC_CLAUDE_MD"
    echo -e "${GREEN}[OMC 복원]${NC} ~/.claude/CLAUDE.md 복원"
  fi
  if [ -f "$OMC_PLUGINS.eval-backup" ]; then
    mv "$OMC_PLUGINS.eval-backup" "$OMC_PLUGINS"
    echo -e "${GREEN}[OMC 복원]${NC} installed_plugins.json 복원"
  fi
  if [ -d "${OMC_PLUGIN_CACHE}.eval-backup" ]; then
    mv "${OMC_PLUGIN_CACHE}.eval-backup" "$OMC_PLUGIN_CACHE"
    echo -e "${GREEN}[OMC 복원]${NC} 플러그인 캐시 복원"
  fi
  if [ -d "${OMC_PLUGIN_MARKET}.eval-backup" ]; then
    mv "${OMC_PLUGIN_MARKET}.eval-backup" "$OMC_PLUGIN_MARKET"
    echo -e "${GREEN}[OMC 복원]${NC} 마켓플레이스 복원"
  fi
}
trap restore_omc EXIT

# =============================================================================
# Temp Dir
# =============================================================================
TEMP_BASE="/tmp/claude-eval-v5-${TIMESTAMP}"

setup_temp_dir() {
  local config="$1"
  local temp_dir="${TEMP_BASE}/${config}"
  mkdir -p "$temp_dir/.claude"

  build_claude_md > "$temp_dir/.claude/CLAUDE.md"

  if [ -d "$SKILLS_DIR" ]; then
    cp -r "$SKILLS_DIR" "$temp_dir/.claude/skills"
  fi
  if [ -d "$AGENTS_DIR" ]; then
    cp -r "$AGENTS_DIR" "$temp_dir/.claude/agents"
  fi

  mkdir -p "$temp_dir/hooks"
  cp "$HOOKS_DIR/"*.sh "$temp_dir/hooks/" 2>/dev/null || true

  # config별 훅 설정
  local hook_script
  case "$config" in
    forced-eval)    hook_script="hooks/forced-eval.sh" ;;
    forced-eval-v5) hook_script="hooks/forced-eval-v5.sh" ;;
    none)           hook_script="" ;;
  esac

  if [ -n "$hook_script" ]; then
    cat > "$temp_dir/.claude/settings.json" << SETTINGSEOF
{
  "hooks": {
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "bash ${hook_script}"}]}
    ]
  }
}
SETTINGSEOF
  else
    echo '{}' > "$temp_dir/.claude/settings.json"
  fi

  (cd "$temp_dir" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true
  echo "$temp_dir"
}

# =============================================================================
# stream-json 분석
# =============================================================================
analyze_log() {
  local log_file="$1"
  local expected_agents="$2"

  python3 - "$log_file" "$expected_agents" <<'PYEOF'
import json, sys

log_file = sys.argv[1]
expected_agents_str = sys.argv[2]
expected_set = set(a.strip() for a in expected_agents_str.split("|") if a.strip())

delegated = False
subagent_types = set()

try:
    with open(log_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            if obj.get("type") != "assistant":
                continue

            msg = obj.get("message", {})
            content = msg.get("content", [])
            if not isinstance(content, list):
                continue

            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") != "tool_use":
                    continue

                name = block.get("name", "")
                inp = block.get("input", {})

                if name in ("Task", "Agent"):
                    delegated = True
                    sat = inp.get("subagent_type", "")
                    if sat:
                        subagent_types.add(sat)

except Exception as e:
    print(f"error,{e}", file=sys.stderr)

sat_str = "|".join(sorted(subagent_types)) if subagent_types else ""
agent_match = bool(subagent_types & expected_set) if (subagent_types and expected_set) else False

print(f"{delegated},{sat_str},{agent_match}")
PYEOF
}

# =============================================================================
# 단일 config 실행
# =============================================================================
run_config() {
  set +e
  local config="$1"
  local round="$2"
  local temp_dir="$3"
  local csv_file="$4"

  echo "id,type,prompt,config,delegated,subagent_types,expected_agents,agent_match" > "$csv_file"

  local total_cases
  total_cases=$(jq 'length' "$TEST_CASES")

  for i in $(seq 0 $((total_cases - 1))); do
    local id type raw_prompt expected_agents
    id=$(jq -r ".[$i].id" "$TEST_CASES")
    type=$(jq -r ".[$i].type" "$TEST_CASES")
    raw_prompt=$(jq -r ".[$i].prompt" "$TEST_CASES")
    expected_agents=$(jq -r ".[$i].expected_agents | join(\"|\")" "$TEST_CASES")

    # 실패 케이스 필터 (--all이 아니면)
    if [ "$RUN_ALL" != true ]; then
      if ! echo "$FAIL_IDS" | grep -q "$id"; then
        continue
      fi
    fi

    local log_dir="$RESULT_SUBDIR/logs/${config}"
    mkdir -p "$log_dir"
    local log_file="$log_dir/${id}-r${round}.json"

    local attempt max_attempts=3
    local output start_ms end_ms duration_ms

    for attempt in $(seq 1 $max_attempts); do
      start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')

      output=$(cd "$temp_dir" && env -u CLAUDECODE $TIMEOUT_CMD "$TIMEOUT_SEC" claude -p "$raw_prompt" \
        --output-format stream-json \
        --verbose \
        --max-turns "$MAX_TURNS" \
        --model "$MODEL" \
        2>/dev/null) || output=""

      end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
      duration_ms=$((end_ms - start_ms))

      if [ "$duration_ms" -ge 2000 ]; then
        break
      fi

      if [ "$attempt" -lt "$max_attempts" ]; then
        echo -e "  ${YELLOW}[$config R$round] $id 크래시 감지, 재시도 ${attempt}/${max_attempts}${NC}" >&2
        sleep 3
      fi
    done

    echo "$output" > "$log_file"

    local analysis delegated subagent_types agent_match
    analysis=$(analyze_log "$log_file" "$expected_agents")
    delegated=$(echo "$analysis" | cut -d, -f1)
    subagent_types=$(echo "$analysis" | cut -d, -f2)
    agent_match=$(echo "$analysis" | cut -d, -f3)

    if [ "$delegated" = "True" ] && [ "$agent_match" = "True" ]; then
      echo -e "  ${GREEN}[$config R$round] $id [${type}] A:${subagent_types} M:OK${NC}" >&2
    elif [ "$delegated" = "True" ]; then
      echo -e "  ${YELLOW}[$config R$round] $id [${type}] A:${subagent_types} M:MISS${NC}" >&2
    else
      echo -e "  ${RED}[$config R$round] $id [${type}] D:- A:- M:-${NC}" >&2
    fi

    local escaped_prompt
    escaped_prompt=$(echo "$raw_prompt" | sed 's/,/;/g')
    echo "${id},${type},${escaped_prompt},${config},${delegated},${subagent_types},${expected_agents},${agent_match}" >> "$csv_file"
  done
  set -e
}

# =============================================================================
# Dry run
# =============================================================================
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}=== DRY RUN ===${NC}"

  for config in "${CONFIGS[@]}"; do
    echo -e "\n${CYAN}━━━ Hook: $config ━━━${NC}"
    TEMP_DIR=$(setup_temp_dir "$config")
    echo '{"cwd":"'"$TEMP_DIR"'"}' | bash "$TEMP_DIR/hooks/${config}.sh"
    echo ""
  done

  echo -e "${CYAN}━━━ 대상 케이스 ━━━${NC}"
  if [ "$RUN_ALL" = true ]; then
    echo "전체 $(jq 'length' "$TEST_CASES")건"
  else
    echo "실패 케이스: $FAIL_IDS"
    for fid in $(echo "$FAIL_IDS" | tr ',' ' '); do
      jq -r --arg id "$fid" '.[] | select(.id == $id) | "\(.id) [\(.type)] \(.prompt) -> expected: \(.expected_agents | join(", "))"' "$TEST_CASES"
    done
  fi

  rm -rf "$TEMP_BASE" 2>/dev/null || true
  exit 0
fi

# =============================================================================
# 메인
# =============================================================================
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  v5 — Step 0 요청 분류 추가 실험                            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$RUN_ALL" = true ]; then
  CASE_COUNT=$(jq 'length' "$TEST_CASES")
  echo -e "${BLUE}대상:${NC}         전체 ${CASE_COUNT}건"
else
  CASE_COUNT=$(echo "$FAIL_IDS" | tr ',' '\n' | wc -l | tr -d ' ')
  echo -e "${BLUE}대상:${NC}         실패 케이스 ${CASE_COUNT}건 ($FAIL_IDS)"
fi
echo -e "${BLUE}Config:${NC}       ${CONFIGS[*]}"
echo -e "${BLUE}모델:${NC}         ${MODEL}"
echo -e "${BLUE}반복:${NC}         ${ROUNDS}회"
echo -e "${BLUE}변경:${NC}         Step 0 요청 분류 추가"
echo ""

for cmd in claude jq python3 git $TIMEOUT_CMD; do
  if ! command -v "$cmd" &> /dev/null; then
    echo -e "${RED}오류: ${cmd}를 찾을 수 없습니다.${NC}"
    exit 1
  fi
done

disable_omc

RESULT_SUBDIR="$RESULTS_DIR/v5-$TIMESTAMP"
mkdir -p "$RESULT_SUBDIR"

for round in $(seq 1 "$ROUNDS"); do
  echo -e "${CYAN}━━━ Round ${round}/${ROUNDS} ━━━${NC}"

  for config in "${CONFIGS[@]}"; do
    TEMP_DIR=$(setup_temp_dir "$config")
    CSV_FILE="$RESULT_SUBDIR/${config}-r${round}.csv"

    echo -e "  ${CYAN}--- $config ---${NC}"
    run_config "$config" "$round" "$TEMP_DIR" "$CSV_FILE"

    # 라운드/config 결과
    total_cnt=$(tail -n +2 "$CSV_FILE" | wc -l | tr -d ' ')
    match_cnt=$(tail -n +2 "$CSV_FILE" | awk -F, '$8 == "True"' | wc -l | tr -d ' ')
    echo -e "  ${BLUE}결과: ${match_cnt}/${total_cnt}${NC}"
    echo ""
  done
done

# =============================================================================
# 최종 비교
# =============================================================================
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    v5 최종 결과 비교                         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

printf "  %-20s %14s %14s\n" "Config" "Delegated" "AgentMatch"
echo "  ──────────────────── ────────────── ──────────────"

for config in "${CONFIGS[@]}"; do
  total_d=0; total_m=0; total_p=0

  for round in $(seq 1 "$ROUNDS"); do
    csv="$RESULT_SUBDIR/${config}-r${round}.csv"
    [ -f "$csv" ] || continue

    p=$(tail -n +2 "$csv" | wc -l | tr -d ' ')
    d=$(tail -n +2 "$csv" | awk -F, '$5 == "True"' | wc -l | tr -d ' ')
    m=$(tail -n +2 "$csv" | awk -F, '$8 == "True"' | wc -l | tr -d ' ')

    total_d=$((total_d + d))
    total_m=$((total_m + m))
    total_p=$((total_p + p))
  done

  if [ "$total_p" -gt 0 ]; then
    d_pct=$((total_d * 100 / total_p))
    m_pct=$((total_m * 100 / total_p))
  else
    d_pct=0
    m_pct=0
  fi

  printf "  %-20s %4s/%-3s(%3d%%) %4s/%-3s(%3d%%)\n" \
    "$config" "$total_d" "$total_p" "$d_pct" "$total_m" "$total_p" "$m_pct"
done

echo ""

# 케이스별 비교
echo -e "  ${CYAN}케이스별 비교:${NC}"
printf "  %-6s %-10s %-20s %-20s\n" "ID" "Type" "forced-eval" "forced-eval-v5"
echo "  ────── ────────── ──────────────────── ────────────────────"

for round in $(seq 1 "$ROUNDS"); do
  csv1="$RESULT_SUBDIR/forced-eval-r${round}.csv"
  csv2="$RESULT_SUBDIR/forced-eval-v5-r${round}.csv"

  if [ -f "$csv1" ] && [ -f "$csv2" ]; then
    python3 - "$csv1" "$csv2" "$round" <<'PYEOF'
import csv, sys

csv1, csv2, rnd = sys.argv[1], sys.argv[2], sys.argv[3]

with open(csv1) as f:
    r1 = {r["id"]: r for r in csv.DictReader(f)}
with open(csv2) as f:
    r2 = {r["id"]: r for r in csv.DictReader(f)}

for cid in sorted(r1.keys()):
    if cid not in r2:
        continue
    row1, row2 = r1[cid], r2[cid]
    sat1 = row1.get("subagent_types", "-") or "-"
    sat2 = row2.get("subagent_types", "-") or "-"
    m1 = "OK" if row1["agent_match"] == "True" else "MISS"
    m2 = "OK" if row2["agent_match"] == "True" else "MISS"

    icon1 = "✓" if m1 == "OK" else "✗"
    icon2 = "✓" if m2 == "OK" else "✗"

    print(f"  {cid:<6} {row1['type']:<10} {icon1} {sat1:<17} {icon2} {sat2:<17}")
PYEOF
  fi
done

echo ""
echo -e "${GREEN}결과: ${RESULT_SUBDIR}/${NC}"

rm -rf "$TEMP_BASE" 2>/dev/null || true
