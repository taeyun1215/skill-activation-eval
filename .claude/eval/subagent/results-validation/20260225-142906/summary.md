# Phase 2: Subagent Validation Results

- **Date**: 2026-02-25 14:29:06
- **Model**: sonnet
- **Rounds**: 1
- **Test Cases**: 20
- **Configs**: tag tag-instruction inline-forced-eval
- **Hooks**: none
- **Tools**: unrestricted (all tools available)
- **Execution**: parallel
- **Key diff from Phase 1**: `--allowedTools` not set → model can skip Skill

### tag (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 70% (14/20) |
| Activation Rate | 70% |
| Missed | 6 |
| False Positive | 0 |
| Wrong Skill | 0 |
| Tag Followed | 10/16 (62%) |
| Skipped Skill (used other tools) | 5 |

### tag-instruction (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 70% (14/20) |
| Activation Rate | 70% |
| Missed | 6 |
| False Positive | 0 |
| Wrong Skill | 0 |
| Tag Followed | 10/16 (62%) |
| Skipped Skill (used other tools) | 6 |

### inline-forced-eval (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 80% (16/20) |
| Activation Rate | 80% |
| Missed | 4 |
| False Positive | 0 |
| Wrong Skill | 0 |
| Tag Followed | 12/16 (75%) |
| Skipped Skill (used other tools) | 4 |

---
## Summary (Average)
| Config | Accuracy | Activation | Missed | FP | Wrong |
|--------|----------|------------|--------|----|-------|
| tag | 70% | 70% | 6 | 0 | 0 |
| tag-instruction | 70% | 70% | 6 | 0 | 0 |
| inline-forced-eval | 80% | 80% | 4 | 0 | 0 |
