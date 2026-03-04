#!/bin/bash
# =============================================================================
# Skill Activation Eval Runner (Isolated + Parallel)
# =============================================================================
# config별 temp dir 격리 + 모델 고정 + 병렬 실행
#
# 사용법:
#   ./run.sh                       # 전체 (4 configs 병렬 x 20 cases x 2 rounds)
#   ./run.sh --config forced-eval  # 특정 구성만
#   ./run.sh --type direct         # 특정 유형만
#   ./run.sh --id D01              # 특정 케이스만
#   ./run.sh --rounds 1            # 1회만
#   ./run.sh                       # OMC 기본 비활성화 (순수 Claude 동작만 측정)
#   ./run.sh --sequential          # 순차 실행 (디버깅용)
#   ./run.sh --dry-run             # 테스트 목록만 출력
# =============================================================================

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$EVAL_DIR/../.." && pwd)"
RESULTS_DIR="$EVAL_DIR/results"
TEST_CASES="$EVAL_DIR/test-cases.json"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
TIMEOUT_SEC=30
MODEL="sonnet"
ROUNDS=2
SEQUENTIAL=false
NO_OMC=true

# macOS 호환: timeout → gtimeout
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
FILTER_TYPE=""
FILTER_ID=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --config)     FILTER_CONFIG="$2"; shift 2 ;;
    --type)       FILTER_TYPE="$2"; shift 2 ;;
    --id)         FILTER_ID="$2"; shift 2 ;;
    --rounds)     ROUNDS="$2"; shift 2 ;;
    --model)      MODEL="$2"; shift 2 ;;
    --sequential) SEQUENTIAL=true; shift ;;
    --no-omc)     NO_OMC=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "  --config CONFIG   none|current|simple|forced-eval|llm-eval"
      echo "  --type TYPE       direct|natural|ambiguous|negative"
      echo "  --id ID           D01, N01, A01, X01 etc."
      echo "  --rounds N        반복 횟수 (기본: 2)"
      echo "  --model MODEL     사용 모델 (기본: sonnet)"
      echo "  --no-omc          OMC 비활성화 (기본: ON)"
      echo "  --sequential      순차 실행 (기본: 병렬)"
      echo "  --dry-run         실행 없이 테스트 목록만 출력"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

CONFIGS=("none" "simple" "forced-eval" "llm-eval")
if [ -n "$FILTER_CONFIG" ]; then
  CONFIGS=("$FILTER_CONFIG")
fi

# =============================================================================
# Temp Dir 격리
# =============================================================================
TEMP_BASE="/tmp/claude-eval-${TIMESTAMP}"

setup_temp_dir() {
  local config="$1"
  local temp_dir="${TEMP_BASE}/${config}"
  mkdir -p "$temp_dir"

  git init "$temp_dir" --quiet
  cp -r "$PROJECT_DIR/.claude" "$temp_dir/.claude"
  rm -f "$temp_dir/.claude/settings.local.json"

  # --no-omc: temp dir에서 OMC/범용 스킬 제거
  if [ "$NO_OMC" = true ]; then
    rm -rf "$temp_dir/.claude/commands"
  fi

  local settings="$temp_dir/.claude/settings.json"
  local base_settings="$PROJECT_DIR/.claude/settings.json"

  # base_settings에서 enabledPlugins와 hooks를 제거한 클린 버전 생성
  local clean_base
  if [ "$NO_OMC" = true ]; then
    clean_base=$(jq 'del(.enabledPlugins)' "$base_settings")
  else
    clean_base=$(cat "$base_settings")
  fi

  case "$config" in
    none)
      echo "$clean_base" | jq '.hooks = {}' > "$settings"
      ;;
    current)
      echo "$clean_base" > "$settings"
      ;;
    simple)
      echo "$clean_base" | jq '.hooks = {
        "UserPromptSubmit": [
          {"hooks": [{"type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/eval/hooks/simple.sh"}]}
        ]
      }' > "$settings"
      ;;
    forced-eval)
      echo "$clean_base" | jq '.hooks = {
        "UserPromptSubmit": [
          {"hooks": [{"type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/eval/hooks/forced-eval.sh"}]}
        ]
      }' > "$settings"
      ;;
    llm-eval)
      echo "$clean_base" | jq '.hooks = {
        "UserPromptSubmit": [
          {"hooks": [{"type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/eval/hooks/llm-eval.sh"}]}
        ]
      }' > "$settings"
      ;;
  esac

  echo "$temp_dir"
}

cleanup_temp_dirs() {
  [ -d "$TEMP_BASE" ] && rm -rf "$TEMP_BASE"
}

# =============================================================================
# OMC 비활성화 (--no-omc)
# =============================================================================
GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
GLOBAL_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
OMC_PLUGIN_CACHE="$HOME/.claude/plugins/cache/omc"
OMC_PLUGIN_MARKET="$HOME/.claude/plugins/marketplaces/omc"
OMC_BACKED_UP=false

disable_omc() {
  if [ "$NO_OMC" != true ]; then return; fi

  if [ -f "$GLOBAL_CLAUDE_MD" ]; then
    cp "$GLOBAL_CLAUDE_MD" "${GLOBAL_CLAUDE_MD}.eval-backup"
    rm "$GLOBAL_CLAUDE_MD"
    echo -e "${YELLOW}[OMC 비활성화]${NC} ~/.claude/CLAUDE.md 임시 제거"
  fi

  if [ -f "$GLOBAL_PLUGINS" ]; then
    cp "$GLOBAL_PLUGINS" "${GLOBAL_PLUGINS}.eval-backup"
    jq '.plugins = {}' "$GLOBAL_PLUGINS" > "${GLOBAL_PLUGINS}.tmp"
    mv "${GLOBAL_PLUGINS}.tmp" "$GLOBAL_PLUGINS"
    echo -e "${YELLOW}[OMC 비활성화]${NC} installed_plugins.json 클리어"
  fi

  # 기존 백업 정리 (재귀 중첩 방지)
  rm -rf "${OMC_PLUGIN_CACHE}.eval-backup"
  rm -rf "${OMC_PLUGIN_MARKET}.eval-backup"

  if [ -d "$OMC_PLUGIN_CACHE" ]; then
    mv "$OMC_PLUGIN_CACHE" "${OMC_PLUGIN_CACHE}.eval-backup"
    echo -e "${YELLOW}[OMC 비활성화]${NC} 플러그인 캐시 임시 이동"
  fi
  if [ -d "$OMC_PLUGIN_MARKET" ]; then
    mv "$OMC_PLUGIN_MARKET" "${OMC_PLUGIN_MARKET}.eval-backup"
    echo -e "${YELLOW}[OMC 비활성화]${NC} 마켓플레이스 임시 이동"
  fi

  OMC_BACKED_UP=true
}

restore_omc() {
  if [ "$OMC_BACKED_UP" != true ]; then return; fi

  if [ -f "${GLOBAL_CLAUDE_MD}.eval-backup" ]; then
    mv "${GLOBAL_CLAUDE_MD}.eval-backup" "$GLOBAL_CLAUDE_MD"
    echo -e "${GREEN}[OMC 복원]${NC} ~/.claude/CLAUDE.md 복원"
  fi

  if [ -f "${GLOBAL_PLUGINS}.eval-backup" ]; then
    mv "${GLOBAL_PLUGINS}.eval-backup" "$GLOBAL_PLUGINS"
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

# =============================================================================
# 단일 config 실행 (병렬 단위)
# =============================================================================
run_config() {
  local config="$1"
  local round="$2"
  local temp_dir="$3"
  local csv_file="$4"
  local log_file="$5"

  echo "id,type,prompt,expected,activated,activated_skill,result" > "$csv_file"

  local total_cases
  total_cases=$(jq 'length' "$TEST_CASES")

  for i in $(seq 0 $((total_cases - 1))); do
    local id type prompt expected_json
    id=$(jq -r ".[$i].id" "$TEST_CASES")
    type=$(jq -r ".[$i].type" "$TEST_CASES")
    prompt=$(jq -r ".[$i].prompt" "$TEST_CASES")
    expected_json=$(jq -c ".[$i].expected" "$TEST_CASES")

    # 필터
    if [ -n "$FILTER_TYPE" ] && [ "$type" != "$FILTER_TYPE" ]; then continue; fi
    if [ -n "$FILTER_ID" ] && [ "$id" != "$FILTER_ID" ]; then continue; fi

    # 실행
    local output activated activated_skill
    output=$(cd "$temp_dir" && env -u CLAUDECODE $TIMEOUT_CMD "$TIMEOUT_SEC" claude -p "$prompt" \
      --output-format stream-json \
      --verbose \
      --max-turns 1 \
      --model "$MODEL" \
      --allowedTools "Skill" \
      2>/dev/null) || true

    # Skill 호출 감지 (전체)
    activated="false"
    activated_skill=""

    if echo "$output" | grep -q '"name":"Skill"'; then
      activated="true"
      activated_skill=$(echo "$output" \
        | grep -o '"skill":"[^"]*"' \
        | sed 's/"skill":"//;s/"//' \
        | sort -u \
        | paste -sd '|' -)
    fi

    # 판정 (다중 스킬 지원)
    local match
    if [ -z "$activated_skill" ]; then
      local count
      count=$(echo "$expected_json" | jq 'length')
      [ "$count" -eq 0 ] && match="correct" || match="missed"
    else
      local count
      count=$(echo "$expected_json" | jq 'length')
      if [ "$count" -eq 0 ]; then
        match="false_positive"
      else
        # activated_skill에 expected 중 하나라도 포함되면 correct
        local found=false
        IFS='|' read -ra SKILLS <<< "$activated_skill"
        for s in "${SKILLS[@]}"; do
          if echo "$expected_json" | jq -e --arg s "$s" 'index($s) != null' > /dev/null 2>&1; then
            found=true
            break
          fi
        done
        [ "$found" = true ] && match="correct" || match="wrong_skill"
      fi
    fi

    # 로그
    local skill_display="${activated_skill:-(none)}"
    echo "[$config R$round] $id [$type] $match -> $skill_display" >> "$log_file"

    # CSV (expected를 pipe-separated로 변환하여 CSV 컬럼 깨짐 방지)
    local escaped_prompt expected_display
    escaped_prompt=$(echo "$prompt" | sed 's/,/;/g')
    expected_display=$(echo "$expected_json" | jq -r 'join("|")')
    echo "${id},${type},${escaped_prompt},${expected_display},${activated},${activated_skill},${match}" >> "$csv_file"
  done
}

# =============================================================================
# 메인
# =============================================================================
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Skill Activation Eval - Maum Backend (Parallel) ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_CASES=$(jq 'length' "$TEST_CASES")
PARALLEL_MODE="parallel"
[ "$SEQUENTIAL" = true ] && PARALLEL_MODE="sequential"
[ ${#CONFIGS[@]} -eq 1 ] && PARALLEL_MODE="sequential"

echo -e "${BLUE}테스트 케이스:${NC} ${TOTAL_CASES}개"
echo -e "${BLUE}훅 구성:${NC}      ${CONFIGS[*]}"
echo -e "${BLUE}모델:${NC}         ${MODEL}"
echo -e "${BLUE}반복:${NC}         ${ROUNDS}회"
echo -e "${BLUE}실행 방식:${NC}    ${PARALLEL_MODE}"
echo -e "${BLUE}타임아웃:${NC}     ${TIMEOUT_SEC}초"
if [ "$NO_OMC" = true ]; then
  echo -e "${YELLOW}OMC:${NC}          비활성화 (프로젝트 스킬만)"
fi
echo ""

# 의존성 확인
for cmd in claude jq python3 git $TIMEOUT_CMD; do
  if ! command -v "$cmd" &> /dev/null; then
    echo -e "${RED}오류: ${cmd}를 찾을 수 없습니다.${NC}"
    exit 1
  fi
done

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}=== DRY RUN ===${NC}"
  jq -r '.[] | "\(.id) [\(.type)] \(.prompt) -> \(.expected | join(", "))"' "$TEST_CASES"
  exit 0
fi

# 런 디렉토리 생성
RUN_DIR="$RESULTS_DIR/$TIMESTAMP"
mkdir -p "$RUN_DIR"

trap 'cleanup_temp_dirs; restore_omc' EXIT
disable_omc

# 요약 파일
SUMMARY_FILE="$RUN_DIR/summary.md"
cat > "$SUMMARY_FILE" << HEREDOC
# Skill Activation Eval Results

- **Date**: $(date '+%Y-%m-%d %H:%M:%S')
- **Model**: ${MODEL}
- **Rounds**: ${ROUNDS}
- **Test Cases**: ${TOTAL_CASES}
- **Configs**: ${CONFIGS[*]}
- **Execution**: ${PARALLEL_MODE}

HEREDOC

# =============================================================================
# 라운드별 실행
# =============================================================================
for round in $(seq 1 "$ROUNDS"); do
  echo -e "${CYAN}━━━ Round ${round}/${ROUNDS} ━━━${NC}"

  PIDS=()
  LOG_FILES=()
  CSV_FILES=()
  CONFIG_NAMES=()

  for config in "${CONFIGS[@]}"; do
    TEMP_DIR=$(setup_temp_dir "$config")
    CSV_FILE="$RUN_DIR/${config}-r${round}.csv"
    LOG_FILE="$RUN_DIR/${config}-r${round}.log"

    CSV_FILES+=("$CSV_FILE")
    LOG_FILES+=("$LOG_FILE")
    CONFIG_NAMES+=("$config")

    : > "$LOG_FILE"

    if [ "$PARALLEL_MODE" = "parallel" ]; then
      run_config "$config" "$round" "$TEMP_DIR" "$CSV_FILE" "$LOG_FILE" &
      PIDS+=($!)
      echo -e "  ${GREEN}[시작]${NC} $config (PID: $!)"
    else
      echo -e "  ${CYAN}--- $config ---${NC}"
      run_config "$config" "$round" "$TEMP_DIR" "$CSV_FILE" "$LOG_FILE"
    fi
  done

  # 병렬 대기
  if [ "$PARALLEL_MODE" = "parallel" ]; then
    echo ""
    echo -e "  ${BLUE}대기 중... (진행 상황은 로그 파일 참조)${NC}"
    echo -e "  ${BLUE}tail -f $RUN_DIR/*-r${round}.log${NC}"
    echo ""

    for i in "${!PIDS[@]}"; do
      wait "${PIDS[$i]}" || true
      echo -e "  ${GREEN}[완료]${NC} ${CONFIG_NAMES[$i]}"
    done
  fi

  # 라운드 결과 출력
  echo ""
  echo -e "  ${CYAN}--- Round ${round} 결과 ---${NC}"
  printf "  %-14s %8s %8s %6s %4s %6s\n" "Config" "Accuracy" "Activate" "Miss" "FP" "Wrong"
  echo "  ──────────── ──────── ──────── ────── ──── ──────"

  for i in "${!CONFIG_NAMES[@]}"; do
    csv="${CSV_FILES[$i]}"
    config="${CONFIG_NAMES[$i]}"

    t=$(tail -n +2 "$csv" | wc -l | tr -d ' ')
    c=$(tail -n +2 "$csv" | grep -c ',correct' || true)
    m=$(tail -n +2 "$csv" | grep -c ',missed' || true)
    f=$(tail -n +2 "$csv" | grep -c ',false_positive' || true)
    w=$(tail -n +2 "$csv" | grep -c ',wrong_skill' || true)

    if [ "$t" -gt 0 ]; then
      acc=$((c * 100 / t))
      act=$(( (c + w + f) * 100 / t ))
    else
      acc=0; act=0
    fi

    printf "  %-14s %7d%% %7d%% %5d  %3d  %5d\n" "$config" "$acc" "$act" "$m" "$f" "$w"

    # 요약 파일
    cat >> "$SUMMARY_FILE" << HEREDOC
### ${config} (R${round})
| Metric | Value |
|--------|-------|
| Accuracy | ${acc}% (${c}/${t}) |
| Activation Rate | ${act}% |
| Missed | ${m} |
| False Positive | ${f} |
| Wrong Skill | ${w} |

HEREDOC

    # 상세 로그 출력
    if [ -f "${LOG_FILES[$i]}" ]; then
      while IFS= read -r line; do
        case "$line" in
          *correct*) echo -e "    ${GREEN}${line}${NC}" ;;
          *missed*)  echo -e "    ${RED}${line}${NC}" ;;
          *false_positive*) echo -e "    ${RED}${line}${NC}" ;;
          *wrong_skill*) echo -e "    ${YELLOW}${line}${NC}" ;;
          *) echo "    $line" ;;
        esac
      done < "${LOG_FILES[$i]}"
    fi
    echo ""
  done

  # temp dir 정리
  rm -rf "${TEMP_BASE:?}/"*
done

# =============================================================================
# 최종 비교
# =============================================================================
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    최종 결과 비교                    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

printf "  ${BLUE}%-14s %-6s %8s %8s %6s %4s %6s${NC}\n" "Config" "Round" "Accuracy" "Activate" "Miss" "FP" "Wrong"
echo "  ──────────── ────── ──────── ──────── ────── ──── ──────"

for config in "${CONFIGS[@]}"; do
  for r in $(seq 1 "$ROUNDS"); do
    csv="$RUN_DIR/${config}-r${r}.csv"
    [ ! -f "$csv" ] && continue

    t=$(tail -n +2 "$csv" | wc -l | tr -d ' ')
    c=$(tail -n +2 "$csv" | grep -c ',correct' || true)
    m=$(tail -n +2 "$csv" | grep -c ',missed' || true)
    f=$(tail -n +2 "$csv" | grep -c ',false_positive' || true)
    w=$(tail -n +2 "$csv" | grep -c ',wrong_skill' || true)

    [ "$t" -eq 0 ] && continue
    acc=$((c * 100 / t))
    act=$(( (c + w + f) * 100 / t ))

    printf "  %-14s R%-5d %7d%% %7d%% %5d  %3d  %5d\n" "$config" "$r" "$acc" "$act" "$m" "$f" "$w"
  done
done

# 평균
echo ""
echo "  --- 평균 ---"

cat >> "$SUMMARY_FILE" << HEREDOC
---
## Summary (Average)
| Config | Accuracy | Activation | Missed | FP | Wrong |
|--------|----------|------------|--------|----|-------|
HEREDOC

for config in "${CONFIGS[@]}"; do
  total_acc=0; total_act=0; total_m=0; total_f=0; total_w=0; rc=0

  for r in $(seq 1 "$ROUNDS"); do
    csv="$RUN_DIR/${config}-r${r}.csv"
    [ ! -f "$csv" ] && continue

    t=$(tail -n +2 "$csv" | wc -l | tr -d ' ')
    c=$(tail -n +2 "$csv" | grep -c ',correct' || true)
    m=$(tail -n +2 "$csv" | grep -c ',missed' || true)
    f=$(tail -n +2 "$csv" | grep -c ',false_positive' || true)
    w=$(tail -n +2 "$csv" | grep -c ',wrong_skill' || true)

    [ "$t" -eq 0 ] && continue
    total_acc=$((total_acc + c * 100 / t))
    total_act=$((total_act + (c + w + f) * 100 / t))
    total_m=$((total_m + m))
    total_f=$((total_f + f))
    total_w=$((total_w + w))
    rc=$((rc + 1))
  done

  if [ "$rc" -gt 0 ]; then
    avg_acc=$((total_acc / rc))
    avg_act=$((total_act / rc))
    avg_m=$((total_m / rc))
    avg_f=$((total_f / rc))
    avg_w=$((total_w / rc))
    printf "  %-14s avg   %7d%% %7d%% %5d  %3d  %5d\n" "$config" "$avg_acc" "$avg_act" "$avg_m" "$avg_f" "$avg_w"
    echo "| ${config} | ${avg_acc}% | ${avg_act}% | ${avg_m} | ${avg_f} | ${avg_w} |" >> "$SUMMARY_FILE"
  fi
done

echo ""
echo -e "${GREEN}결과: ${RUN_DIR}/${NC}"
echo -e "${GREEN}요약: ${SUMMARY_FILE}${NC}"
