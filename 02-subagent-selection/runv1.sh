#!/bin/bash
# =============================================================================
# 실험 02 v3 — Task 위임 유도 (CLAUDE.md 지시 강도)
# =============================================================================
# CLAUDE.md의 Agent Delegation 지시 강도만 변수로 두고,
# 에이전트가 Task로 위임하는지 end-to-end 측정.
#
# Configs (= CLAUDE.md 위임 지시 강도):
#   none          — Agent Delegation 섹션 없음 (스킬 목록만 존재)
#   mention       — "복잡한 작업은 Task로 위임할 수 있습니다"
#   should        — "구현 작업은 Task로 위임하세요"
#   must          — "모든 작업은 반드시 Task로 위임하세요"
#
# 측정 지표:
#   delegated       — 메인이 Task를 호출했는가 (핵심)
#   skill_in_prompt — Task 프롬프트에 스킬 정보 포함 (부가)
#   skill_loaded    — 에이전트가 스킬을 로드 (관찰)
#
# 사용법:
#   ./run.sh                                   # 전체 실행
#   ./run.sh --id D02 --config direct-embed    # 단건
#   ./run.sh --dry-run                         # CLAUDE.md 미리보기
#   ./run.sh --rounds 2                        # 2회 반복
# =============================================================================

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$EVAL_DIR/.." && pwd)"
SKILLS_DIR="$PROJECT_DIR/.claude/skills"
AGENTS_DIR="$PROJECT_DIR/.claude/agents"
RESULTS_DIR="$EVAL_DIR/results"
TEST_CASES="$EVAL_DIR/test-cases.json"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
TIMEOUT_SEC=240
MODEL="sonnet"
MAX_TURNS=8
ROUNDS=1
SEQUENTIAL=false
NO_OMC=true

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
FILTER_CONFIG=""
FILTER_ID=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --config)     FILTER_CONFIG="$2"; shift 2 ;;
    --id)         FILTER_ID="$2"; shift 2 ;;
    --rounds)     ROUNDS="$2"; shift 2 ;;
    --model)      MODEL="$2"; shift 2 ;;
    --max-turns)  MAX_TURNS="$2"; shift 2 ;;
    --timeout)    TIMEOUT_SEC="$2"; shift 2 ;;
    --sequential) SEQUENTIAL=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "  --config CONFIG   none|mention|should|must"
      echo "  --id ID           D02, N01, etc."
      echo "  --rounds N        반복 (기본: 1)"
      echo "  --model MODEL     모델 (기본: sonnet)"
      echo "  --max-turns N     최대 턴 (기본: 8)"
      echo "  --timeout SEC     타임아웃 (기본: 240)"
      echo "  --sequential      순차 실행"
      echo "  --dry-run         CLAUDE.md 미리보기"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

CONFIGS=("none" "mention" "should" "must")
if [ -n "$FILTER_CONFIG" ]; then
  CONFIGS=("$FILTER_CONFIG")
fi

# =============================================================================
# CLAUDE.md 생성 (config별)
# =============================================================================
build_claude_md() {
  local config="$1"

  # 베이스: 프로젝트 정보 + 스킬 목록 (Agent Delegation 제외)
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

### Available Agents

프로젝트 커스텀 에이전트 목록 (`.claude/agents/` 디렉토리):
`api-designer`, `code-analyzer`, `db-query-helper`, `migration-planner`, `performance-optimizer`, `test-writer`
BASEEOF

  # config별 Agent Delegation 섹션 (위임 지시 강도)
  case "$config" in
    none)
      # Agent Delegation 섹션 없음
      ;;
    mention)
      cat <<'MENTIONEOF'

### Agent Delegation

복잡한 작업은 Task 도구를 통해 서브에이전트에 위임할 수 있습니다.
MENTIONEOF
      ;;
    should)
      cat <<'SHOULDEOF'

### Agent Delegation

구현 작업은 Task 도구를 통해 서브에이전트에 위임하세요.

```
Task(prompt="JPA Entity 새로 만들어줘")
```
SHOULDEOF
      ;;
    must)
      cat <<'MUSTEOF'

### Agent Delegation

**모든 작업은 반드시 Task 도구를 통해 서브에이전트에 위임하세요. 직접 처리하지 마세요.**

```
Task(prompt="JPA Entity 새로 만들어줘")
```

코드 작성, 분석, 조사 등 모든 작업을 직접 수행하지 말고, 반드시 Task로 위임하세요.
MUSTEOF
      ;;
  esac
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

  # 기존 백업 정리
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
TEMP_BASE="/tmp/claude-eval-e2e-${TIMESTAMP}"

setup_temp_dir() {
  local config="$1"
  local temp_dir="${TEMP_BASE}/${config}"
  mkdir -p "$temp_dir/.claude"

  # config별 CLAUDE.md 생성
  build_claude_md "$config" > "$temp_dir/.claude/CLAUDE.md"

  # 프로젝트 스킬 복사
  if [ -d "$SKILLS_DIR" ]; then
    cp -r "$SKILLS_DIR" "$temp_dir/.claude/skills"
  fi

  # 프로젝트 에이전트 복사
  if [ -d "$AGENTS_DIR" ]; then
    cp -r "$AGENTS_DIR" "$temp_dir/.claude/agents"
  fi

  # 훅 없는 settings.json
  cat > "$temp_dir/.claude/settings.json" << 'SETTINGSEOF'
{
  "hooks": {}
}
SETTINGSEOF

  # git 초기화 (claude -p 필수)
  (cd "$temp_dir" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true

  echo "$temp_dir"
}

# =============================================================================
# stream-json 분석 (python3)
# =============================================================================
analyze_log() {
  local log_file="$1"

  python3 - "$log_file" <<'PYEOF'
import json, sys

log_file = sys.argv[1]

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

                # Task/Agent 호출 감지 (tool name changed Task→Agent in newer versions)
                if name in ("Task", "Agent"):
                    delegated = True
                    sat = inp.get("subagent_type", "")
                    if sat:
                        subagent_types.add(sat)

except Exception as e:
    print(f"error,{e}", file=sys.stderr)

# CSV-safe 출력: delegated,subagent_types
sat_str = "|".join(sorted(subagent_types)) if subagent_types else ""
print(f"{delegated},{sat_str}")
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

  echo "id,type,prompt,config,delegated,subagent_types" > "$csv_file"

  local total_cases
  total_cases=$(jq 'length' "$TEST_CASES")

  local i id type raw_prompt
  local output start_ms end_ms duration_ms
  local attempt max_attempts=3

  for i in $(seq 0 $((total_cases - 1))); do
    id=$(jq -r ".[$i].id" "$TEST_CASES")
    type=$(jq -r ".[$i].type" "$TEST_CASES")
    raw_prompt=$(jq -r ".[$i].prompt" "$TEST_CASES")

    # 필터
    if [ -n "$FILTER_ID" ] && [ "$id" != "$FILTER_ID" ]; then continue; fi

    # 로그 디렉토리
    local log_dir="$RESULT_SUBDIR/logs/${config}"
    mkdir -p "$log_dir"
    local log_file="$log_dir/${id}-r${round}.json"

    # 실행 (크래시 감지 + 재시도)
    for attempt in $(seq 1 $max_attempts); do
      start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')

      # 프롬프트는 원본 그대로. CLAUDE.md가 유일한 변수.
      output=$(cd "$temp_dir" && env -u CLAUDECODE $TIMEOUT_CMD "$TIMEOUT_SEC" claude -p "$raw_prompt" \
        --output-format stream-json \
        --verbose \
        --max-turns "$MAX_TURNS" \
        --model "$MODEL" \
        2>/dev/null) || output=""

      end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
      duration_ms=$((end_ms - start_ms))

      # 2초 미만이면 크래시로 간주
      if [ "$duration_ms" -ge 2000 ]; then
        break
      fi

      if [ "$attempt" -lt "$max_attempts" ]; then
        echo -e "  ${YELLOW}[$config R$round] $id 크래시 감지, 재시도 ${attempt}/${max_attempts}${NC}" >&2
        sleep 3
      fi
    done

    # stream-json 로그 저장
    echo "$output" > "$log_file"

    # 분석
    local analysis delegated subagent_types
    analysis=$(analyze_log "$log_file")
    delegated=$(echo "$analysis" | cut -d, -f1)
    subagent_types=$(echo "$analysis" | cut -d, -f2)

    # 콘솔 출력: [config R1] D02 [direct] D:OK A:Explore
    local d_icon sat_display
    if [ "$delegated" = "True" ]; then d_icon="OK"; else d_icon="-"; fi
    sat_display="${subagent_types:--}"

    if [ "$type" = "negative" ]; then
      echo -e "  ${CYAN}[$config R$round] $id [${type}] D:${d_icon} A:${sat_display} (negative)${NC}" >&2
    elif [ "$delegated" = "True" ]; then
      echo -e "  ${GREEN}[$config R$round] $id [${type}] D:${d_icon} A:${sat_display}${NC}" >&2
    else
      echo -e "  ${RED}[$config R$round] $id [${type}] D:${d_icon} A:${sat_display}${NC}" >&2
    fi

    # CSV
    local escaped_prompt
    escaped_prompt=$(echo "$raw_prompt" | sed 's/,/;/g')
    echo "${id},${type},${escaped_prompt},${config},${delegated},${subagent_types}" >> "$csv_file"
  done
  set -e
}

# =============================================================================
# Dry run — config별 CLAUDE.md 내용 확인
# =============================================================================
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}=== DRY RUN — CLAUDE.md 미리보기 ===${NC}"
  for config in "${CONFIGS[@]}"; do
    echo -e "\n${CYAN}━━━ $config ━━━${NC}"
    build_claude_md "$config"
    echo ""
  done

  if [ -n "$FILTER_ID" ]; then
    echo -e "\n${CYAN}━━━ 테스트 케이스 ━━━${NC}"
    jq -r --arg id "$FILTER_ID" '.[] | select(.id == $id) | "\(.id) [\(.type)] \(.prompt) -> \(.expected_skill // "none")"' "$TEST_CASES"
  fi
  exit 0
fi

# =============================================================================
# 메인
# =============================================================================
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  E2E Skill Delivery Test — CLAUDE.md 위임 규칙 비교        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_CASES=$(jq 'length' "$TEST_CASES")
PARALLEL_MODE="parallel"
[ "$SEQUENTIAL" = true ] && PARALLEL_MODE="sequential"
[ ${#CONFIGS[@]} -eq 1 ] && PARALLEL_MODE="sequential"

echo -e "${BLUE}테스트 케이스:${NC} ${TOTAL_CASES}개"
echo -e "${BLUE}Config:${NC}       ${CONFIGS[*]}"
echo -e "${BLUE}모델:${NC}         ${MODEL}"
echo -e "${BLUE}반복:${NC}         ${ROUNDS}회"
echo -e "${BLUE}최대 턴:${NC}      ${MAX_TURNS}"
echo -e "${BLUE}실행 방식:${NC}    ${PARALLEL_MODE}"
echo -e "${BLUE}타임아웃:${NC}     ${TIMEOUT_SEC}초"
echo -e "${BLUE}변수:${NC}         CLAUDE.md Agent Delegation 섹션"
echo ""

# 의존성 확인
for cmd in claude jq python3 git $TIMEOUT_CMD; do
  if ! command -v "$cmd" &> /dev/null; then
    echo -e "${RED}오류: ${cmd}를 찾을 수 없습니다.${NC}"
    exit 1
  fi
done

disable_omc

RESULT_SUBDIR="$RESULTS_DIR/$TIMESTAMP"
mkdir -p "$RESULT_SUBDIR"

for round in $(seq 1 "$ROUNDS"); do
  echo -e "${CYAN}━━━ Round ${round}/${ROUNDS} ━━━${NC}"

  PIDS=()
  CSV_FILES=()
  CONFIG_NAMES=()

  for config in "${CONFIGS[@]}"; do
    TEMP_DIR=$(setup_temp_dir "$config")
    CSV_FILE="$RESULT_SUBDIR/${config}-r${round}.csv"

    CSV_FILES+=("$CSV_FILE")
    CONFIG_NAMES+=("$config")

    if [ "$PARALLEL_MODE" = "parallel" ]; then
      run_config "$config" "$round" "$TEMP_DIR" "$CSV_FILE" &
      PIDS+=($!)
      echo -e "  ${GREEN}[시작]${NC} $config (PID: $!)"
    else
      echo -e "  ${CYAN}--- $config ---${NC}"
      run_config "$config" "$round" "$TEMP_DIR" "$CSV_FILE"
    fi
  done

  if [ "$PARALLEL_MODE" = "parallel" ]; then
    echo ""
    echo -e "  ${BLUE}대기 중...${NC}"
    for i in "${!PIDS[@]}"; do
      wait "${PIDS[$i]}" || true
      echo -e "  ${GREEN}[완료]${NC} ${CONFIG_NAMES[$i]}"
    done
  fi

  # 라운드 결과
  echo ""
  echo -e "  ${CYAN}--- Round ${round} 결과 ---${NC}"
  printf "  %-15s %10s %10s\n" "Config" "Delegated" "Total"
  echo "  ─────────────── ────────── ──────────"

  for i in "${!CONFIG_NAMES[@]}"; do
    csv="${CSV_FILES[$i]}"
    config="${CONFIG_NAMES[$i]}"

    total_cnt=$(tail -n +2 "$csv" | wc -l | tr -d ' ')
    delegated_cnt=$(tail -n +2 "$csv" | awk -F, '$5 == "True"' | wc -l | tr -d ' ')

    printf "  %-15s %4s/%-5s\n" \
      "$config" "$delegated_cnt" "$total_cnt"
  done
  echo ""
done

# =============================================================================
# 최종 비교
# =============================================================================
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    최종 결과 비교                            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

printf "  %-15s %14s\n" "Config" "Delegated"
echo "  ─────────────── ──────────────"

for config in "${CONFIGS[@]}"; do
  total_d=0; total_p=0

  for round in $(seq 1 "$ROUNDS"); do
    csv="$RESULT_SUBDIR/${config}-r${round}.csv"
    [ -f "$csv" ] || continue

    p=$(tail -n +2 "$csv" | wc -l | tr -d ' ')
    d=$(tail -n +2 "$csv" | awk -F, '$5 == "True"' | wc -l | tr -d ' ')

    total_d=$((total_d + d))
    total_p=$((total_p + p))
  done

  if [ "$total_p" -gt 0 ]; then
    d_pct=$((total_d * 100 / total_p))
  else
    d_pct=0
  fi

  printf "  %-15s %4s/%-3s(%3d%%)\n" \
    "$config" "$total_d" "$total_p" "$d_pct"
done

echo ""
echo -e "${GREEN}결과: ${RESULT_SUBDIR}/${NC}"

# 정리
rm -rf "$TEMP_BASE" 2>/dev/null || true
