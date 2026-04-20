---
name: literature-ingest
description: Use when working on the dissertation project and the task involves papers, PDFs, literature summaries, pdf_text_cache, paper_summaries, or 文献索引与分类总览.md. Prefer this skill over generic paper-reading workflows whenever the current task belongs to the dissertation repo. This skill covers the standard workflow for paper ingestion and project-specific literature organization in the dissertation workspace.
---

# Literature Ingest

Use this skill when the task is about adding a new paper into this dissertation workspace. Keep the workflow light and deterministic: cache text once, summarize once, then reuse the summary in later writing tasks.

If the current work belongs to the dissertation repo, prefer this skill over the global `paper-ingest` skill. The global skill is only the fallback for cross-project or non-project-specific paper handling.

## Workflow

1. Place the PDF in the appropriate source directory, usually `papers/` or `papers/supplemental/`.
2. Mirror that relative path under `pdf_text_cache/` and extract the PDF into a `.txt` cache if the cache is missing.
3. Write one Chinese summary file under `paper_summaries/`.
4. Update `文献索引与分类总览.md` with the paper's category, purpose, and path when the user is building or maintaining the literature map.
5. For later writing tasks, read `paper_summaries/` first, then `pdf_text_cache/`, and only return to the PDF when context is missing.

## Extraction Rules

- Prefer the repository script:

```bash
swift -module-cache-path /tmp/swift-module-cache \
  tools/extract_pdf_text.swift INPUT_PDF OUTPUT_TXT
```

- The `-module-cache-path /tmp/swift-module-cache` flag is required in this environment.
- Reuse existing cache files instead of re-extracting unless the cache is missing, corrupted, or the user explicitly wants a refresh.
- When inspecting cache text, prefer `rg`, `sed`, and `tr -d '\000'`.

## Summary Rules

- Create one standalone Chinese summary per paper in `paper_summaries/`.
- Keep the summary oriented toward proposal use, not just generic paper notes.
- Use the template in `references/summary_template.md`.
- If the paper is only partially relevant, state the boundary clearly so later writing does not overclaim.

## Decision Rules

- If the user asks to "read", "digest", or "summarize" a paper that is already in the repo, do not start from the PDF if a cache and summary already exist.
- If the user asks to support proposal writing, prefer citing the existing summary and read the cache only for missing evidence.
- If the user asks to add many PDFs, batch extraction is acceptable, but summaries should still be produced per paper.

## Files To Touch

- PDF originals: `papers/` or another user-specified source folder
- Text cache: `pdf_text_cache/`
- Per-paper summaries: `paper_summaries/`
- Literature map: `文献索引与分类总览.md`

Read `references/summary_template.md` when you need the exact summary structure or naming convention.
