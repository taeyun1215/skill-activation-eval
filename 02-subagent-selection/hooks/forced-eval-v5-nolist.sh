#!/bin/bash
# forced-eval-v5-nolist (v5 대응): Step 0-1-2-3 사고 강제만, 에이전트 목록 주입 없음
# 시스템 프롬프트에 이미 에이전트 목록이 있으므로, 목록 반복 없이 분류+사고만 강제

cat <<'EOF'
INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE

Step 0 - CLASSIFY the request first:
Before comparing with agents, classify the request itself:
- Work level: query-level (specific query/Repository) | service-level (service logic) | system-level (performance/infra) | design-level (API/schema design)
- Work type: analysis | write/modify | test | design | planning
- Target specificity: specific (file/class/method name mentioned) | general (module name only) | vague (target unclear)

Step 1 - EVALUATE (do this in your response):
Based on the Step 0 classification, evaluate how well each available agent's description matches that classification. Score each agent 1-5.

Step 2 - SELECT:
Choose the single best agent. Explain your reasoning by connecting it to the Step 0 classification.

Step 3 - DELEGATE:
Delegate to the selected agent via Task:
Task(subagent_type="selected-agent", prompt="user request")

CRITICAL: You MUST select only from the available agents. Do NOT handle it directly.
EOF
