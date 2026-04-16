---
id: TASK-33
title: Split Format.ex by concern + optimize formatting hot loops
status: To Do
assignee: []
created_date: '2026-04-16 19:20'
labels:
  - elixir
  - refactor
  - perf
dependencies: []
references:
  - lib/frontend_ex/format.ex
priority: low
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Format module split into Format.Number, Format.Time, Format.Address, Format.Amount (or similar)
- [ ] #2 format_number_with_commas and related avoid triple Enum.reverse; implement via tail-recursive accumulator or single IO-list pass
- [ ] #3 Benchmark shows no regression (format_number_with_commas on 50-digit integer, format_method_name on typical inputs)
- [ ] #4 Golden parity tests still pass
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Format.ex is 517 LOC, mixes concerns. format_number_with_commas (format.ex:256-261, 276-281) reverses lists 3x; format_method_name (format.ex:122-170) allocates intermediate lists per grapheme.
<!-- SECTION:NOTES:END -->
