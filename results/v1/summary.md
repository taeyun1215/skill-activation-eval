# Skill Activation Eval Results

- **Date**: 2026-02-24 12:10:33
- **Model**: sonnet
- **Rounds**: 2
- **Test Cases**: 20
- **Configs**: none simple forced-eval llm-eval
- **Execution**: sequential

### none (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 50% (10/20) |
| Activation Rate | 50% |
| Missed | 10 |
| False Positive | 0 |
| Wrong Skill | 0 |

### simple (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 60% (12/20) |
| Activation Rate | 60% |
| Missed | 8 |
| False Positive | 0 |
| Wrong Skill | 0 |

### forced-eval (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 100% (20/20) |
| Activation Rate | 100% |
| Missed | 0 |
| False Positive | 0 |
| Wrong Skill | 0 |

### llm-eval (R1)
| Metric | Value |
|--------|-------|
| Accuracy | 65% (13/20) |
| Activation Rate | 65% |
| Missed | 7 |
| False Positive | 0 |
| Wrong Skill | 0 |

### none (R2)
| Metric | Value |
|--------|-------|
| Accuracy | 55% (11/20) |
| Activation Rate | 55% |
| Missed | 9 |
| False Positive | 0 |
| Wrong Skill | 0 |

### simple (R2)
| Metric | Value |
|--------|-------|
| Accuracy | 55% (11/20) |
| Activation Rate | 55% |
| Missed | 9 |
| False Positive | 0 |
| Wrong Skill | 0 |

### forced-eval (R2)
| Metric | Value |
|--------|-------|
| Accuracy | 100% (20/20) |
| Activation Rate | 100% |
| Missed | 0 |
| False Positive | 0 |
| Wrong Skill | 0 |

### llm-eval (R2)
| Metric | Value |
|--------|-------|
| Accuracy | 65% (13/20) |
| Activation Rate | 70% |
| Missed | 6 |
| False Positive | 0 |
| Wrong Skill | 1 |

---
## Summary (Average)
| Config | Accuracy | Activation | Missed | FP | Wrong |
|--------|----------|------------|--------|----|-------|
| none | 52% | 52% | 9 | 0 | 0 |
| simple | 57% | 57% | 8 | 0 | 0 |
| forced-eval | 100% | 100% | 0 | 0 | 0 |
| llm-eval | 65% | 67% | 6 | 0 | 0 |
