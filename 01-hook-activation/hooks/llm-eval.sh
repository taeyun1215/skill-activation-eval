# Model
MODEL="claude-haiku-4-5-20251001"

# Read JSON input from stdin with timeout
INPUT_JSON=$(timeout 2 cat || echo '{}')

# Extract user prompt and cwd from JSON
USER_PROMPT=$(echo "$INPUT_JSON" | jq -r '.prompt // ""' 2>/dev/null)
CWD=$(echo "$INPUT_JSON" | jq -r '.cwd // ""' 2>/dev/null)

# Use CLAUDE_PROJECT_DIR if CWD is empty
if [ -z "$CWD" ] || [ "$CWD" = "null" ]; then
	CWD="${CLAUDE_PROJECT_DIR:-.}"
fi

# Get available skills with descriptions
AVAILABLE_SKILLS=""

scan_skills_dir() {
	local dir="$1"

	if [ -d "$dir" ]; then
		for skill_dir in "$dir"/*/; do
			if [ -d "$skill_dir" ]; then
				skill_file="$skill_dir/SKILL.md"
				if [ -f "$skill_file" ]; then
					skill_name=$(basename "$skill_dir")
					# Extract description from YAML frontmatter
					skill_desc=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep '^description:' | sed 's/^description: *//' | head -n 1)

					if [ -n "$skill_desc" ]; then
						AVAILABLE_SKILLS="${AVAILABLE_SKILLS}- ${skill_name}: ${skill_desc}
"
					else
						AVAILABLE_SKILLS="${AVAILABLE_SKILLS}- ${skill_name}
"
					fi
				fi
			fi
		done
	fi
}

# Scan project skills
scan_skills_dir "$CWD/.claude/skills"

if [ -z "$AVAILABLE_SKILLS" ]; then
	AVAILABLE_SKILLS="No skills found"
fi

# Fallback
FALLBACK_INSTRUCTION="INSTRUCTION: If the prompt matches any available skill keywords, use Skill(skill-name) to activate it."

# If no API key, fall back
if [ -z "$ANTHROPIC_API_KEY" ]; then
	echo "$FALLBACK_INSTRUCTION"
	exit 0
fi

# Evaluation prompt
EVAL_PROMPT=$(cat <<EOF
Return ONLY a JSON array of skill names that match this request.

Request: ${USER_PROMPT}

Skills:
${AVAILABLE_SKILLS}
Format: ["skill-name"] or []
EOF
)

# Call Claude API
RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
	-H "content-type: application/json" \
	-H "x-api-key: $ANTHROPIC_API_KEY" \
	-H "anthropic-version: 2023-06-01" \
	-d "{
		\"model\": \"$MODEL\",
		\"max_tokens\": 200,
		\"temperature\": 0,
		\"system\": \"You are a skill matcher. Return only valid JSON arrays.\",
		\"messages\": [{
			\"role\": \"user\",
			\"content\": $(echo "$EVAL_PROMPT" | jq -Rs .)
		}]
	}")

# Extract skill list
RAW_TEXT=$(echo "$RESPONSE" | jq -r '.content[0].text' 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$RAW_TEXT" ]; then
	echo "$FALLBACK_INSTRUCTION"
	exit 0
fi

# Strip markdown code fences if present
SKILLS=$(echo "$RAW_TEXT" | sed -n '/^\[/,/^\]/p' | head -n 1)

if [ -z "$SKILLS" ]; then
	SKILLS="$RAW_TEXT"
fi

# Parse the skills array
SKILL_COUNT=$(echo "$SKILLS" | jq 'length' 2>/dev/null)

if [ "$SKILL_COUNT" = "0" ]; then
	echo "INSTRUCTION: LLM evaluation determined no skills are needed for this task."
elif [ -n "$SKILL_COUNT" ] && [ "$SKILL_COUNT" != "null" ]; then
	SKILL_NAMES=$(echo "$SKILLS" | jq -r '.[]' | paste -sd ',' -)
	echo "INSTRUCTION: LLM evaluation determined these skills are relevant: $SKILL_NAMES"
	echo ""
	echo "You MUST activate these skills using the Skill() tool BEFORE implementation:"
	echo "$SKILLS" | jq -r '.[] | "- Skill(\(.))"'
else
	echo "$FALLBACK_INSTRUCTION"
fi
