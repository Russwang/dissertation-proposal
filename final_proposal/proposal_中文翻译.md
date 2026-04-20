# MetricDB 中用于统一检索的向量索引转换与合并

作者：Russ Wang  
日期：2026 年 4 月

## 摘要

向量数据库现在被广泛用于语义检索、信息抽取、推荐系统和生成式 AI 系统。大多数向量数据库都围绕一个特定的 embedding model 构建，因此由不同模型生成的向量通常不能直接比较，也不能直接放在一起查询。MetricDB 希望解决这个限制。它从依赖单一模型的向量空间，转向一个支持跨 embedding model 统一检索的 shared metric view。

本 proposal 关注的是向量数据库已经被对齐或转换到 shared space 之后的 indexing problem。一个简单的 baseline 是丢弃已有的 local indices，然后在 aligned and unioned vector set 上重新构建一个新的 HNSW index。这个 baseline 很重要，但它也有局限。它忽略了原始向量数据库中可能已经存在的 index structures。当新的数据库被接入时，它也可能需要反复做完整的重建。

本项目的主要关注点是 index reuse。项目从对齐之前已经构建好的 local vector indices 开始，尤其是构建在不同 vector subsets 上的 HNSW indices。项目将研究如何把这些 indices 转换、修复并合并成一个 valid vector index，使它能够覆盖 transformed vectors 的 union。HNSW 会作为主要 case study，FAISS 会作为优先考虑的 implementation backend。 proposed method 会和 brute-force search 以及 HNSW rebuild baseline 进行比较。预期产出包括一个 prototype、一组关于 retrieval quality 和 system cost 的评估，以及对什么时候应该复用 index、什么时候应该从头 rebuild 的分析。

## 1. Motivation

向量数据库已经成为现代数据系统的重要组成部分。语义搜索、文档问答、推荐系统和多模态信息管理都越来越依赖 embedding vectors 来表示相似性。FAISS 展示了 similarity search 如何扩展到大规模向量集合。Lucene-based vector search 展示了向量检索如何进入成熟的搜索基础设施。Predicate-aware vector search 则展示了向量相似性如何和结构化过滤结合起来。

当前的向量数据库仍然有一个基本限制：每个数据库通常围绕一个 embedding model 构建。因此，不同模型产生的向量位于不同空间中，不能直接比较。已有的 cross-space alignment 工作表明，不同 embedding spaces 有时可以通过 learned mappings 联系起来。Representation convergence 方面的工作也给出了更广泛的动机，说明不同 representation spaces 之间可能存在共享结构。MetricDB 在数据库场景下研究这个问题，关注如何把基于不同 embedding models 的 vector databases 集成到 shared metric view 中。

当 vectors 可以被转换到 shared space 后，第二个问题就出现了。系统可以形成一个 aligned and unioned vector set，然后重建一个新的 vector index。这是自然的 baseline。但是在真实系统中，原始 vector databases 可能已经有 local indices。直接丢弃这些 indices 可能会造成浪费，尤其是当数据库很大、数据库是增量加入的，或者不同数据库独立更新时。因此，这个 proposal 关注的问题是：alignment 之后，local vector indices 是否可以被复用。

## 2. Background and Corresponding Work

### 2.1 Vector Indices and ANN Search

HNSW 是一种 graph-based approximate nearest-neighbour index。它使用 navigable small-world graph 来支持高维向量空间中的高效搜索。FAISS 是一个广泛使用的大规模 similarity search 框架，支持 HNSW、IVF 和 product quantization 相关的 indices。这些系统是 single-space vector search 的重要基础。在这些场景中，index 通常直接构建在一个 vector collection 上。

IVF 也相关，因为它是 approximate search 中一种基于 partition 的方法。本项目会聚焦 HNSW，因为 graph links 让 conversion and merging problem 变得更具体。Local neighbourhood edges 可以被保留、测试、修复，或者跨数据库连接。IVF 会作为 related work 和 future extension 讨论，而不是作为必须实现的目标。

### 2.2 Vector Databases, Filtering, and System Integration

现代 vector retrieval systems 很少只是孤立的 nearest-neighbour algorithms。Lucene-based vector search 展示了 vector search 如何和成熟搜索基础设施结合。ACORN 研究了当 vector similarity 和 structured predicates 一起使用时，如何进行高效搜索。这对 MetricDB 很重要，因为 index module 最终要服务于更大的 query flow，而不仅仅是一个 standalone benchmark。

### 2.3 Embedding Alignment and MetricDB

本项目假设 upstream components 或已有 alignment methods 可以提供到 shared space 的 transformations。Unsupervised word translation 表明，embedding spaces 可以在没有 parallel data 的情况下被对齐。Platonic Representation Hypothesis 为不同 representation spaces 可能共享结构提供了更广泛的动机。MetricDB 直接研究跨 embedding models 的 vector database integration，也是本 proposal 的主要背景。

### 2.4 Metric-Space and Graph-Based Indexing

本 proposal 使用 vector index 这个术语来指代 HNSW 和 IVF 这样的具体 ANN structures。它也和更广义的 metric-space indexing 相关。经典的 metric-space search 工作为基于 distance functions 的 similarity search 提供了一般背景。后续工作研究了 exact metric-space indexing、pivot selection、learned metric indices、graph-based methods 和 distributed metric indices。这些工作共同说明，在 shared distance space 下做 indexing 是一个真实的研究问题。本项目的具体贡献更窄：研究 alignment 之后如何复用和合并 local vector indices。

下一节把上述动机转化为具体的问题定义。

## 3. Problem Definition

### 3.1 Core Problem

本项目研究如下问题：

> 给定多个 vector databases，假设它们的 embedding vectors 可以被转换到一个 shared space。每个数据库可能已经有一个 local vector index，例如 HNSW 或 IVF index。我们如何把这些 local indices 转换、修复并合并成一个 valid vector index，使它能够覆盖 transformed vectors 的 union？

为了让实现范围可控，HNSW 会作为主要实现目标。

Baseline 很直接：把所有 vectors 转换到 shared space，形成 aligned and unioned vector set，然后调用 off-the-shelf HNSW implementation 从头构建一个新的 index。这个 baseline 很重要，因为它给出了 fully rebuilt index 的 retrieval quality 和 query performance。 proposed research 关注的是：reuse-based route 是否能够接近这个质量，同时降低 construction 或 integration cost。

在本 proposal 中，一个 valid union-level vector index 需要满足三个要求。它要支持在所有 transformed vectors 上做 nearest-neighbour search；它要返回具有全局意义的 item identifiers；它还要能够和 brute-force ground truth 以及 HNSW rebuild baseline 进行比较。对于 prototype，validity 会通过 union-level search behaviour、recall@k、query latency、construction or merge cost，以及跨原始 vector subsets 的 retrieval 来评估。

### 3.2 Inputs, Outputs, and Constraints

从系统角度看，本项目可以概括为：

- **Inputs:** 原始 vector subsets、到 shared space 的 transformations、已有 local HNSW indices 或 HNSW-derived neighbourhood structures，以及来自 upstream modules 的 optional anchor or alignment information。
- **Baseline output:** 一个直接在 aligned and unioned vector set 上重建的 HNSW index。
- **Proposed output:** 一个通过转换、修复和合并 local index structures 产生的 union-level vector index。
- **Constraints:** 和 MetricDB code skeleton 兼容；能够在项目周期内实现；评估 retrieval quality、construction cost 和 query cost。

### 3.3 Research Scope and Module Responsibility

在 MetricDB 中，本项目负责 indexing layer，而不是完整的 cross-database alignment pipeline。项目假设 transformations、alignment results 或 anchors 由 upstream components、已有方法或 controlled synthetic experiments 提供。项目的主要职责是研究 indexing layer 应该如何使用这些输入。

这个范围和当前的 `metricdb` skeleton 对齐。Indexing module 需要通过 shared index interface 暴露 `build` 和 `search` 行为，并为 downstream search modules 返回 candidate item identifiers。项目会保持和这个 interface 的兼容，但研究贡献不是简单包装一个已有 HNSW library。核心贡献是 transformation 之后 local index structures 的 conversion、repair 和 merging。

## 4. Research Goals and Research Questions

### 4.1 Research Goals

总体目标是为 MetricDB 设计并评估一种 reuse-based vector indexing method。项目不是只把 aligned and unioned vector set 看作一个新的 fresh dataset，而是研究原始 vector databases 中的 local index structures 是否可以被带入 shared space 继续使用。

具体目标包括：

1. 建立一个在 aligned and unioned vector set 上的 HNSW rebuild baseline。
2. 研究 local HNSW neighbourhood structures 在 vector transformation 之后的表现。
3. 设计 transformed space 中 local graph links 的 conversion and repair strategy。
4. 设计一种 merge strategy，在 local structures 之间加入 cross-index links。
5. 使用 HNSW 作为主要 case study，并优先考虑 FAISS 作为 backend，实现一个 prototype。
6. 将 proposed method 和 brute-force search、HNSW rebuild baseline 进行比较。

### 4.2 Research Questions

本项目围绕以下 research questions 展开：

1. Local HNSW neighbourhood structure 在 vectors 被转换到 shared space 之后，还有多少是有用的？
2. 当 transformed local links 不再代表 shared space 中的 good neighbours 时，应该如何修复？
3. 应该如何加入 cross-index links，使分开的 local structures 可以作为一个 union-level index 被搜索？
4. 和在 aligned and unioned vector set 上从头 rebuild HNSW 相比，reuse-based method 会带来怎样的 quality and cost trade-offs？

## 5. Timeliness, Significance, Feasibility, and Beneficiaries

### 5.1 Timeliness and Novelty

本项目具有及时性，因为 vector databases 正在成为标准基础设施，而 multi-model 和 multi-source embeddings 也越来越常见。已有 vector search systems 已经很成熟，但它们通常假设一个 single vector space 和一个建立在单一 collection 上的 index。MetricDB 改变了这个设定，使 cross-embedding retrieval 成为显式问题。在这个设定下，新问题不是简单地构建另一个 vector index，而是如何在 vectors 被 transformed 之后复用和合并已有 local indices。

### 5.2 Significance

本项目的意义在于 integration 和 indexing 之间的 gap。Alignment 可以让 vectors 变得可比较，但它本身并不提供一个覆盖 transformed vectors union 的高效 index。Rebuilding 是显然的 baseline。当 vector databases 已经维护 local indices，或者新的 databases 需要被增量接入时，reuse-based method 可能更有吸引力。

### 5.3 Feasibility

本项目可行有三个原因。第一，它有清楚的 baseline。第二，它聚焦在一个主要 index structure 上。第三，它有一个边界清楚的 implementation target。HNSW 提供了一个具体的 graph-based object，可以用来研究 conversion and merging。FAISS 会作为 preferred backend 被研究，因为它支持 HNSW-based indexing，并且可能提供对本项目有用的 graph-level structures 或 search functionality。如果 direct graph-level manipulation 太复杂，prototype 会使用 HNSW-derived neighbourhood graph。这个 graph 可以通过 local index queries 构造，并用于评估 conversion、repair 和 merging。

### 5.4 Beneficiaries

直接受益者是研究 MetricDB 和 cross-embedding retrieval 的 researchers and developers。更广泛地说，本项目也可以帮助 enterprise search、multimodal retrieval 和 multi-model vector database systems 的开发者判断什么时候 local indices 可以复用，什么时候 full rebuilding 是更好的工程选择。

## 6. Methodology

### 6.1 Overall Approach

本项目采用 baseline-plus-proposed-method 的结构。Baseline 在 aligned and unioned vector set 上重建 HNSW index。Proposed method 从构建在原始 vector subsets 上的 local HNSW indices 或 HNSW-derived neighbourhood structures 开始。然后，它把 vectors 转换到 shared space，修复 local graph links，并加入 cross-index links。最终结果是一个 union-level searchable structure。

### 6.2 Baseline: HNSW Rebuild over the Unioned Vector Set

Baseline 首先对每个 vector subset 应用已有 transformations，然后把 transformed vectors 拼接成一个 aligned and unioned vector set。一个标准 HNSW implementation 会在这个完整集合上构建新的 index。这条路线忽略了原始 local indices，但它为 recall、query latency、build time、memory 或 graph size 提供了强对比点。

### 6.3 Proposed Method: Convert, Repair, and Merge

Proposed method 围绕三个步骤展开。

1. **Convert.** 每个 local index 通过对其 vectors 应用相应 transformation，被移动到 shared space。Local neighbourhood structure 会作为初始 graph representation 被保留。
2. **Repair.** Local graph links 会在 transformed space 中被重新评估。仍然连接 close neighbours 的 links 可以被保留，而 weak or distorted links 可以用 transformed vectors 中的 local candidate search 来替换。
3. **Merge.** 在 local structures 之间加入 cross-index links，使 search 可以跨 vector subsets 移动。Candidate cross links 可以来自 anchors、sampled cross-neighbour searches，或者 transformed subsets 之间的 nearest neighbours。

预期结果是一个 union-level graph-based vector index，它的行为可以被直接评估。它应该能够在 transformed vector union 上搜索，返回 global item identifiers，支持 cross-subset retrieval，并且在 retrieval quality 和 construction cost 上与 HNSW rebuild baseline 进行公平比较。

### 6.4 Implementation Procedure

Prototype 会通过六个步骤把 convert-repair-merge method 落地。

1. **Prepare transformed vectors.** 对每个 vector subset \(D_i\)，prototype 会应用已有 transformation \(T_i\)，把 vectors 映射到 shared space。每个 vector 也会被分配一个 global item identifier。
2. **Obtain local HNSW graph information.** 首选路线是复用 local HNSW backend 暴露出的 graph links。如果这条路线不实际可行，项目会研究 FAISS 是否提供 Python-level 的方式来访问有用的 HNSW graph information。如果 direct graph manipulation 技术成本太高，prototype 会查询每个已有 local HNSW index 中每个 vector 的 neighbours，并用结果构建 HNSW-derived local neighbourhood graph。
3. **Convert local graphs.** Local graph topology 会和 transformed vectors 一起被带入 shared space。Local node identifiers 会被映射到 global item identifiers。在这个阶段，graph 仍然只包含 within-subset links。
4. **Repair within-subset links.** 已有 links 会使用 transformed space 中的 distances 或 ranks 重新评估。Weak or distorted links 指的是 transformation 之后不再连接 close neighbours 的 links。这些 links 可以被删除、降级，或者使用同一 transformed subset 中的 candidate neighbours 替换。
5. **Add cross-subset links.** Prototype 会在不同 local graphs 之间加入 links。Candidate cross-subset links 可以来自 anchors、sampled nodes，或者 transformed subsets 之间的 nearest-neighbour search。这些 links 让 search 可以从一个原始 database 移动到另一个 database。
6. **Search the merged structure.** Query 会被表示在 shared space 中，并在 merged graph 上搜索。Search 会遍历 repaired local links 和 cross-subset links，然后返回 global item identifiers。

这个 procedure 不假设 merged graph 必须总是超过 fully rebuilt HNSW index。它提供的是一个具体方式，用来研究 retrieval quality 和 construction or integration cost 之间的 trade-off。

### 6.5 Implementation Backend

HNSW 会作为主要 case study，因为它把 index reuse 表达成一个 graph problem。FAISS 会作为 preferred implementation backend 被研究，因为它支持标准 HNSW rebuilding，并且可能提供 proposed method 所需的 graph-level structures 或 search functionality。如果可用的 FAISS interface 不足以支持 direct graph-level manipulation，项目会通过查询 local indices 构造 HNSW-derived neighbourhood graph。这个 graph 会用于评估 conversion、repair 和 merging。

### 6.6 System Integration

Prototype 会保持和 MetricDB indexing boundary 的兼容。Search results 应该以 global item identifiers 的形式返回，使 downstream query 或 predicate modules 可以使用它们。本项目不要求完整完成 union-management 或 entity-linking modules。相反，它会把 transformations 和 optional anchors 作为输入，并聚焦于 index-level integration problem。

### 6.7 Risks and Mitigation

主要风险如下：

1. **Graph-level API risk.** 一些 HNSW libraries 暴露 build 和 query operations，但不暴露 direct graph editing。缓解方式是优先考虑 FAISS，并保留 HNSW-derived neighbourhood graph representation 作为 fallback。
2. **Overly broad index scope.** HNSW 和 IVF 都相关。如果两个都实现，项目范围会过大。缓解方式是实现 HNSW，并把 IVF 作为 related work 和 future extension。
3. **Alignment dependency.** 项目依赖 transformed vectors，但不实现完整 alignment pipeline。缓解方式是假设 upstream transformations，或者在 evaluation 中使用 controlled synthetic transformations。
4. **Quality-cost trade-off.** Merged graph 可能构造成本更低，但 recall 更低。缓解方式是同时对 quality 和 cost 进行评估，并和 HNSW rebuild baseline 比较。

## 7. Evaluation Plan

评估会比较三条路线。

1. **Brute-force search** over the transformed vector union，用作 nearest-neighbour quality 的 ground truth。
2. **HNSW rebuild baseline** over the aligned and unioned vector set，用作主要 practical baseline。
3. **Proposed merged method**，由 local HNSW 或 HNSW-derived structures 经过 conversion、repair 和 merging 产生。

### 7.1 Retrieval Quality

Retrieval quality 会使用 top-k agreement 或 recall@k against brute-force ground truth 来衡量。与 HNSW rebuild baseline 的比较会说明 reuse 是否损失 retrieval quality。Evaluation 也会检查 cross-subset retrieval，因为 union-level index 应该能够跨原始 vector subsets 检索 neighbours。

### 7.2 System Cost

System cost 会关注 build time versus merge time、query latency，以及 practical 情况下的 index size 或 graph size。核心比较有两部分。第一，merged method 是否能正确搜索？第二，和在完整 aligned and unioned vector set 上 rebuild HNSW 相比，它是否提供了有意义的 construction 或 integration-cost advantage？

### 7.3 Ablation and Sensitivity

如果时间允许，项目会对 repair 和 cross-link strategies 做小规模 ablations。例如，evaluation 可以比较三种 variants：不做 repair 的 local links、只做 repair 但没有 cross-index links、完整的 convert-repair-merge pipeline。这些 ablations 可以帮助解释 proposed method 中哪一部分对 retrieval quality 贡献最大。

## 8. Expected Outcomes

本项目的预期产出包括：

1. 一个在 aligned and unioned transformed vectors 上的 HNSW rebuild baseline。
2. 一个用于 HNSW index conversion、repair 和 merging 的 prototype。
3. 一个比较 brute-force search、rebuild baseline 和 proposed merged method 的 evaluation。
4. 一份分析，说明什么时候 local index reuse 有价值，什么时候 full rebuilding 更合适。
5. dissertation/report 的基础内容，包括 method、experiments、limitations，以及 IVF 等 future extensions。

## 9. Timeline, Milestones, and Deliverables

这个 proposal 会在正式项目执行前完成。下面的十周计划描述 proposal 被确认之后的 implementation period。

### Phase 1: Baseline and Backend Study (Weeks 1--2)

第一阶段会设置 transformed-vector test data，实现 HNSW rebuild baseline，确认 FAISS 或 HNSW backend route，并定义具体 evaluation metrics。

Deliverables:

- aligned and unioned vector set 上的 HNSW rebuild baseline
- confirmed backend choice and graph-representation plan
- brute-force ground truth setup
- recall、latency 和 construction cost 的 experimental protocol

### Phase 2: Convert and Repair Prototype (Weeks 3--4)

第二阶段会构造 local HNSW 或 HNSW-derived neighbourhood structures，把 vectors 转换到 shared space，并实现第一个 local graph links repair strategy。

Deliverables:

- local index conversion procedure
- transformed-space link evaluation
- initial repair strategy and diagnostic results

### Phase 3: Merge Prototype and Integration (Weeks 5--6)

第三阶段会加入 cross-index links，并在 merged structure 上实现 union-level graph search。它也会让 output identifiers 和 MetricDB indexing interface 对齐。

Deliverables:

- cross-index link construction method
- union-level merged graph prototype
- 使用 global item identifiers 的 search output

### Phase 4: Evaluation (Weeks 7--8)

第四阶段会比较 brute-force search、HNSW rebuild 和 proposed merged method。重点是 recall@k、query latency、construction or merge time，以及 graph or index size。

Deliverables:

- retrieval-quality results
- build-versus-merge cost results
- cross-database retrieval behaviour 的分析
- repair 和 cross-link choices 的 optional ablation results

### Phase 5: Dissertation Writing and Final Consolidation (Weeks 9--10)

最后阶段会整合结果，准备 figures and tables，并撰写 dissertation/report 中的 background、methodology、evaluation、limitations 和 future extensions。

Deliverables:

- draft dissertation/report chapters
- final result figures and tables
- 和 proposal 对齐的 final project materials

## 10. Conclusion

本项目研究如何为 MetricDB 中的 unified retrieval 转换和合并已有 local vector indices。Baseline 是在 aligned and unioned vector set 上从头 rebuild HNSW。主要研究贡献是，在 vector transformation 之后，对 local HNSW index structures 进行 conversion、repair 和 connection。结果应该是一个覆盖 transformed vectors union 的 valid vector index。Evaluation 会将 retrieval quality 和 system cost 与 brute-force search 以及 HNSW rebuild baseline 进行比较。这个比较会说明什么时候 index reuse 是 practical 的，什么时候 full rebuilding 仍然是更好的选择。
