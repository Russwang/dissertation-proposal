# Agent 工作说明

## 仓库定位

本目录用于 `MetricDB / Metric Databases: Towards Embedding-independent Vector Search` 的 proposal、文献整理和写作辅助。当前个人聚焦方向是：

- `From Vector Indexing to Metric Indexing`

## 默认工作流

- 涉及论文 PDF、文本缓存、单篇摘要或文献总览时，优先使用 `skills/literature-ingest/`。
- 写作或回顾时，默认先读 `paper_summaries/`，不够再读 `pdf_text_cache/`，最后才回 PDF。
- 新文献统一按四层结构维护：
  - `papers/`
  - `pdf_text_cache/`
  - `paper_summaries/`
  - `文献索引与分类总览.md`

## 写作与修改规则

- 先明确本轮修改的目标章节、要解决的问题、证据来源和完成判据，再动手写。
- 不得编造引用或文献结论；任何文献性表述都必须能追溯到摘要、缓存或原文。
- 先做 claim-to-source mapping，再补引用；不要先堆论文名。
- 只改当前任务直接涉及的内容，避免顺手重写相邻章节、术语或格式。
- 明确区分三类表述：文献事实、你的推断、proposal 计划。
- 优先完成当前最小闭环，不无边界扩展任务范围。

## Proposal 导航规则

- proposal 相关工作默认以 `Proposal结构复核清单.md` 作为主导航。
- 每次实质性修改后，检查是否需要同步更新：
  - `Proposal结构复核清单.md`
  - `文献索引与分类总览.md`
  - 当前任务直接涉及的规划文件

目标是让 `proposal 正文`、`文献体系` 和 `结构清单` 保持一致。
