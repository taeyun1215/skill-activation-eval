#!/bin/bash
# forced-eval: dynamically read agent descriptions and force structured evaluation

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

Step 1 - EVALUATE (do this in your response):
From the following agent list, select the most appropriate agent for the user's request.
Compare each agent's description against the user's request and evaluate fitness:

${AGENT_LIST}
Step 2 - SELECT:
Choose the single best agent. Briefly explain your reasoning.

Step 3 - DELEGATE:
Delegate to the selected agent via Task:
Task(subagent_type="selected-agent", prompt="user request")

CRITICAL: You MUST select only from the agent list above. Do NOT handle it directly.
EOF
