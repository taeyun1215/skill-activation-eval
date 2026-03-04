#!/bin/bash
# =============================================================================
# Direct Embed Test — 서브에이전트 스킬 전달률 비교
# =============================================================================
# 4가지 config으로 스킬이 서브에이전트에 전달되는지 측정.
#
# Configs:
#   none          — 프롬프트만 (baseline)
#   tag           — <!-- skill: {name} --> HTML 주석 태그
#   light-embed   — "SKILL.md를 참고하세요" 힌트
#   direct-embed  — <skill-guide>{SKILL.md 전문}</skill-guide>
#
# 측정 지표:
#   skill_loaded — 서브에이전트가 스킬 내용을 로드했는가
#
# 사용법:
#   ./test-direct-embed.sh --no-omc                     # 전체 실행
#   ./test-direct-embed.sh --no-omc --id D02             # 단건
#   ./test-direct-embed.sh --no-omc --config direct-embed # 특정 config만
#   ./test-direct-embed.sh --dry-run                      # 프롬프트 미리보기
# =============================================================================

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$EVAL_DIR/../../.." && pwd)"
SKILLS_DIR="$PROJECT_DIR/.claude/skills"
RESULTS_DIR="$EVAL_DIR/results-embed"
TEST_CASES="$EVAL_DIR/test-cases.json"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
TIMEOUT_SEC=120
MODEL="sonnet"
ROUNDS=1
SEQUENTIAL=false
NO_OMC=false

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
    --sequential) SEQUENTIAL=true; shift ;;
    --no-omc)     NO_OMC=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "  --config CONFIG   none|direct-embed"
      echo "  --id ID           D02, N01, etc."
      echo "  --rounds N        반복 (기본: 1)"
      echo "  --no-omc          OMC 비활성화"
      echo "  --sequential      순차 실행"
      echo "  --dry-run         프롬프트만 출력"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

CONFIGS=("none" "tag" "light-embed" "direct-embed")
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
    light-embed)
      if [ -n "$primary_skill" ]; then
        printf '이 작업은 %s과 관련됩니다. 프로젝트의 .claude/skills/%s/SKILL.md를 참고하세요.\n\n%s' "$primary_skill" "$primary_skill" "$prompt"
      else
        echo "$prompt"
      fi
      ;;
    direct-embed)
      if [ -n "$primary_skill" ]; then
        local skill_file="$SKILLS_DIR/$primary_skill/SKILL.md"
        if [ -f "$skill_file" ]; then
          local skill_content
          skill_content=$(cat "$skill_file")
          printf '<skill-guide>\n%s\n</skill-guide>\n\n%s' "$skill_content" "$prompt"
        else
          echo "$prompt"
        fi
      else
        echo "$prompt"
      fi
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
TEMP_BASE="/tmp/claude-eval-embed-${TIMESTAMP}"

setup_temp_dir() {
  local config="$1"
  local temp_dir="${TEMP_BASE}/${config}"
  mkdir -p "$temp_dir"

  # 프로젝트 스킬 복사
  if [ -d "$PROJECT_DIR/.claude" ]; then
    mkdir -p "$temp_dir/.claude"
    cp -r "$PROJECT_DIR/.claude/skills" "$temp_dir/.claude/skills" 2>/dev/null || true
    cp "$PROJECT_DIR/.claude/CLAUDE.md" "$temp_dir/.claude/CLAUDE.md" 2>/dev/null || true
  fi

  # git 초기화 (claude -p 필수)
  (cd "$temp_dir" && git init -q 2>/dev/null || true)

  echo "$temp_dir"
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

  echo "id,type,prompt,expected_skill,config,skill_loaded,loaded_skills" > "$csv_file"

  local total_cases
  total_cases=$(jq 'length' "$TEST_CASES")

  local i id type raw_prompt primary_skill
  local full_prompt start_ms end_ms duration_ms output
  local skill_loaded attempt max_attempts=3

  for i in $(seq 0 $((total_cases - 1))); do
    id=$(jq -r ".[$i].id" "$TEST_CASES")
    type=$(jq -r ".[$i].type" "$TEST_CASES")
    raw_prompt=$(jq -r ".[$i].prompt" "$TEST_CASES")
    primary_skill=$(jq -r ".[$i].primary_skill // empty" "$TEST_CASES")

    # 필터
    if [ -n "$FILTER_ID" ] && [ "$id" != "$FILTER_ID" ]; then continue; fi

    full_prompt=$(build_prompt "$config" "$raw_prompt" "$primary_skill")

    # 프롬프트 저장
    local raw_dir="$RESULT_SUBDIR/raw/${config}"
    mkdir -p "$raw_dir"
    echo "$full_prompt" > "$raw_dir/${id}-prompt.txt"

    # 로그 디렉토리
    local log_dir="$RESULT_SUBDIR/logs/${config}"
    mkdir -p "$log_dir"

    # 실행 (크래시 감지 + 재시도)
    for attempt in $(seq 1 $max_attempts); do
      start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')

      output=$(cd "$temp_dir" && env -u CLAUDECODE $TIMEOUT_CMD "$TIMEOUT_SEC" claude -p "$full_prompt" \
        --output-format stream-json \
        --verbose \
        --max-turns 3 \
        --model "$MODEL" \
        2>/dev/null) || output=""

      end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
      duration_ms=$((end_ms - start_ms))

      if [ "$duration_ms" -ge 1000 ]; then
        break
      fi

      if [ "$attempt" -lt "$max_attempts" ]; then
        echo -e "  ${YELLOW}[$config R$round] $id 크래시 감지, 재시도 ${attempt}/${max_attempts}${NC}" >&2
        sleep 3
      fi
    done

    # stream-json 로그 저장 (전달 판정의 근거)
    echo "$output" > "$log_dir/${id}-r${round}.json"

    # 스킬 로드 감지 (config별 경로가 다름)
    # 주의: echo "$output" | grep -q 는 pipefail + 대용량 출력 시 Broken pipe로 오판됨
    # → 저장된 로그 파일에서 grep하여 정확하게 감지
    local log_file="$log_dir/${id}-r${round}.json"
    local loaded_skills=""
    skill_loaded="false"
    if [ -z "$primary_skill" ]; then
      # negative 케이스: 스킬 대상 없음
      skill_loaded=""
    elif [ "$config" = "direct-embed" ]; then
      # direct-embed: 프롬프트에 포함 → 항상 로드됨
      skill_loaded="true"
      loaded_skills="$primary_skill"
    elif [ "$config" = "light-embed" ]; then
      # light-embed: Read tool로 어떤 SKILL.md를 읽었는지 추출
      loaded_skills=$(grep -o '"file_path":"[^"]*skills/[^"]*SKILL.md"' "$log_file" 2>/dev/null \
        | sed 's|.*skills/||;s|/SKILL.md"||' \
        | sort -u \
        | tr '\n' '|' \
        | sed 's/|$//')
      if echo "|${loaded_skills}|" | grep -q "|${primary_skill}|"; then
        skill_loaded="true"
      fi
    else
      # none / tag: Skill() tool로 어떤 스킬을 호출했는지 추출
      loaded_skills=$(grep -o '"name":"Skill","input":{"skill":"[^"]*"' "$log_file" 2>/dev/null \
        | sed 's|.*"skill":"||;s|"||' \
        | sort -u \
        | tr '\n' '|' \
        | sed 's/|$//')
      if echo "|${loaded_skills}|" | grep -q "|${primary_skill}|"; then
        skill_loaded="true"
      fi
    fi

    # 콘솔 출력
    local result_icon
    if [ -z "$primary_skill" ]; then
      echo -e "  ${GREEN}[$config R$round] $id [$type] n/a (negative)${NC}" >&2
    elif [ "$skill_loaded" = "true" ]; then
      echo -e "  ${GREEN}[$config R$round] $id [$type] loaded${NC}" >&2
    else
      echo -e "  ${RED}[$config R$round] $id [$type] not_loaded${NC}" >&2
    fi

    # CSV
    local escaped_prompt
    escaped_prompt=$(echo "$raw_prompt" | sed 's/,/;/g')
    echo "${id},${type},${escaped_prompt},${primary_skill},${config},${skill_loaded},${loaded_skills}" >> "$csv_file"
  done
  set -e
}

# =============================================================================
# Dry run
# =============================================================================
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}=== DRY RUN ===${NC}"
  total=$(jq 'length' "$TEST_CASES")
  for config in "${CONFIGS[@]}"; do
    echo -e "\n${CYAN}--- $config ---${NC}"
    for i in $(seq 0 $((total - 1))); do
      id=$(jq -r ".[$i].id" "$TEST_CASES")
      prompt=$(jq -r ".[$i].prompt" "$TEST_CASES")
      skill=$(jq -r ".[$i].primary_skill // empty" "$TEST_CASES")
      [ -n "$FILTER_ID" ] && [ "$id" != "$FILTER_ID" ] && continue

      full=$(build_prompt "$config" "$prompt" "$skill")
      echo -e "\n  ${BLUE}[$id]${NC} skill=$skill"
      echo "  $full" | head -5
      [ $(echo "$full" | wc -l) -gt 5 ] && echo "  ... ($(echo "$full" | wc -l)줄)"
    done
  done
  exit 0
fi

# =============================================================================
# 메인
# =============================================================================
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Direct Embed Test — 스킬 내용 직접 포함 검증              ║${NC}"
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
echo -e "${BLUE}실행 방식:${NC}    ${PARALLEL_MODE}"
echo -e "${BLUE}타임아웃:${NC}     ${TIMEOUT_SEC}초"
echo -e "${BLUE}Tools:${NC}        제한 없음 (All Tools)"
if [ "$NO_OMC" = true ]; then
  echo -e "${YELLOW}OMC:${NC}          비활성화"
fi
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
  printf "  %-15s %10s %6s %10s\n" "Config" "TP" "FP" "Accuracy"
  echo "  ─────────────── ────────── ────── ──────────"

  for i in "${!CONFIG_NAMES[@]}"; do
    csv="${CSV_FILES[$i]}"
    config="${CONFIG_NAMES[$i]}"

    # TP: positive 케이스 중 skill_loaded=true
    tp=$(tail -n +2 "$csv" | awk -F, '$4 != "" && $6 == "true"' | wc -l | tr -d ' ')
    positive_total=$(tail -n +2 "$csv" | awk -F, '$4 != ""' | wc -l | tr -d ' ')
    # FP: negative 케이스 중 loaded_skills가 비어있지 않은 경우
    fp=$(tail -n +2 "$csv" | awk -F, '$4 == "" && $7 != ""' | wc -l | tr -d ' ')
    negative_total=$(tail -n +2 "$csv" | awk -F, '$4 == ""' | wc -l | tr -d ' ')
    # TN = negative_total - fp
    tn=$((negative_total - fp))
    # 전체 정확도 = (TP + TN) / 전체
    total_cases=$((positive_total + negative_total))
    correct=$((tp + tn))
    if [ "$total_cases" -gt 0 ]; then
      accuracy=$((correct * 100 / total_cases))
    else
      accuracy=0
    fi

    printf "  %-15s %5s/%-4s %2s/%-3s %5s/%s(%s%%)\n" \
      "$config" "$tp" "$positive_total" "$fp" "$negative_total" "$correct" "$total_cases" "$accuracy"
  done
  echo ""
done

# 최종 비교
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    최종 결과 비교                            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

printf "  %-15s %10s %6s %10s\n" "Config" "TP" "FP" "Accuracy"
echo "  ─────────────── ────────── ────── ──────────"

for config in "${CONFIGS[@]}"; do
  total_tp=0
  total_positive=0
  total_fp=0
  total_negative=0

  for round in $(seq 1 "$ROUNDS"); do
    csv="$RESULT_SUBDIR/${config}-r${round}.csv"
    [ -f "$csv" ] || continue

    tp=$(tail -n +2 "$csv" | awk -F, '$4 != "" && $6 == "true"' | wc -l | tr -d ' ')
    p=$(tail -n +2 "$csv" | awk -F, '$4 != ""' | wc -l | tr -d ' ')
    fp=$(tail -n +2 "$csv" | awk -F, '$4 == "" && $7 != ""' | wc -l | tr -d ' ')
    n=$(tail -n +2 "$csv" | awk -F, '$4 == ""' | wc -l | tr -d ' ')

    total_tp=$((total_tp + tp))
    total_positive=$((total_positive + p))
    total_fp=$((total_fp + fp))
    total_negative=$((total_negative + n))
  done

  total_tn=$((total_negative - total_fp))
  total_cases=$((total_positive + total_negative))
  correct=$((total_tp + total_tn))
  if [ "$total_cases" -gt 0 ]; then
    accuracy=$((correct * 100 / total_cases))
  else
    accuracy=0
  fi

  printf "  %-15s %5s/%-4s %2s/%-3s %5s/%s(%s%%)\n" \
    "$config" "$total_tp" "$total_positive" "$total_fp" "$total_negative" "$correct" "$total_cases" "$accuracy"
done

echo ""
echo -e "${GREEN}결과: ${RESULT_SUBDIR}/${NC}"

# 정리
rm -rf "$TEMP_BASE" 2>/dev/null || true
