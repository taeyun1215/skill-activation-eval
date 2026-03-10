#!/bin/bash
# forced-eval-v6: v5 + Step 4 self-verification (선택 후 재검증)

INPUT_JSON=$(timeout 2 cat || echo '{}')
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

cat <<EOF
INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE

Step 0 - CLASSIFY the request first:
Before comparing with agents, classify the request itself:
- Work level: query-level (specific query/Repository) | service-level (service logic) | system-level (performance/infra) | design-level (API/schema design)
- Work type: analysis | write/modify | test | design | planning
- Target specificity: specific (file/class/method name mentioned) | general (module name only) | vague (target unclear)

Step 1 - EVALUATE (do this in your response):
Based on the Step 0 classification, evaluate how well each agent's description matches that classification:

${AGENT_LIST}
Step 2 - SELECT:
Choose the single best agent. Explain your reasoning by connecting it to the Step 0 classification.

Step 3 - VERIFY your selection:
Before delegating, re-read the selected agent's description above and extract 2-3 core keywords from the user's request.
Check: do the request keywords align with the agent's described capability?
- If YES: proceed to Step 4.
- If NO: go back to Step 2 and re-select a different agent.

Step 4 - DELEGATE:
Delegate to the verified agent via Task:
Task(subagent_type="selected-agent", prompt="user request")

CRITICAL: You MUST select only from the agent list above. Do NOT handle it directly.
EOF
