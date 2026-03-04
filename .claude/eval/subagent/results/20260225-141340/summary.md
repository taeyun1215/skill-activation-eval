# Subagent Skill Activation Eval Results

- **Date**: 2026-02-25 14:13:40
- **Model**: sonnet
- **Rounds**: 1
- **Test Cases**: 20
- **Configs**: tag tag-instruction inline-forced-eval
- **Hooks**: none (prompt prefix only)
- **Execution**: parallel

### tag (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 60% (12/20) |
| Activation Rate | 60% |
| Missed | 8 |
| False Positive | 0 |
| Wrong Skill | 0 |
| Tag Followed | 8/16 (50%) |

### tag-instruction (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 75% (15/20) |
| Activation Rate | 75% |
| Missed | 5 |
| False Positive | 0 |
| Wrong Skill | 0 |
| Tag Followed | 11/16 (68%) |

### inline-forced-eval (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 80% (16/20) |
| Activation Rate | 80% |
| Missed | 4 |
| False Positive | 0 |
| Wrong Skill | 0 |
| Tag Followed | 12/16 (75%) |

---
## Summary (Average)
| Config | Accuracy | Activation | Missed | FP | Wrong |
|--------|----------|------------|--------|----|-------|
| tag | 60% | 60% | 8 | 0 | 0 |
| tag-instruction | 75% | 75% | 5 | 0 | 0 |
| inline-forced-eval | 80% | 80% | 4 | 0 | 0 |
