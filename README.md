# Dissertation Proposal Workspace

This repository contains the working materials for my dissertation proposal on MetricDB:

**Transforming and Merging Vector Indices for Unified Retrieval in MetricDB**

The proposal focuses on reusing existing local vector indices after embedding spaces have been aligned. The main research direction is to transform, repair, and merge local HNSW index structures into a valid vector index over the union of transformed vectors. Rebuilding HNSW over the aligned and unioned vector set is treated as the baseline.

## Repository Structure

- `final_proposal/`
  - `main.tex`: final English LaTeX proposal source
  - `references.bib`: BibTeX references used by the proposal
  - `proposal_中文翻译.md`: Chinese translation for review and explanation
- `docs/proposal/`: proposal drafts, feedback notes, revision plans, and structure checks
- `docs/metricdb/`: notes on MetricDB module responsibilities, interfaces, and code structure
- `PROJECT_REQUIREMENTS.md`: original project requirement document
- `AGENT.md`: local workflow notes for this workspace
- `skills/` and `tools/`: lightweight helper workflow files and scripts

## What Is Not Included

Large or reference-only materials are intentionally excluded from this GitHub repository:

- paper PDFs
- IPP example PDFs
- extracted PDF text caches
- paper summaries
- Obsidian vault files
- LaTeX build outputs such as `.aux`, `.log`, and `.pdf`

These files remain local and are excluded through `.gitignore`.

## Current Proposal Direction

The proposal responds to the concern that simply rebuilding a vector index over the unioned dataset is too small as a thesis contribution. The revised direction makes index reuse the main contribution:

1. Build an HNSW rebuild baseline over the aligned and unioned vector set.
2. Reuse local HNSW indices or HNSW-derived neighbourhood graphs.
3. Convert local graph structures after vector transformation.
4. Repair distorted within-subset links in the transformed space.
5. Add cross-subset links to merge local structures.
6. Evaluate retrieval quality and construction cost against brute-force search and the rebuild baseline.

## Status

The proposal draft is ready for supervisor review.
