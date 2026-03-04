#!/bin/bash
# llm-eval: recommend agent via Haiku 4.5 and inject instruction

MODEL="claude-haiku-4-5-20251001"

INPUT_JSON=$(timeout 2 cat || echo '{}')
USER_PROMPT=$(echo "$INPUT_JSON" | jq -r '.prompt // ""' 2>/dev/null)
CWD=$(echo "$INPUT_JSON" | jq -r '.cwd // ""' 2>/dev/null)

if [ -z "$CWD" ] || [ "$CWD" = "null" ]; then
  CWD="${CLAUDE_PROJECT_DIR:-.}"
fi

# Extract descriptions from .claude/agents/*.md
AGENTS_DIR="$CWD/.claude/agents"
AGENT_LIST=""

if [ -d "$AGENTS_DIR" ]; then
  for agent_file in "$AGENTS_DIR"/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name=$(basename "$agent_file" .md)
    agent_desc=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep '^description:' | sed 's/^description: *//' | head -n 1)
    if [ -n "$agent_desc" ]; then
      AGENT_LIST="${AGENT_LIST}- ${agent_name}: ${agent_desc}
"
    fi
  done
fi

FALLBACK="INSTRUCTION: When delegating via Task, refer to agent descriptions in .claude/agents/ and select the most appropriate agent."

if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "$FALLBACK"
  exit 0
fi

EVAL_PROMPT=$(cat <<EOF
Select the single most appropriate agent for the user's request.

Request: ${USER_PROMPT}

Agent list:
${AGENT_LIST}
Return only the agent name (e.g., db-query-helper). Return "none" if no agent is appropriate.
EOF
)

RESPONSE=$(curl -s --max-time 15 https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d "{
    \"model\": \"$MODEL\",
    \"max_tokens\": 100,
    \"temperature\": 0,
    \"system\": \"You are an agent router. Return only the agent name, nothing else.\",
    \"messages\": [{
      \"role\": \"user\",
      \"content\": $(echo "$EVAL_PROMPT" | jq -Rs .)
    }]
  }")

AGENT_NAME=$(echo "$RESPONSE" | jq -r '.content[0].text' 2>/dev/null | tr -d '[:space:]' | tr -d '"')

if [ -z "$AGENT_NAME" ] || [ "$AGENT_NAME" = "null" ] || [ "$AGENT_NAME" = "none" ]; then
  echo "$FALLBACK"
else
  echo "INSTRUCTION: Based on LLM evaluation, the most appropriate agent for this task is \"${AGENT_NAME}\"."
  echo ""
  echo "You MUST delegate via Task(subagent_type=\"${AGENT_NAME}\")."
fi
