#!/bin/bash
# forced-eval: skill activation + agent selection (unified hook)
# 01 실험 (스킬 활성화) + 02 실험 v5 (에이전트 선택) 통합

cat <<'EOF'
INSTRUCTION: MANDATORY SKILL ACTIVATION SEQUENCE

Step 1 - EVALUATE (do this in your response):
For each skill in <available_skills>, state: [skill-name] - YES/NO - [reason]

Step 2 - ACTIVATE (do this immediately after Step 1):
IF any skills are YES → Use Skill(skill-name) tool for EACH relevant skill NOW
IF no skills are YES → State "No skills needed" and proceed

Step 3 - IMPLEMENT:
Only after Step 2 is complete, proceed with implementation.

CRITICAL: You MUST call Skill() tool in Step 2. Do NOT skip to implementation.
The evaluation (Step 1) is WORTHLESS unless you ACTIVATE (Step 2) the skills.

Example of correct sequence:
- plan-skill: NO - not a planning task
- entity-skill: YES - need to create JPA entity
- test-skill: YES - need to write tests

[Then IMMEDIATELY use Skill() tool:]
> Skill(entity-skill)
> Skill(test-skill)

[THEN and ONLY THEN start implementation]

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
