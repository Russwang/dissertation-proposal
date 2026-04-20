# MetricDB 代码结构与接口梳理

## 1. 这份文件的目的

这份文件用于把当前 `metricdb/` 仓库中已经明确可见的系统结构、模块职责、接口形式和真实输入输出整理清楚，作为后续收紧 proposal 结构清单与改写 `第 6-7 段` 的依据。

当前判断的重点不是“系统最终会做成什么”，而是“现在代码里已经给了什么骨架、每个模块当前实际上承担什么责任、我负责的 Module 4 在代码里到底处于什么位置”。

同时也要明确这份文件服务于什么阶段目标：当前阅读和整理代码的主要目的，不是立刻开始改写代码，而是先把 proposal 写完整、写稳，并让方法设计与评估方案和现有代码现实保持一致。代码实现、原型选择和具体改写，应放在 proposal 稳定之后的后期阶段推进。

## 2. 代码库的整体定位

`metricdb/` 是 `MetricDB MSc Cluster Project (2025/26)` 的主系统仓库。它当前更像一个面向 5 个学生模块协作的 Python 原型框架，而不是已经实现完成的完整数据库系统。

这个仓库的特点是：

- 已经定义了统一接口；
- 已经拆好了 5 个模块；
- 已经提供了 `main.py` 用于演示模块如何接起来；
- 已经提供了 `tests/` 用于单模块和集成测试；
- 但各模块核心逻辑大多仍是 `TODO`。

因此，当前最合理的理解方式不是“老师已经给了一个复杂系统实现”，而是“老师给了一个可协作开发的骨架和接口模板”。

## 3. 顶层结构

当前仓库最重要的目录和文件如下：

- `core/base.py`
  定义系统的抽象接口，是所有模块共同遵守的骨架。
- `modules/`
  放 5 个学生负责的模块实现：
  - `predicate_search/`
  - `query_engine/`
  - `union_management/`
  - `metric_indexing/`
  - `entity_linking/`
- `main.py`
  一个集成演示入口，用来说明模块如何初始化和串接。
- `tests/`
  每个模块各有一份测试文件，另有 `test_integration.py` 做端到端流程演示。
- `data/`
  生成和读取 synthetic data。
- `examples/`
  给出简化接口示例和可选的 C++ 扩展示例。

## 4. 当前系统的真实运行流程

基于 `main.py`，当前系统的真实流程可以概括为：

1. 生成或读取 synthetic vectors 和 metadata；
2. 用这些数据构造 `SimpleMetricRelation`；
3. 初始化 `MetricIndex` 并调用 `build(relation)`；
4. 用 `MetricIndex` 和 `MetricRelation` 初始化 `PredicateSearchModule`；
5. 初始化 `SQLParser`；
6. 初始化 `UnionManager`；
7. 初始化 `EntityLinker`。

这说明当前系统的集成状态是：

- 5 个模块已经被放进同一个系统骨架中；
- 模块之间已经约定了最基本的对象依赖关系；
- 但还没有真正形成完整的查询执行引擎。

更具体地说，`MetricIndex` 当前直接对接的是一个单一的 `MetricRelation`，而不是已经整合完成的跨库 unified metric view。

## 5. 核心抽象接口

### 5.1 `MetricRelation`

定义在 `core/base.py` 中，是系统里最基础的数据抽象。当前暴露两个方法：

- `get_vectors(ids) -> np.ndarray`
- `get_metadata(ids) -> List[Dict[str, Any]]`

它的含义是：系统默认把“向量 + 元数据”打包成一个 relation 来访问，而不是直接暴露底层存储结构。

在 `main.py` 中，对应的具体实现是 `SimpleMetricRelation`。它内部维护：

- `vectors`
- `metadata`
- `ids`

因此目前 relation 的能力很基础，更接近一个内存中的示例数据容器。

### 5.2 `BaseMetricIndex`

`BaseMetricIndex` 是 Module 4 必须实现的接口，当前只有两个核心方法：

- `build(data: MetricRelation)`
- `search(query_vector: np.ndarray, k: int = 10) -> List[str]`

这两个接口非常关键，因为它们直接定义了你当前模块的最低交付边界：

- 输入是一个 `MetricRelation`
- 输出是若干 item IDs

当前接口里没有要求：

- 多 relation 输入；
- 显式空间对齐信息；
- index merge 接口；
- query transformation 接口；
- 更新、删除、增量维护接口。

### 5.3 `QueryNode` 与 `MetricQueryProcessor`

这两个类也定义在 `core/base.py` 中，但当前只是为 Module 2 预留的抽象位：

- `QueryNode`：逻辑查询计划节点
- `MetricQueryProcessor.execute(query)`：执行查询计划

目前它们还没有形成真正可执行的查询树或执行器。

## 6. 各模块当前的真实职责与输入输出

### 6.1 Module 1: `predicate_search`

文件：`modules/predicate_search/engine.py`

当前模块初始化时接收：

- `index: BaseMetricIndex`
- `relation: MetricRelation`

当前目标是实现 `hybrid_search(query_vector, filters, k)`。

从伪代码看，Module 1 默认依赖 Module 4 返回候选 IDs，然后再调用 relation 的 metadata 做过滤。因此你这边最直接服务的下游模块其实是 Module 1。

### 6.2 Module 2: `query_engine`

文件：`modules/query_engine/parser.py`

当前目标是：

- 解析带 metric operator 的 SQL；
- 做逻辑优化。

但当前实现基本还是空的，`parse()` 只是打印 SQL 并返回 `None`。

因此目前 proposal 中不应把 Module 2 写成已经能稳定向 Module 4 交付复杂逻辑计划的上游模块。

### 6.3 Module 3: `union_management`

文件：`modules/union_management/union.py`

当前预留了两个接口：

- `soft_union_query(relations, query_vector)`
- `hard_union_integrate(relations) -> MetricRelation`

这部分在概念上和 MetricDB 的跨库整合非常相关，但当前依然完全是 `TODO`。这意味着：

- 代码里还没有真正的跨库 unified view 输入；
- 你负责的索引模块现在也还没有直接建立在“整合后多库数据”之上。

### 6.4 Module 4: `metric_indexing`

文件：`modules/metric_indexing/indexing.py`

这是你当前负责的模块。它的真实任务不是“把整个 MetricDB 的索引层全部做完”，而是：

- 实现一个符合 `BaseMetricIndex` 的可运行 index 原型；
- 能对 `MetricRelation` 执行 `build()`；
- 能根据 query vector 返回若干 IDs；
- 能被 Module 1 和 integration test 正常调用。

注释里提到的方向包括：

- M-Tree
- VP-Tree
- 包装现有坐标索引，如 FAISS

但这些都还是候选实现路线，不是代码里已经确定的既定方案。

### 6.5 Module 5: `entity_linking`

文件：`modules/entity_linking/linker.py`

当前负责：

- `find_anchor_points(rel_a, rel_b)`
- `link_entities(rel_a, rel_b)`

这部分和跨 embedding space 的 reference mappings 有直接关系，但同样还是 `TODO`。因此当前 proposal 中不能假定 anchor points 和 relation linking 已经作为稳定上游能力存在。

## 7. 测试与当前可评估条件

`tests/` 目录体现了当前代码库的真实开发策略：

- 每个模块先做独立测试；
- 再用 `test_integration.py` 做简单集成演示；
- 测试主要确认接口是否可调用，而不是确认复杂算法已经正确实现。

对 Module 4 来说，当前测试期望很低，主要只有两点：

- `build()` 不崩；
- `search()` 返回 `list`。

此外，`test_integration.py` 里真正把你模块放进了如下链路：

- Parsing（Module 2，当前基本空）
- Indexing（Module 4）
- Predicate Search（Module 1）

这说明当前第一阶段最合理的实验条件是：

- synthetic data；
- 单 relation；
- 先用 brute-force 作为 ground truth；
- 先验证 build/search 和集成流能跑通。

## 8. 我负责的 Module 4 目前到底处于什么位置

根据当前代码，Module 4 的真实位置可以概括为：

### 8.1 它是系统中的共享基础模块

虽然从 proposal 的大叙述看，metric indexing 是 MetricDB 走向系统可用性的关键部分，但在当前代码里，它首先是一个供其他模块依赖的基础接口实现，而不是一个独立完整子系统。

### 8.2 它当前面对的是单 relation 原型场景

现在 `build()` 的输入是一个 `MetricRelation`，没有显式表达：

- 多个数据库；
- 多个 embedding 模型；
- 对齐后的统一空间；
- 已有 index 的导入或合并。

因此当前代码现实下最稳妥的表述应是：

> 第一阶段先在单 relation 原型环境里实现一个 metric index，证明该索引模块可以在系统骨架中正常构建、查询并与其他模块对接。

### 8.3 它当前最直接的下游是 Module 1

Module 1 的伪代码已经写得很明确：先调 `index.search()` 拿候选 ID，再调用 relation 的 metadata 做过滤。因此，Module 4 当前最直接的系统价值，是支撑 hybrid search 的候选生成。

### 8.4 它当前还不是“跨库整合后的最终索引层”

这是最重要的一点。当前代码没有让你直接实现：

- 跨 embedding 整合后的 unified metric index；
- index conversion；
- index merge；
- distributed metric indexing。

这些仍然是 proposal 中可以保留的研究远景，但不能继续写成“当前代码原型已经基本对接到那种系统边界”。

## 9. 当前代码现实与现有 proposal 的主要偏差

结合现有 draft，当前最明显的偏差有以下几类：

### 9.1 主线方案写得比代码现实更“系统化”

现有 `第 6 段` 之前默认从“统一 metric view 已经形成”出发，并把索引模块写成接收整合后表示的下游。这在研究叙述上没问题，但和当前代码骨架并不一致。当前代码还没有真正把 unified metric view 做成可传给你模块的稳定输入。

### 9.2 HNSW 被写得过于像既定起点

proposal 之前把 HNSW 类图索引写成默认原型起点，但代码里并没有任何 HNSW 相关实现，也没有任何图索引接口约束。当前更稳妥的写法应该是“选择一种距离驱动、易于实现和评估的 metric index 原型”，而不是预设 HNSW。

### 9.3 扩展路线离现有接口太远

索引转换与合并当然仍然是研究上成立的扩展方向，但当前代码接口根本还没有到那一步。因此它应继续保留在扩展研究或 future work 位置，而不是近期主线的自然下一步。

### 9.4 评估方案需要向当前测试条件收缩

当前系统可直接支撑的是：

- synthetic data
- unit tests
- integration tests
- brute-force ground truth

因此评估段落应先围绕这些条件写“最低可执行实验”，而不是过早绑定更大规模、更复杂的 benchmark 情境。

## 10. 这份梳理对 proposal 下一步修改的直接影响

基于当前代码现实，下一步最合理的改法应该是：

1. 先用本文件收紧 `Proposal结构复核清单.md`；
2. 把 `第 6 段` 从抽象系统草图改成“围绕当前接口的原型方法设计”；
3. 把 `第 7 段` 从偏一般性实验设计改成“围绕当前代码条件的最低可执行评估方案”；
4. 保留“跨库 unified metric view / index conversion / index merge”作为研究动机和扩展方向，但不再写成当前代码已经接上的既定主线。

这一步的目标不是削弱 proposal，而是让 proposal 的主线承诺、代码现实和后续可执行工作量重新对齐。
