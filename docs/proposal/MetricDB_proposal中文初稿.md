# From Vector Indexing to Metric Indexing in MetricDB

## 摘要

随着向量数据库在语义检索、信息抽取和生成式人工智能系统中的广泛应用，越来越多的数据被存储在由不同 embedding 模型生成的向量空间中。然而，现有向量数据库通常与具体 embedding 模型强绑定，导致来自不同模型、不同数据库的向量难以直接比较，也难以进行统一查询。Yang、Cao 和 Ren 关于跨 embedding 模型整合向量数据库的工作直接指出，这种绑定关系使向量数据库失去了类似传统数据库那样的数据共享与联合检索能力。MetricDB 项目的总体目标正是打破这种绑定关系，使逻辑上的相似性与物理上的向量表示解耦，从而支持跨 embedding 模型的统一检索。

在这一整体目标下，本 proposal 聚焦于 `From Vector Indexing to Metric Indexing` 这一子方向，研究在异构向量数据库已经可以被整合到统一 metric 视图之后，如何进一步构建高效的索引结构，以支持实际可用的近邻搜索。本文将首先界定该问题的研究边界，随后围绕两条可能的技术路线展开：一条是对整合后的数据重建 metric index，另一条是对已有 vector index 进行转换和合并。考虑到项目周期与实现可行性，本研究将优先推进前一条主线，并将后一条路线保留为扩展方向。

本 proposal 的目标不是立即完成全部系统实现，而是提出一套清晰、可落地、可评估的研究计划。在未来 10 周的项目实施中，本研究将优先完成一个可运行、可评估的 metric indexing 原型，并据此建立基础 benchmark，分析其在统一 metric 视图下的正确性、效率与局限性，在时间允许的前提下再进一步探索索引转换与合并的可行路径。预期产出包括一个原型索引模块、一套覆盖准确性与效率的评估方案，以及对两条索引路线优缺点的系统分析。这项研究将为 MetricDB 从概念验证走向系统可用性提供关键支撑。

## 1. 研究背景与动机

近年来，向量数据库已经成为现代数据系统的重要组成部分。无论是语义检索、推荐系统、文档问答，还是多模态信息管理，都越来越依赖 embedding 向量来表示对象之间的相似关系。Milvus、pgvector、Pinecone 等系统的流行，说明向量检索已经从研究问题逐渐转变为工程基础设施。与此同时，Johnson、Douze 和 Jegou 关于 FAISS 的工作展示了十亿级相似搜索的系统实现路径，而 Lin 等人基于 Lucene 的案例进一步说明，向量搜索能力已经可以被整合进成熟搜索基础设施之中。

然而，这类系统目前仍然存在一个根本限制：每个向量数据库通常都建立在某一特定 embedding 模型上，因此它们的向量空间彼此割裂。由不同模型生成的向量通常不能直接比较，也就无法自然地进行跨数据库的联合检索。换句话说，当前的向量数据库更像是多个彼此隔离的数据孤岛。

MetricDB 所要解决的核心问题是：能否将这种“绑定于 embedding 模型的向量数据库”提升为“面向逻辑相似性的 metric database”。在这一框架下，不同 embedding 空间中的数据可以被映射到统一的度量视图中，从而实现跨数据库的搜索、整合与管理。Conneau 等人的无监督对齐研究表明，不同 embedding 空间之间可以通过学习映射建立联系。Yang、Cao 和 Ren 则进一步把这一问题推进到向量数据库整合层面，提出 `local isometry hypothesis` 作为跨模型数据库整合的核心依据。Huh 等人关于表示收敛的讨论，则从更宏观的角度强化了跨模型共享结构这一设想的研究动机。

但是，仅仅解决“向量能否被统一比较”还不够。若要使 MetricDB 成为真正可用的数据库系统，就必须进一步解决查询效率问题。传统数据库之所以具备实用价值，不只是因为能够表达查询，更因为能通过索引机制高效执行查询。对 MetricDB 而言也是如此：如果没有一个适用于统一 metric 视图的索引层，那么跨 embedding 的查询即便在理论上成立，也很难在真实规模的数据上具备可用性。

因此，我负责的 `From Vector Indexing to Metric Indexing` 子方向，实质上是在解决 MetricDB 从“概念成立”走向“系统可运行”的关键一步。这个方向的意义不在于重新定义 metric database 的理念，而在于为其提供可执行的性能基础设施。

基于上述背景，下面需要进一步把这个方向收束为一个可以被研究、实现和评估的具体问题。也就是说，前一节回答的是“为什么这个方向值得做”，而下一节要回答的是“这个方向在系统中究竟要解决什么问题”。

## 2. 问题定义

### 2.1 核心问题

本研究聚焦的问题可以表述为：

在多个异构向量数据库已经可以通过对齐、映射或整合被组织到统一 metric 视图中的前提下，如何设计并实现一种高效的 metric index，以支持近邻搜索与相关查询操作？

这里的关键点在于，研究对象已经不再是单一 embedding 空间中的原生向量，而是来自不同数据库、不同模型、可能经过变换或映射的数据表示。Yang、Cao 和 Ren 已经说明，不同 embedding 模型生成的向量数据库不能简单做 union，否则会破坏原本支撑相似搜索的几何前提。传统的向量索引方法通常默认数据位于同一向量空间中，距离定义、分区方式、图结构邻接关系以及索引构建假设都建立在这一前提上。而在 MetricDB 场景中，这些假设至少部分被打破，因此需要重新审视现有 vector indexing 方法的适用性。

### 2.2 输入、输出与约束

本项目可以从系统角度抽象为如下形式：

- 输入：
  来自不同向量数据库的 embedding 数据
  不同数据库之间的映射关系或整合结果
  可能已经存在的局部索引结构
- 输出：
  一个能够支撑统一近邻检索的 metric index，以及与其对应的查询执行机制。
- 约束：
  需要与 MetricDB 的其他模块兼容
  需要在准确性与性能之间做出平衡
  需要在有限时间内形成一个可演示、可 benchmark 的原型实现

### 2.3 研究范围与模块职责

基于上述问题定义，本研究在 MetricDB 中承担的是索引层的设计与实现任务。换句话说，前一节已经说明了“问题是什么”，这一节则进一步说明“这个问题在系统中由哪个模块来解决，以及本研究具体负责哪些内容”。本研究并不试图重新定义整个 MetricDB 的架构，也不把整个跨库整合链路都作为本人的直接职责，而是将重点放在统一 metric 视图上的索引组织、查询效率和可评估实现上。

从当前 `metricdb` 的 README 和代码骨架来看，这一模块的最低要求是围绕 `MetricRelation` 与 `BaseMetricIndex` 实现一个可 build、可 search 的索引原型。换句话说，当前阶段最核心的职责不是一次完成整个统一索引层，而是先形成一个遵守系统接口、能够在 relation-level 场景下稳定工作的 metric indexing 模块。与此同时，这个模块在现有系统中的最直接下游对象是 `PredicateSearchModule`，因为后者需要索引模块返回 candidate IDs，再结合 metadata 进行 hybrid search。

与此相对，`UnionManager` 和 `EntityLinker` 所代表的跨 relation / 跨空间整合逻辑，虽然与本研究高度相关，但在当前代码中还没有和索引模块形成稳定的直接接口链。因此，这部分内容更适合作为本研究后续扩展的上游前提来考虑，而不是当前最低交付的必备条件。

本研究主要负责的内容包括：

- 面向统一 metric 视图的索引设计与问题建模
- 基于现有接口实现 relation-level metric index 原型
- 直接支撑 `Module 1` 的候选生成与基础系统集成
- 面向查询效率的性能优化、实验评估与 benchmark
- 在时间允许时进一步探索索引转换与可能的合并。

## 3. 研究目标与研究问题

前一节已经将问题收束为：在统一 metric 视图下，如何构建一个真正可用于查询执行的索引结构。对 proposal 而言，仅仅把问题表述清楚还不够，还需要进一步说明这个问题将如何被拆解成可执行的研究任务，以及研究最终准备回答哪些核心问题。因此，本节在问题定义的基础上，进一步给出本研究的目标设置与研究问题，并据此建立后续方法设计与评估方案的逻辑起点。

### 3.1 研究目标

本研究的总体目标，是为 MetricDB 设计并实现一个初步可用的 metric indexing 模块，使其能够在统一的 metric 视图上支持高效检索。若将前文的问题定义进一步转化为可执行的研究任务，那么本项目至少需要同时覆盖问题建模、方法选择、系统实现与评估设计这几个层面。也正因为如此，本研究不会只停留在“提出一个索引想法”，而是希望形成一条从问题分析到原型验证的完整研究路径。

在这一前提下，本文将研究目标具体化为以下几个方面：

1. 调研并分析现有 vector indexing 方法在 metric database 场景下的适用性与局限性。
2. 给出适用于 MetricDB 的 metric indexing 问题建模方式，并明确当前骨架下的最低接口要求。
3. 设计并实现一个符合 `BaseMetricIndex` 接口的 relation-level metric indexing 原型。
4. 使该原型能够直接支撑 `Module 1` 的候选生成与基础系统集成。
5. 建立一套用于评估 metric indexing 模块正确性与性能的 benchmark 方法。
6. 在时间允许时探索与 `Module 3` 场景相关的索引转换与合并路线。

### 3.2 研究问题

如果说上一小节回答的是“本项目准备做哪些事情”，那么这一小节要进一步回答“本研究最终试图解决哪些问题”。这些研究问题不仅用于概括 proposal 的核心关切，也将作为后续方法设计与评估方案的对应依据。围绕前述目标，本文拟重点回答以下几个研究问题：

1. 现有 vector indexing 方法在跨 embedding、跨数据库的统一 metric 视图下，哪些核心假设仍然成立，哪些需要修改？
2. 在 MetricDB 场景中，重建索引与转换合并索引两条路线分别适用于什么条件，它们的优劣如何？
3. 一个面向 MetricDB 的 metric index 应当如何在准确性、构建成本与查询效率之间取得平衡？
4. 在原型系统层面，metric indexing 模块如何与其他子模块对接，形成完整的查询路径？

## 4. Timeliness、意义、可行性与受益对象

### 4.1 Timeliness 与新颖性

本研究的时机性与新颖性主要体现在两个层面。

第一，随着向量数据库逐渐成为现代数据系统的重要基础设施，多模型、多来源 embedding 共存已经越来越常见，但现有系统仍然大多以单一 embedding 空间为默认前提。FAISS、Lucene 向量检索以及 ACORN 等工作分别从大规模 ANN、现实系统整合和混合查询执行的角度表明，向量检索已进入系统化阶段，但它们默认的仍然是单一或统一的向量空间。在这样的背景下，MetricDB 所提出的统一 metric 视图具有明显的现实时机性，而围绕这一视图进一步研究索引层实现，也就具有直接的研究价值。

第二，本研究关注的不是传统单库、单 embedding 空间下的 vector indexing，而是异构向量数据库被整合之后的 metric indexing 问题。这意味着研究对象发生了变化，原有索引假设不能简单照搬。同时，本项目并不只把索引视为一个孤立的数据结构问题，而是把它放在 MetricDB 的系统框架中考察，要求它同时服务于查询执行、系统集成和 benchmark 评估。更重要的是，近年的 metric-space 文献并没有停止发展：LIMS 与 Learned Metric Index 把 learned route 引入 metric indexing，graph-based metric search 的综述则说明图方法已形成现代化方法脉络，而 DIMS 进一步把这一问题推进到 distributed setting。这些工作共同说明，metric indexing 仍然是一个活跃演进中的问题，因此把它放到 MetricDB 语境下继续研究，具有明显的新颖性与时机性。

### 4.2 意义

这一研究方向对 MetricDB 具有直接的重要性。若没有索引层支持，MetricDB 很可能停留在概念验证阶段，只能证明不同 embedding 空间之间“可以比较”，却难以证明这种比较在系统上“可高效执行”。因此，metric indexing 是 MetricDB 走向实际系统实现的关键一环。

除此之外，本研究也可能对更广泛的数据库与信息检索领域产生启发。随着多模型、多来源数据的普及，未来的数据系统很可能需要面对越来越多“异构 embedding 共存”的场景。Huh 等人关于表示收敛的讨论也提示我们，跨模型统一表示并不只是工程需求，也可能是表示学习发展的自然趋势。因此，如何在统一度量视图上建立索引，将会成为一类具有长期价值的问题。

### 4.3 可行性

从可行性看，本项目具备较好的实施条件。

首先，研究方向已经由项目文档明确划定，问题范围相对清晰。其次，项目整体是一个共享代码库的合作项目，我的模块不需要独立完成整个 MetricDB，只需要在既定系统框架中完成属于索引层的部分。再次，文档已明确给出两条技术路线，这意味着该方向并非无从下手，而是可以沿着已有研究脉络推进。现有的 HNSW、FAISS 等索引与系统工作可以为主线方案提供实现参考，而 Integrating Vector Databases across Embedding Models 与 embedding alignment 相关研究则为统一 metric 视图的上游前提提供了直接可行性支撑。

更具体地说，目前文献支撑的强度在两条路线之间并不完全对称。统一 metric view 的上游前提，主要由 Yang、Cao 和 Ren 关于跨 embedding 模型整合向量数据库的工作，以及 embedding alignment 相关研究提供支撑。主线方案“整合后重建索引”的可行性，则更多来自 HNSW、FAISS 以及更直接面向 metric-space indexing 的工作，例如 *Searching in Metric Spaces*、*Indexing Metric Spaces for Exact Similarity Search*、LIMS、pivot-based metric indexing 研究以及 graph-based metric search 综述。换句话说，当前主线方案既有传统向量索引的工程经验，也有更直接的 metric indexing 文献脉络可借鉴。

相比之下，扩展路线“已有 index 的转换与合并”目前更多是从这些相关研究中获得启发，而不是已经存在一条成熟、可直接复用的现成方案。现有 modern metric indexing 文献虽然提供了 learned route、graph-based route 以及 distributed route 等多种启发，但它们大多没有直接回答“跨 embedding 整合之后，旧索引如何转换并合并”这一更具体的问题。更重要的是，从当前代码骨架看，`Module 4` 最直接被接入的是 `Module 1` 的候选生成流程，而不是 `Module 3` 所代表的 hard/soft union 场景，现有仓库也还没有提供 index merge 或 unified metric view 的现成 API。因此，在未来 10 周的项目周期内，本 proposal 将把“先形成一个可运行、可评估、并能直接支撑 Module 1 的主线原型”作为最低保底目标，再把与 `Module 3` 更直接相关的索引转换与合并保留为时间允许时继续推进的扩展方向。代码骨架和当前接口的作用，是帮助说明这一阶段划分是可行的，而不是说明项目此刻已经进入实现后期。

### 4.4 受益对象

该研究的受益对象不应仅理解为项目内部成员，更可以放在真实应用场景中理解。首先，数据库与信息检索研究者可以通过这一工作更系统地讨论跨 embedding 检索中的索引问题，而不是只停留在对齐与映射层面。其次，构建企业知识库、语义搜索或多模态检索系统的开发者，往往会遇到不同数据源使用不同 embedding 管线的情况，相关研究若能够形成统一 metric 视图上的索引方法，将有助于降低跨库检索与系统整合的成本。再进一步看，面向多平台内容检索、跨模型向量管理、研究型数据联邦系统等应用，也都有可能从这一方向中受益。

如果说前一节主要回答的是“为什么这个题目值得立项”，那么接下来就需要进一步说明：已有研究到底做到哪里、哪些部分已经较为成熟、又有哪些关键缺口恰好构成了本 proposal 的切入点。因此，下面的相关工作部分将不只是回顾文献，也是在为后续方法设计建立依据。

## 5. 相关工作

为了说明本研究为何成立，以及为什么会自然导向“重建 metric index”和“转换或合并已有索引”这两条路线，本节先对已有相关工作做必要梳理。这里的目的不是罗列所有向量索引方法，而是围绕三个问题组织文献：传统向量索引依赖什么前提、异构 embedding 数据如何被整合到统一 metric 视图中、以及在这一前提变化之后索引层会面临哪些新的迁移挑战。这样的组织方式也将直接服务于后续方法设计部分。

### 5.1 向量索引与近邻搜索

现有向量检索系统通常依赖近邻搜索相关索引技术来提升效率。不同方法在结构上可能采用树、图、量化、聚类或哈希等思路，但它们大多共享一个隐含前提，即所有向量都位于同一 embedding 空间中，并且距离函数与数据分布具有较稳定的一致性。Malkov 和 Yashunin 提出的 HNSW 是图索引路线中的代表，而 Johnson、Douze 和 Jegou 的 FAISS 则从系统实现角度展示了大规模相似搜索如何落地。这些工作共同构成了传统 vector indexing 的主要背景。

这些工作所代表的成功路线，主要建立在“单一 embedding 空间 + 相对稳定的数据分布假设”之上。也正因此，它们非常适合被用作本 proposal 的主线原型参考，但还不能直接回答跨 embedding、跨数据库统一 metric view 下的索引问题。

如果把视角扩大到更一般的 similarity search in metric spaces，就会发现 `metric indexing` 本身也有一条独立的研究脉络。Chávez 等人的经典综述 *Searching in Metric Spaces* 从更上位的角度总结了 metric-space similarity search 的核心难点、方法组织方式和 taxonomy，说明这一问题长期以来就与空间性质、距离函数和 intrinsic dimensionality 紧密相关，而不只是某一种局部数据结构选择。沿着这条脉络，Chen 等人关于 *Indexing Metric Spaces for Exact Similarity Search* 的工作又进一步把问题直接收束到数据库语境下的 indexing and querying，说明 metric indexing 并不只是向量检索的边角话题，而是一个可以被单独建模和系统梳理的研究方向。

在更具体的方法层面，Zhu 等人关于 pivot selection in metric spaces 的综述与实验研究表明，经典 metric index 的效果不仅取决于索引结构本身，也强烈依赖 pivot 设计。Tian 等人提出的 LIMS 则进一步说明，即使在 learned index 背景下，metric space 仍然不能被简单视作普通多维向量空间，因为许多依赖坐标结构、编号规则或固定分区方式的做法并不能直接迁移过来。除此之外，Antol 等人提出的 Learned Metric Index 进一步把相似搜索重构为分类问题，而 graph-based metric search 的综述也表明，图方法在 metric spaces 中已经形成较成熟的 modern route，这些工作共同说明，当前 metric indexing 的研究已经不只停留在经典树或 pivot-based 设计。

在这一设定下，索引构建通常围绕以下目标展开：尽可能减少查询时访问的数据量，同时保持较高召回率，并在构建成本、查询延迟和内存开销之间做平衡。这些目标同样适用于 MetricDB，但实现方式可能需要改变。

### 5.2 Metric database 与异构向量整合

Yang、Cao 和 Ren 在 *Integrating Vector Databases across Embedding Models* 中直接提出，不同 embedding 模型生成的向量数据库不能简单做 union，而需要建立一种能够保持局部几何结构的整合方式。他们进一步提出 `local isometry hypothesis`，用来解释为什么不同模型的向量数据库在局部邻域内可能仍然存在可对齐或近似等距的关系。基于这一点，原本彼此隔离的向量数据库才有可能被提升到统一的 metric 视图之下，从而支持跨库查询。已有研究更多关注的是这种映射与整合是否成立，以及如何利用 anchor points、union 或 query transformation 完成跨库检索。以 Conneau 等人的无监督对齐方法为代表的 embedding alignment 工作，说明空间之间的映射学习是一个已有研究基础的问题。Yang、Cao 和 Ren 则把这一问题推进到向量数据库整合层面。Huh 等人的讨论则从更宏观层面强化了跨模型表示存在共享结构的动机。

相较之下，索引层的问题尚未被同等充分地系统化。也就是说，现有研究更多回答“如何把不同数据库联系起来”，而不是“联系起来之后如何高效查”。这一差异正是本 proposal 的切入点：前一类工作让统一 metric view 成为可能，后一类问题则要求我们进一步回答，在新的空间假设下索引结构应如何重新组织。

### 5.3 从 vector indexing 到 metric indexing 的迁移挑战

若要将传统 vector index 迁移到 MetricDB 场景，需要面对至少三个问题。

第一，原有索引所依赖的空间结构在经过跨库整合后可能发生变化，导致分区边界、近邻关系或层级结构不再稳定。

第二，若直接在整合后的统一空间上重建索引，虽然实现较直接，但可能面临较高的构建成本和更新代价。

第三，若尝试复用已有索引，则必须回答原有索引的结构性质能否被保留、变换或合并，这涉及更复杂的系统与算法问题。

因此，本研究不会把相关工作部分写成对所有索引算法的罗列，而会围绕“哪些假设可以迁移，哪些不能迁移”来组织文献综述。HNSW、FAISS 和 Lucene 这类工作主要支撑传统单空间 vector indexing 的成功路线。Yang、Cao 和 Ren 以及 alignment 相关文献支撑统一 metric view 的上游前提。*Searching in Metric Spaces* 与 *Indexing Metric Spaces for Exact Similarity Search* 提供 metric-space similarity search 的上位综述与直接问题脉络。LIMS、Learned Metric Index、pivot selection survey 以及 graph-based metric search 综述则进一步说明 metric indexing 既有经典 pivot-based 设计问题，也在吸收 learned index、graph-based design 和 modern systems thinking 等较新的思路。再往前一步，DIMS 这类工作还表明，metric-space indexing 已经被推进到 distributed setting 中讨论。也正是在这几类工作的交汇处，本 proposal 才会自然导向“主线先重建索引、扩展再讨论转换与合并”的研究组织方式。

## 6. 方法设计

### 6.1 总体方法思路

本节的目的，是说明在未来 10 周内这一部分工作准备如何推进。结合当前项目文档、现有代码骨架和文献背景，本研究将采用“主线原型 + 扩展探索”的组织方式，先完成一个可运行、可评估的 metric indexing 原型，再在时间允许的前提下探索更具研究性的转换与合并路线。

当前 `metricdb` 代码仓库提供了一个 5 模块共享的 Python 骨架，并已经定义了 `MetricRelation` 与 `BaseMetricIndex` 等接口。这些现有接口的意义，不在于限定最终系统只能做到这里，而在于为接下来 10 周的工作提供一个合理起点。本研究可以先在该骨架上实现一个 relation-level 的 metric index 原型，验证索引模块在系统中的基本作用。至于之后是否进一步推进到更复杂的统一场景，这里属于基于项目方向和当前代码边界作出的阶段划分，而不是代码中已经写死的现成功能路线。

这篇 proposal 的目的，就是提出一个可分阶段推进的计划。主线部分回答“我们首先将如何构建一个可运行原型”。扩展部分回答“在主线跑通后，我们还准备进一步探索哪些更强的问题”。

### 6.2 主线方案：基于现有接口实现 metric index 原型

在未来 10 周的主线任务中，本研究首先将完成一个基于现有系统骨架的 metric index 原型。这里的关键不是把最终的 MetricDB 场景过度简化，而是承认项目周期和当前基础设施的现实约束：在现阶段，最稳妥的做法是先从单 relation 输入开始，建立索引模块的最小闭环。

现有 `metricdb` 骨架已经定义了 `MetricRelation` 与 `BaseMetricIndex` 两个抽象，并在 `main.py` 中用 `SimpleMetricRelation` 提供了一个 relation 示例。因此，主线方案将以这些接口为起点，推进一个可在系统骨架中真正运行起来的原型，而不是先把全部精力放在更复杂的跨库整合机制上。

从接口角度看，当前主线方案可以被更准确地写成如下形式：

- 输入：一个 `MetricRelation`，其内部可以根据 ID 返回向量和 metadata
- 核心处理：基于距离函数对 relation 中的对象建立索引结构，并支持 query vector 的近邻搜索
- 输出：一个满足 `build/search` 接口的索引实例，以及搜索返回的候选 item IDs。

在方法选择上，当前代码和 README 已经给出了一个合理但开放的范围。README 中明确提到可以考虑 `M-Tree`、`VP-Tree`、或 `FAISS wrapper` 等路线，并强调索引设计应当对 distance metric 有明确意识，搜索逻辑也可以体现 triangle inequality pruning 等 metric-space 思路。因此，本 proposal 在这一阶段不会把某一种结构写成既定答案，而是把方法选择表述为一个后续实施中的设计决策：我们将优先选择一种与当前骨架兼容、实现复杂度可控、且能够在实验中清楚比较的索引思路，先完成第一版 prototype。

在此基础上，实现任务可以继续细化为：

1. 明确索引如何从 `MetricRelation` 中读取对象及其向量表示。
2. 在 `M-Tree`、`VP-Tree`、`FAISS wrapper` 或其他兼容方案之间做出第一版原型选择，并明确该选择的理由。
3. 完成 `build()` 和 `search()` 两个最小接口，使模块能在 unit test 和 integration test 中稳定运行。
4. 确保 `search()` 返回的结果形式能够直接服务于 Module 1 的后续 metadata filtering。
5. 将 prototype 的最低交付界定为“可 build、可 search、可被 Module 1 调用”，而不是一开始就承诺跨 relation 的索引转换与合并。
6. 为后续替换或扩展索引结构预留空间，但不在第一阶段过度承诺具体高级结构。

需要特别说明的是，虽然 HNSW、FAISS 等工作在相关文献中仍然具有重要参考价值，但本 proposal 在当前阶段不会把某一种复杂结构写成既定实现答案。更合理的写法是：在后续实施中，我们将选择一种与当前骨架兼容、易于验证且能够支撑实验比较的 metric indexing 思路，优先完成第一版原型，再根据进展决定是否进一步引入更复杂的索引结构。

### 6.3 扩展方案：索引转换与合并

在主线原型稳定之后，本研究仍将把“索引转换与合并”保留为扩展研究方向。也就是说，这一部分并未从研究问题中消失，而是被安排在主线完成之后，作为时间允许时继续推进的增强路线。这里至少存在两种可能的思路：

- 将某一数据库中的索引转换到另一数据库的统一 metric 视图中
- 在保留局部索引的前提下，设计某种索引合并机制，使多个索引协同支持检索。

当前代码骨架在这里提供的价值，主要是帮助我们判断阶段划分是否合理。现有 `metricdb` 接口并没有直接给出 index import、index conversion、index merge 或 unified metric view 的现成 API，而 Module 3 和 Module 5 也仍在更高层的整合问题上保留了大量待实现空间。因此，把这一方向写成扩展任务而不是主线最低交付，既符合代码现实，也符合 10 周 proposal 的可完成性要求。

这一方向的技术难点也依然成立：索引结构不仅依赖数据点的位置，还依赖邻近关系、分区方式和局部几何组织。一旦空间表达发生变化，原有索引未必仍然可迁移。因此，proposal 在这里的重点不是声称“我们已经知道如何做完”，而是明确说明：在主线原型完成后，我们将进一步分析和探索这一问题的可行性、潜在收益与实现路径。

### 6.4 系统集成

根据 `main.py` 和 integration tests，现有最小数据流可以概括为：

1. `data/data_generator.py` 生成 synthetic data
2. `SimpleMetricRelation` 把 vectors 和 metadata 组织成一个 relation
3. `MetricIndex.build(relation)` 在该 relation 上构建索引
4. `MetricIndex.search(query_vector, k)` 返回候选 IDs
5. `PredicateSearchModule` 再将这些候选与 metadata filtering 结合
6. `SQLParser`、`UnionManager` 和 `EntityLinker` 作为并列模块存在，但目前还没有形成真正的完整查询执行链。

对 proposal 而言，这里最重要的信息，是当前最真实、最直接的模块关系是 `Module 4 -> Module 1`，也就是索引模块先返回候选 IDs，Predicate Search 再在这些候选上结合 metadata 做 hybrid filtering。

与此同时，`SQLParser` 代表未来查询链上的上游逻辑入口，但当前尚未和索引模块形成真实执行耦合。`UnionManager` 和 `EntityLinker` 则分别代表跨 relation 查询整合与 anchor-point driven integration 的更高层系统目标。它们和本研究在问题层面密切相关，但在当前代码里还没有和 `MetricIndex` 形成稳定的直接接口链。

因此，本研究在接下来的实施中将优先保持与现有接口的一致性，避免把索引模块过早耦合到尚未成熟的上游整合逻辑。统一 metric view、hard union 和 anchor-point driven integration 仍然是更高层的系统目标，但在 proposal 这一步，它们更适合作为后续推进方向与扩展前提来组织，而不是写成第一阶段已经完全具备的系统条件。也正因为如此，与 `Module 3` 更直接相关的索引转换与合并路线，应在本 proposal 中被明确定位为主线之后的自然扩展，而不是当前最低交付。

### 6.5 风险与应对

该研究面临的主要风险包括：

第一，当前仓库本质上是一个共享骨架，而不是成熟系统，因此很多模块虽然已经有接口，但尚未形成完整功能。这意味着，如果在未来 10 周一开始就把工作依赖于其它模块的成熟实现，整个计划很容易失去收敛性。对此，本研究将优先围绕 `BaseMetricIndex` 的最小契约展开，先完成单 relation 原型。

第二，索引算法如果选得过于激进，可能导致实现时间过长，或与当前代码接口不匹配。对此，项目早期将优先选择更稳妥、更容易在现有骨架下形成原型的方案，而不是一开始就承诺复杂图索引或转换机制。

第三，当前实验条件主要依赖 synthetic data 和测试框架，与最终多库、跨 embedding 的 MetricDB 场景之间存在明显差距。对此，本研究将先在现有可控环境下建立最小可执行评估，再逐步扩展到更强场景。

第四，项目是多人协作框架，接口虽然已定义，但模块实现进度可能不一致。对此，需要把最低保底交付界定得更清楚：即便其他模块仍未完整实现，索引模块也应能够独立 build、search，并在 unit test 与 integration test 中正常工作。这样的阶段划分也有助于保证 proposal 中提出的工作量在 10 周内是合理的。

## 7. 评估方案

本节说明的是：在接下来的项目实施中，我们将如何证明 metric indexing 这一部分不仅“能做出来”，而且“做得合理”。结合当前代码骨架和项目周期，本研究将从正确性与系统代价两个维度组织评估，并把实验分为最低必做项和时间允许时继续扩展的部分。

### 7.1 准确性评估

准确性评估的目标，是判断未来实现的 `MetricIndex.search()` 是否能够返回符合预期的近邻结果，并能在系统中承担候选生成的角色。基于当前骨架和可预见的实验条件，第一阶段将优先采用下面几类检查：

- 与暴力搜索结果的差异
- top-k 结果是否稳定且可解释
- 在不同随机 query 下返回结果是否满足基本近邻行为
- 返回值是否能被 Module 1 直接作为候选 ID 使用。

在 baseline 设计上，第一阶段最可靠的对照将是暴力搜索，因为它最容易在当前 synthetic data 条件下提供 ground truth。也就是说，在项目前期，正确性的首要验证不是和复杂现成系统比较，而是先证明 metric index 原型返回的结果与 brute-force nearest neighbor 基本一致。这里的最低必做项应包括：

- `search()` 的返回类型与接口行为验证
- prototype 相对于 brute-force 的 top-k 结果检查
- prototype 返回结果能否顺利进入 Module 1 的后续 filtering 流程。

在此基础上，如果后续实现中引入更具体的索引结构或已有库包装，再继续补充更强的 baseline 比较。

### 7.2 性能评估

性能评估将主要关注主线原型的系统代价与基本查询效率，具体包括：

- 索引构建时间
- 单次查询延迟
- 在不同数据规模下的时间变化趋势
- 必要时补充内存占用或索引大小的观测。

这些指标能够帮助判断未来实现的 metric index 原型是否已经具备最基本的实用性，也能帮助区分“只是接口上能跑”和“在一定规模下具备可接受代价”这两种不同状态。

结合当前代码库，最现实的做法是利用 `main.py` 中可调的数据规模参数，在不同 `DATA_SIZE` 和 `VECTOR_DIM` 下进行分层测试。例如，先从较小规模 synthetic data 起步，再扩展到中等规模，观察 build time 和 query latency 的变化趋势。相比之下，多吞吐场景、复杂多库环境和大规模系统 benchmark 将留到后续条件成熟后再补充。

从 proposal 的阶段安排看，性能评估也应当区分最低必做项和扩展项。最低必做项包括：

- 在多组 synthetic data 规模下记录 build time
- 在多组 query 上记录 query latency
- 必要时记录 index size 或基本内存开销。

扩展项则包括：

- 在不同 prototype 设计之间做更细致比较
- 在更大规模或更复杂数据条件下补充测试
- 在时间允许时观察扩展路线可能带来的额外系统代价。

### 7.3 路线对比评估

如果扩展方案后续能够形成初步设计或部分实现，则还可以进一步比较两条路线：

- 基于当前 relation 直接重建索引的实现成本与性能表现
- 转换或合并已有索引的潜在收益、接口缺口与实现复杂度。

但在当前代码条件下，这一部分更适合先写成分析性比较，而不是写成近期必做实验。原因很简单，现有骨架已经更直接地支撑前者，却还没有为后者提供稳定输入输出边界。因此，路线对比将优先回答“为什么接下来 10 周要先做重建索引，为什么转换与合并要放在扩展位置”，并把后者的实现难点、依赖前提和可能收益清楚列出。

从本 proposal 的最低完成标准看，本研究至少应完成以下几类实验：第一，主线原型相对于 brute-force search 的正确性验证。第二，主线原型在不同 synthetic data 规模下的构建时间与查询延迟评估。第三，即使扩展方案暂时无法实现，也要给出“索引转换与合并”为何未进入当前 10 周主线、它需要哪些前提、潜在收益是什么的分析性比较。这样一来，评估部分就能和项目周期、现有骨架以及可交付工作量保持一致。

## 8. 预期成果

本研究的预期成果包括：

1. 一个遵守 `BaseMetricIndex` 接口、能够在单个 `MetricRelation` 上完成 `build/search` 的 metric indexing 原型模块
2. 一个可直接服务 `Module 1` 的 candidate generation 流程，使索引模块在当前系统骨架中形成最小可执行闭环
3. 一套用于评估索引准确性与性能的基础 benchmark 方案，包括 brute-force baseline、synthetic data 条件下的正确性检查以及 build/search 的基础性能结果
4. 对主线方案优缺点的分析总结，以及对“重建索引”和“转换/合并索引”两条路线的比较性讨论
5. 一份包含方法、实验结果与分析结论的 dissertation/report 主体章节基础。

如果研究进展顺利，扩展成果还可能包括：

- 对已有索引可迁移性的初步结论
- 一个与 `Module 3` 更直接相关的索引转换或合并方向初步设计，或其小规模原型探索
- 对不同 prototype 设计选择的进一步比较结论。

## 9. 时间计划、里程碑与交付物

本研究的 proposal 将在项目正式实施之前完成，因此以下 10 周计划并不包含 proposal 写作本身，而是说明在 proposal 确定之后，metric indexing 方向将如何分阶段推进。

### 9.1 阶段一：问题收敛、原型设计与实验准备（第 1-2 周）

在项目实施的最初两周，重点不是重新撰写 proposal，而是把 proposal 中已经提出的主线方案进一步落实为可执行的技术计划。具体而言，这一阶段将围绕现有 `metricdb` 骨架，进一步确认 metric indexing 模块的职责边界、第一版 prototype 的技术路线、它与 `Module 1` 的直接对接方式、实验设置以及最低保底交付范围。

交付物：

- 一份明确的 prototype 技术方案
- 一份说明 `Module 4 -> Module 1` 集成方式的实现草案
- 一份可执行的实验设置与 baseline 设计
- 一份细化后的阶段实施计划
- 对最低交付目标与扩展目标的最终确认。

### 9.2 阶段二：主线原型实现与基础联调（第 3-6 周）

这一阶段是整个项目的主体部分，预计持续四周。核心任务是基于现有 `MetricRelation` 和 `BaseMetricIndex` 接口，完成 relation-level metric indexing 原型的实现，并使其能够在当前系统骨架中稳定运行，尤其是能够直接支撑 `Module 1` 的候选生成流程。由于项目后期仍需预留 dissertation/report 写作时间，这一阶段的目标应控制在“先把主线 prototype 做扎实”，而不是过早扩张到更复杂的跨 relation 功能。

交付物：

- 一个可运行的 metric indexing 原型模块
- 与当前骨架兼容的 build/search 基本流程
- 一个可直接服务 `PredicateSearchModule` 的 candidate generation 流程
- 基础联调结果与初步调试结论。

### 9.3 阶段三：系统评估与扩展分析（第 7-8 周）

这一阶段预计持续两周，重点从“把原型做出来”转向“系统地评估原型表现”。主要工作包括完成与 brute-force baseline 的正确性比较，在不同 synthetic data 规模下记录 build time 和 query latency，整理 prototype 的优势、局限与后续可扩展空间，并在时间允许时对与 `Module 3` 更直接相关的索引转换与合并路线进行初步分析。如果扩展路线暂时无法形成完整实现，则至少需要给出较清楚的可行性分析、前提条件与潜在收益判断。

交付物：

- 一组基础 benchmark 与分析结果
- 对主线方案优缺点的总结
- 对索引转换与合并方向的初步探索或分析性比较

### 9.4 阶段四：论文写作与最终整理（第 9-10 周）

考虑到项目最后仍需完成 dissertation/report 的主体写作、结果整理和图表收尾，本 proposal 将保守地预留最后两周用于最终文档产出，而不把全部时间都压在实现和实验上。这样的安排虽然会使前面几个阶段相对更紧，但更符合项目真实交付流程，也更有助于避免“实现完成但最终文档来不及整理”的风险。

交付物：

- dissertation/report 的主体章节草稿
- 最终实验图表与结果整理
- 与 proposal 对齐的最终项目交付材料。

## 10. 结论

`From Vector Indexing to Metric Indexing` 是 MetricDB 中一个兼具研究价值与系统价值的方向。它的核心任务不是重新定义异构向量数据库整合的基本理念，而是在此基础上提出一条可执行的索引研究与实现路径。对于当前 proposal 而言，最重要的不是证明所有问题都已经被解决，而是说明：在未来 10 周内，我们将优先完成什么、如何分阶段推进、如何评估这些工作是否达成目标。

从 proposal 的角度看，这一方向已经具备较为清楚的问题定义、方法路线和评估框架。接下来的核心任务，是先完成一个遵守 `BaseMetricIndex` 接口、能够直接支撑 `Module 1` 候选生成的 relation-level metric index 原型及其基础评估，再在时间允许时探索与 `Module 3` 更直接相关的索引转换与合并路线。这样的组织方式既回应了代码与系统背景，也更符合 proposal 作为未来工作计划书的本质。

## 11. 初步参考文献

1. Yang, B., Cao, Y., and Ren, Y. Integrating Vector Databases across Embedding Models. 2025.
2. Malkov, Y. A., and Yashunin, D. A. Efficient and robust approximate nearest neighbor search using Hierarchical Navigable Small World graphs. 2016.
3. Johnson, J., Douze, M., and Jegou, H. Billion-scale similarity search with GPUs. 2017.
4. Lin, J., Pradeep, R., Teofili, T., and Xian, J. Vector Search with OpenAI Embeddings: Lucene Is All You Need. 2023.
5. Patel, L., Kraft, P., Guestrin, C., and Zaharia, M. ACORN: Performant and Predicate-Agnostic Search Over Vector Embeddings and Structured Data. 2024.
6. Conneau, A., Lample, G., Ranzato, M. A., Denoyer, L., and Jegou, H. Word Translation Without Parallel Data. 2018.
7. Huh, M., Cheung, B., Wang, T., and Isola, P. The Platonic Representation Hypothesis. 2024.
8. Tian, Y., Yan, T., Zhao, X., Huang, K., and Zhou, X. A Learned Index for Exact Similarity Search in Metric Spaces. 2022.
9. Zhu, Y., Chen, L., Gao, Y., and Jensen, C. S. Pivot selection algorithms in metric spaces: a survey and experimental study. VLDB Journal, 2022.
10. Chávez, E., Navarro, G., Baeza-Yates, R., and Marroquín, J. L. Searching in Metric Spaces. ACM Computing Surveys, 2001.
11. Chen, L., Gao, Y., Song, X., Li, Z., Zhu, Y., Miao, X., and Jensen, C. S. Indexing Metric Spaces for Exact Similarity Search. 2022.
12. Antol, M., Ol’ha, J., Slanináková, T., and Dohnal, V. Learned Metric Index — Proposition of learned indexing for unstructured data. 2021.
13. Shimomura, L. C., Oyamada, R. S., Vieira, M. R., and Kaster, D. S. A survey on graph-based methods for similarity searches in metric spaces. 2021.
14. Zhu, Y., Luo, C., Qian, T., Chen, L., Gao, Y., and Zheng, B. DIMS: Distributed Index for Similarity Search in Metric Spaces. 2024.

后续正式版本仍需继续补充：

- MetricDB 或相关核心论文
- 更贴近 metric search / metric indexing 的直接相关工作
- 数据库联邦检索、soft union / hard union 相关文献
- 实验 baseline 与 benchmark 文献。
