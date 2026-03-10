#!/bin/bash
# forced-eval-nolist (v4 대응): Step 1-2-3 사고 강제만, 에이전트 목록 주입 없음
# 시스템 프롬프트에 이미 에이전트 목록이 있으므로, 목록 반복 없이 사고만 강제

cat <<'EOF'
INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE

Step 1 - EVALUATE (do this in your response):
Evaluate how well each available agent's description matches the user's request. Score each agent 1-5.

Step 2 - SELECT:
Choose the single best agent. Briefly explain your reasoning.

Step 3 - DELEGATE:
Delegate to the selected agent via Task:
Task(subagent_type="selected-agent", prompt="user request")

CRITICAL: You MUST select only from the available agents. Do NOT handle it directly.
EOF
