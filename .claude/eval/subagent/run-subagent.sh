#!/bin/bash
# =============================================================================
# Subagent Skill Activation Eval Runner
# =============================================================================
# 서브에이전트 환경 시뮬레이션: 훅 없이 prompt prefix만으로 스킬 활성화 측정
#
# 사용법:
#   ./run-subagent.sh --no-omc --rounds 2           # 전체 (3 configs x 20 cases x 2 rounds)
#   ./run-subagent.sh --no-omc --config tag          # 특정 config만
#   ./run-subagent.sh --no-omc --id D02 --config tag # 단건
#   ./run-subagent.sh --no-omc --sequential          # 순차 실행 (디버깅)
#   ./run-subagent.sh --dry-run                      # 프롬프트 미리보기
# =============================================================================

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$EVAL_DIR/../../.." && pwd)"
RESULTS_DIR="$EVAL_DIR/results"
TEST_CASES="$EVAL_DIR/test-cases.json"
FORCED_EVAL_INLINE="$EVAL_DIR/hooks/forced-eval-inline.txt"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
TIMEOUT_SEC=45
MODEL="sonnet"
ROUNDS=2
SEQUENTIAL=false
NO_OMC=false

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
      echo "  --config CONFIG   tag|tag-instruction|inline-forced-eval"
      echo "  --type TYPE       direct|natural|ambiguous|negative"
      echo "  --id ID           D02, N01, A01, X01 etc."
      echo "  --rounds N        반복 횟수 (기본: 2)"
      echo "  --model MODEL     사용 모델 (기본: sonnet)"
      echo "  --no-omc          OMC 플러그인 비활성화"
      echo "  --sequential      순차 실행 (기본: 병렬)"
      echo "  --dry-run         프롬프트만 출력"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# none은 기존 데이터 재사용 → 실행 대상에서 제외
CONFIGS=("tag" "tag-instruction" "inline-forced-eval")
if [ -n "$FILTER_CONFIG" ]; then
  CONFIGS=("$FILTER_CONFIG")
fi

# =============================================================================
# Prompt 생성
# =============================================================================
build_prompt() {
  local config="$1"
  local prompt="$2"
  local primary_skill="$3"

  case "$config" in
    none)
      echo "$prompt"
      ;;
    tag)
      if [ -n "$primary_skill" ]; then
        printf '<!-- skill: %s -->\n%s' "$primary_skill" "$prompt"
      else
        echo "$prompt"
      fi
      ;;
    tag-instruction)
      if [ -n "$primary_skill" ]; then
        printf '<!-- skill: %s -->\n위 스킬을 Skill() tool로 반드시 활성화한 후 작업을 진행하세요.\n\n%s' "$primary_skill" "$prompt"
      else
        echo "$prompt"
      fi
      ;;
    inline-forced-eval)
      printf '%s\n\n%s' "$(cat "$FORCED_EVAL_INLINE")" "$prompt"
      ;;
  esac
}

# =============================================================================
# Temp Dir 격리 (훅 없이, 프로젝트 스킬만)
# =============================================================================
TEMP_BASE="/tmp/claude-eval-subagent-${TIMESTAMP}"

setup_temp_dir() {
  local config="$1"
  local temp_dir="${TEMP_BASE}/${config}"
  [ -d "$temp_dir" ] && echo "$temp_dir" && return

  mkdir -p "$temp_dir"
  git init "$temp_dir" --quiet
  cp -r "$PROJECT_DIR/.claude" "$temp_dir/.claude"
  rm -f "$temp_dir/.claude/settings.local.json"
  rm -rf "$temp_dir/.claude/commands"

  # 전 config 동일: hooks = {} (없음), config별 dir 격리 (병렬 경합 방지)
  local settings="$temp_dir/.claude/settings.json"
  local base_settings="$PROJECT_DIR/.claude/settings.json"
  jq '.hooks = {} | del(.enabledPlugins)' "$base_settings" > "$settings"

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
    # 기존 백업이 있으면 먼저 정리
    [ -f "${GLOBAL_CLAUDE_MD}.eval-backup" ] && rm -f "${GLOBAL_CLAUDE_MD}.eval-backup"
    cp "$GLOBAL_CLAUDE_MD" "${GLOBAL_CLAUDE_MD}.eval-backup"
    rm "$GLOBAL_CLAUDE_MD"
    echo -e "${YELLOW}[OMC 비활성화]${NC} ~/.claude/CLAUDE.md 임시 제거"
  fi

  if [ -f "$GLOBAL_PLUGINS" ]; then
    [ -f "${GLOBAL_PLUGINS}.eval-backup" ] && rm -f "${GLOBAL_PLUGINS}.eval-backup"
    cp "$GLOBAL_PLUGINS" "${GLOBAL_PLUGINS}.eval-backup"
    jq '.plugins = {}' "$GLOBAL_PLUGINS" > "${GLOBAL_PLUGINS}.tmp"
    mv "${GLOBAL_PLUGINS}.tmp" "$GLOBAL_PLUGINS"
    echo -e "${YELLOW}[OMC 비활성화]${NC} installed_plugins.json 클리어"
  fi

  if [ -d "$OMC_PLUGIN_CACHE" ]; then
    [ -d "${OMC_PLUGIN_CACHE}.eval-backup" ] && rm -rf "${OMC_PLUGIN_CACHE}.eval-backup"
    mv "$OMC_PLUGIN_CACHE" "${OMC_PLUGIN_CACHE}.eval-backup"
    echo -e "${YELLOW}[OMC 비활성화]${NC} 플러그인 캐시 임시 이동"
  fi
  if [ -d "$OMC_PLUGIN_MARKET" ]; then
    [ -d "${OMC_PLUGIN_MARKET}.eval-backup" ] && rm -rf "${OMC_PLUGIN_MARKET}.eval-backup"
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
# 단일 config 실행
# =============================================================================
run_config() {
  set +e  # 함수 내에서 개별 명령 실패 허용
  local config="$1"
  local round="$2"
  local temp_dir="$3"
  local csv_file="$4"
  local log_file="$5"

  echo "id,type,prompt,expected,activated,activated_skill,result,duration_ms,tag_skill,tag_followed,extra_skills" > "$csv_file"

  local total_cases
  total_cases=$(jq 'length' "$TEST_CASES")

  local i id type raw_prompt expected_json primary_skill
  local full_prompt start_ms end_ms duration_ms output
  local all_skills activated_skill activated tag_followed extra_skills

  for i in $(seq 0 $((total_cases - 1))); do
    id=$(jq -r ".[$i].id" "$TEST_CASES")
    type=$(jq -r ".[$i].type" "$TEST_CASES")
    raw_prompt=$(jq -r ".[$i].prompt" "$TEST_CASES")
    expected_json=$(jq -c ".[$i].expected" "$TEST_CASES")
    primary_skill=$(jq -r ".[$i].primary_skill // empty" "$TEST_CASES")

    # 필터
    if [ -n "$FILTER_TYPE" ] && [ "$type" != "$FILTER_TYPE" ]; then continue; fi
    if [ -n "$FILTER_ID" ] && [ "$id" != "$FILTER_ID" ]; then continue; fi

    # Prompt 생성
    full_prompt=$(build_prompt "$config" "$raw_prompt" "$primary_skill")

    # 실행 (크래시 감지 + 자동 재시도)
    local attempt max_attempts=3
    for attempt in $(seq 1 $max_attempts); do
      start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')

      output=$(cd "$temp_dir" && env -u CLAUDECODE $TIMEOUT_CMD "$TIMEOUT_SEC" claude -p "$full_prompt" \
        --output-format stream-json \
        --verbose \
        --max-turns 3 \
        --model "$MODEL" \
        --allowedTools "Skill" \
        2>/dev/null) || output=""

      end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
      duration_ms=$((end_ms - start_ms))

      # 크래시 감지: 1초 미만이면 프로세스가 정상 실행되지 않은 것
      if [ "$duration_ms" -ge 1000 ]; then
        break  # 정상 실행
      fi

      if [ "$attempt" -lt "$max_attempts" ]; then
        echo "[$config R$round] $id 크래시 감지 (${duration_ms}ms), 재시도 ${attempt}/${max_attempts}... (3초 대기)" >> "$log_file"
        sleep 3
      else
        echo "[$config R$round] $id 크래시 ${max_attempts}회 반복, 결과 그대로 기록 (${duration_ms}ms)" >> "$log_file"
      fi
    done

    # Skill 호출 감지 (모든 호출된 스킬 수집)
    activated="false"
    all_skills=""
    activated_skill=""

    if echo "$output" | grep -q '"name":"Skill"'; then
      activated="true"
      all_skills=$(echo "$output" \
        | grep -o '"skill":"[^"]*"' \
        | sed 's/"skill":"//;s/"//' \
        | sort -u \
        | paste -sd '|' -) || all_skills=""
      # 첫 번째 스킬 (주 호출)
      activated_skill=$(echo "$output" \
        | grep -o '"skill":"[^"]*"' \
        | head -1 \
        | sed 's/"skill":"//;s/"//') || activated_skill=""
    fi

    # tag_followed: 지정 스킬을 실제로 호출했는지
    tag_followed=""
    if [ -n "$primary_skill" ]; then
      if echo "$all_skills" | grep -q "$primary_skill"; then
        tag_followed="true"
      else
        tag_followed="false"
      fi
    fi

    # extra_skills: 지정 외 추가 호출된 스킬
    extra_skills=""
    if [ -n "$all_skills" ] && [ -n "$primary_skill" ]; then
      extra_skills=$(echo "$all_skills" | tr '|' '\n' | grep -v "^${primary_skill}$" | paste -sd '|' -) || extra_skills=""
    elif [ -n "$all_skills" ] && [ -z "$primary_skill" ]; then
      extra_skills="$all_skills"
    fi

    # 판정 (기존 로직 동일)
    local match count any_match sk
    local escaped_prompt expected_pipe skill_display tag_display
    if [ -z "$activated_skill" ]; then
      count=$(echo "$expected_json" | jq 'length')
      [ "$count" -eq 0 ] && match="correct" || match="missed"
    else
      count=$(echo "$expected_json" | jq 'length')
      if [ "$count" -eq 0 ]; then
        match="false_positive"
      elif echo "$expected_json" | jq -e --arg s "$activated_skill" 'index($s) != null' > /dev/null 2>&1; then
        match="correct"
      else
        # 다중 스킬 호출 시 하나라도 expected에 포함되면 correct
        any_match=false
        for sk in $(echo "$all_skills" | tr '|' ' '); do
          if echo "$expected_json" | jq -e --arg s "$sk" 'index($s) != null' > /dev/null 2>&1; then
            any_match=true
            break
          fi
        done
        [ "$any_match" = true ] && match="correct" || match="wrong_skill"
      fi
    fi

    # 로그
    skill_display="${all_skills:-(none)}"
    tag_display="${primary_skill:--}"
    echo "[$config R$round] $id [$type] $match -> $skill_display (tag:$tag_display followed:${tag_followed:--}) (${duration_ms}ms)" >> "$log_file"

    # CSV (쉼표 안전: prompt의 쉼표를 세미콜론으로, expected는 pipe로)
    escaped_prompt=$(echo "$raw_prompt" | sed 's/,/;/g')
    expected_pipe=$(echo "$expected_json" | jq -r 'join("|")')

    echo "${id},${type},${escaped_prompt},${expected_pipe},${activated},${activated_skill},${match},${duration_ms},${primary_skill},${tag_followed},${extra_skills}" >> "$csv_file"
  done
  set -e  # set -e 복구
}

# =============================================================================
# 메인
# =============================================================================
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Subagent Skill Activation Eval (Prompt Prefix Only)   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_CASES=$(jq 'length' "$TEST_CASES")
PARALLEL_MODE="parallel"
[ "$SEQUENTIAL" = true ] && PARALLEL_MODE="sequential"
[ ${#CONFIGS[@]} -eq 1 ] && PARALLEL_MODE="sequential"

echo -e "${BLUE}테스트 케이스:${NC} ${TOTAL_CASES}개"
echo -e "${BLUE}Config:${NC}       ${CONFIGS[*]}"
echo -e "${BLUE}모델:${NC}         ${MODEL}"
echo -e "${BLUE}반복:${NC}         ${ROUNDS}회"
echo -e "${BLUE}실행 방식:${NC}    ${PARALLEL_MODE}"
echo -e "${BLUE}타임아웃:${NC}     ${TIMEOUT_SEC}초"
echo -e "${BLUE}훅:${NC}           없음 (전 config 동일)"
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

# Dry run: 생성될 프롬프트 미리보기
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}=== DRY RUN (프롬프트 미리보기) ===${NC}"
  total=$(jq 'length' "$TEST_CASES")
  for config in "${CONFIGS[@]}"; do
    echo ""
    echo -e "${CYAN}--- $config ---${NC}"
    for i in $(seq 0 $((total - 1))); do
      id=$(jq -r ".[$i].id" "$TEST_CASES")
      prompt=$(jq -r ".[$i].prompt" "$TEST_CASES")
      primary=$(jq -r ".[$i].primary_skill // empty" "$TEST_CASES")

      if [ -n "$FILTER_ID" ] && [ "$id" != "$FILTER_ID" ]; then continue; fi

      full=$(build_prompt "$config" "$prompt" "$primary")
      echo ""
      echo -e "${GREEN}[$id]${NC} (tag: ${primary:--})"
      echo "$full"
      echo "---"
    done
  done
  exit 0
fi

mkdir -p "$RESULTS_DIR"
RESULT_SUBDIR="$RESULTS_DIR/${TIMESTAMP}"
mkdir -p "$RESULT_SUBDIR"

trap 'cleanup_temp_dirs; restore_omc' EXIT
disable_omc

# 요약 파일
SUMMARY_FILE="$RESULT_SUBDIR/summary.md"
cat > "$SUMMARY_FILE" << HEREDOC
# Subagent Skill Activation Eval Results

- **Date**: $(date '+%Y-%m-%d %H:%M:%S')
- **Model**: ${MODEL}
- **Rounds**: ${ROUNDS}
- **Test Cases**: ${TOTAL_CASES}
- **Configs**: ${CONFIGS[*]}
- **Hooks**: none (prompt prefix only)
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
    CSV_FILE="$RESULT_SUBDIR/${config}-r${round}.csv"
    LOG_FILE="$RESULT_SUBDIR/${config}-r${round}.log"

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
    echo -e "  ${BLUE}tail -f $RESULT_SUBDIR/*-r${round}.log${NC}"
    echo ""

    for i in "${!PIDS[@]}"; do
      wait "${PIDS[$i]}" || true
      echo -e "  ${GREEN}[완료]${NC} ${CONFIG_NAMES[$i]}"
    done
  fi

  # 라운드 결과 출력
  echo ""
  echo -e "  ${CYAN}--- Round ${round} 결과 ---${NC}"
  printf "  %-20s %8s %8s %6s %4s %6s %10s\n" "Config" "Accuracy" "Activate" "Miss" "FP" "Wrong" "TagFollow"
  echo "  ──────────────────── ──────── ──────── ────── ──── ────── ──────────"

  for i in "${!CONFIG_NAMES[@]}"; do
    csv="${CSV_FILES[$i]}"
    config="${CONFIG_NAMES[$i]}"

    t=$(tail -n +2 "$csv" | wc -l | tr -d ' ')
    c=$(tail -n +2 "$csv" | grep -c ',correct,' || true)
    m=$(tail -n +2 "$csv" | grep -c ',missed,' || true)
    f=$(tail -n +2 "$csv" | grep -c ',false_positive,' || true)
    w=$(tail -n +2 "$csv" | grep -c ',wrong_skill,' || true)

    # tag_followed 비율 (primary_skill이 있는 행 중 tag_followed=true 비율)
    tagged_total=$(tail -n +2 "$csv" | awk -F, '$9 != ""' | wc -l | tr -d ' ')
    tagged_followed=$(tail -n +2 "$csv" | awk -F, '$10 == "true"' | wc -l | tr -d ' ')

    if [ "$t" -gt 0 ]; then
      acc=$((c * 100 / t))
      act=$(( (c + w + f) * 100 / t ))
    else
      acc=0; act=0
    fi

    if [ "$tagged_total" -gt 0 ]; then
      tf_pct=$((tagged_followed * 100 / tagged_total))
    else
      tf_pct=0
    fi

    printf "  %-20s %7d%% %7d%% %5d  %3d  %5d  %4d/%d=%d%%\n" \
      "$config" "$acc" "$act" "$m" "$f" "$w" "$tagged_followed" "$tagged_total" "$tf_pct"

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
| Tag Followed | ${tagged_followed}/${tagged_total} (${tf_pct}%) |

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
done

# =============================================================================
# 최종 비교
# =============================================================================
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    최종 결과 비교                        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

printf "  ${BLUE}%-20s %-6s %8s %8s %6s %4s %6s${NC}\n" "Config" "Round" "Accuracy" "Activate" "Miss" "FP" "Wrong"
echo "  ──────────────────── ────── ──────── ──────── ────── ──── ──────"

for config in "${CONFIGS[@]}"; do
  for r in $(seq 1 "$ROUNDS"); do
    csv="$RESULT_SUBDIR/${config}-r${r}.csv"
    [ ! -f "$csv" ] && continue

    t=$(tail -n +2 "$csv" | wc -l | tr -d ' ')
    c=$(tail -n +2 "$csv" | grep -c ',correct,' || true)
    m=$(tail -n +2 "$csv" | grep -c ',missed,' || true)
    f=$(tail -n +2 "$csv" | grep -c ',false_positive,' || true)
    w=$(tail -n +2 "$csv" | grep -c ',wrong_skill,' || true)

    [ "$t" -eq 0 ] && continue
    acc=$((c * 100 / t))
    act=$(( (c + w + f) * 100 / t ))

    printf "  %-20s R%-5d %7d%% %7d%% %5d  %3d  %5d\n" "$config" "$r" "$acc" "$act" "$m" "$f" "$w"
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
    csv="$RESULT_SUBDIR/${config}-r${r}.csv"
    [ ! -f "$csv" ] && continue

    t=$(tail -n +2 "$csv" | wc -l | tr -d ' ')
    c=$(tail -n +2 "$csv" | grep -c ',correct,' || true)
    m=$(tail -n +2 "$csv" | grep -c ',missed,' || true)
    f=$(tail -n +2 "$csv" | grep -c ',false_positive,' || true)
    w=$(tail -n +2 "$csv" | grep -c ',wrong_skill,' || true)

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
    printf "  %-20s avg   %7d%% %7d%% %5d  %3d  %5d\n" "$config" "$avg_acc" "$avg_act" "$avg_m" "$avg_f" "$avg_w"
    echo "| ${config} | ${avg_acc}% | ${avg_act}% | ${avg_m} | ${avg_f} | ${avg_w} |" >> "$SUMMARY_FILE"
  fi
done

echo ""
echo -e "${GREEN}결과: ${RESULT_SUBDIR}/${NC}"
echo -e "${GREEN}요약: ${SUMMARY_FILE}${NC}"
