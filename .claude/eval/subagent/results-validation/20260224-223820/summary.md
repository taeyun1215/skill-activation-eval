# Phase 2: Subagent Validation Results

- **Date**: 2026-02-24 22:38:20
- **Model**: sonnet
- **Rounds**: 1
- **Test Cases**: 20
- **Configs**: tag-instruction
- **Hooks**: none
- **Tools**: unrestricted (all tools available)
- **Execution**: sequential
- **Key diff from Phase 1**: `--allowedTools` not set → model can skip Skill

### tag-instruction (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 100% (1/1) |
| Activation Rate | 100% |
| Missed | 0 |
| False Positive | 0 |
| Wrong Skill | 0 |
| Tag Followed | 1/1 (100%) |
| Skipped Skill (used other tools) | 0 |

---
## Summary (Average)
| Config | Accuracy | Activation | Missed | FP | Wrong |
|--------|----------|------------|--------|----|-------|
| tag-instruction | 100% | 100% | 0 | 0 | 0 |
