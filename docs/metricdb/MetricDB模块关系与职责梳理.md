# MetricDB 模块关系与职责梳理

## 目的

这份文件专门回答一个问题：在老师给的 `metricdb/` 骨架代码里，`Module 4: Metric Indexing` 和其他模块之间到底是什么关系，哪些是直接依赖，哪些只是并列模块，哪些属于后续更高层的系统目标。

这里的判断依据主要来自：

- [metricdb/README.md](/Users/battle.net/Desktop/dissertation/metricdb/README.md)
- [metricdb/core/base.py](/Users/battle.net/Desktop/dissertation/metricdb/core/base.py)
- [metricdb/main.py](/Users/battle.net/Desktop/dissertation/metricdb/main.py)
- [metricdb/tests/test_integration.py](/Users/battle.net/Desktop/dissertation/metricdb/tests/test_integration.py)
- 各模块入口文件：
  - [metricdb/modules/predicate_search/engine.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/predicate_search/engine.py)
  - [metricdb/modules/query_engine/parser.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/query_engine/parser.py)
  - [metricdb/modules/union_management/union.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/union_management/union.py)
  - [metricdb/modules/metric_indexing/indexing.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/metric_indexing/indexing.py)
  - [metricdb/modules/entity_linking/linker.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/entity_linking/linker.py)

## 一、老师给的代码里是否明确写了 Module 4 和其他模块的关系

有，而且写得比较清楚，但层次不同。

README 里明确给了两类信息：

- 一类是“任务分工”，也就是每个模块各自负责什么；
- 一类是“集成方式”，也就是这些模块在 `main.py` 和 integration tests 里如何被连起来。

从代码现实看，`Module 4` 和其他模块的关系不是“它单独解决整个 MetricDB 问题”，而是：

- 它是一个共享基础模块；
- 它先在单个 `MetricRelation` 上建立和查询索引；
- 然后给其他模块提供候选生成或后续系统扩展的基础。

换句话说，老师给的骨架并没有要求你现在就把 `metric indexing` 直接做成“跨所有模块的一步到位总方案”，而是把它放在一个比较清楚的中间层位置。

## 二、Module 4 自己的明确职责

根据 [metricdb/README.md](/Users/battle.net/Desktop/dissertation/metricdb/README.md) 和 [metricdb/modules/metric_indexing/indexing.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/metric_indexing/indexing.py)，Module 4 的明确职责是：

- 实现 `MetricRelation` 上的索引构建；
- 实现基于距离的近邻搜索；
- 使用 `BaseMetricIndex` 接口暴露 `build(data)` 和 `search(query_vector, k)`；
- 可以选择真正的 metric index，如 `M-Tree`、`VP-Tree`；
- 也可以用 coordinate-based index 的 wrapper，例如 `FAISS`。

这说明老师给的代码对 Module 4 的最低要求其实很聚焦：

- 先做一个可 build、可 search 的索引模块；
- 先让它能在骨架系统里被调用；
- 不要求第一版就直接完成复杂的跨库 index conversion / merge。

## 三、Module 4 和 Module 1 的关系：最直接、最现实的下游关系

这是目前代码里最明确、最直接的一条关系。

### 1. README 的表述

README 明确写了：

- Module 1 负责 hybrid search；
- 它要把 vector similarity 和 relational predicates 结合起来；
- 它需要依赖一个 index 来生成候选结果。

### 2. 代码里的表述

[metricdb/modules/predicate_search/engine.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/predicate_search/engine.py) 的构造函数直接要求传入：

- `index: BaseMetricIndex`
- `relation: MetricRelation`

而 `hybrid_search()` 里的伪代码也明确写了第一步是：

- `candidate_ids = self.index.search(query_vector, k=k*10)`

然后再：

- 读取 metadata；
- 做 predicate filtering；
- 返回过滤后的结果。

### 3. 测试里的表述

[metricdb/tests/test_predicate_search.py](/Users/battle.net/Desktop/dissertation/metricdb/tests/test_predicate_search.py) 更直接说明了模块关系：

- Module 1 默认可以先用 `MockIndex` 独立开发；
- 等到 Module 4 实现后，可以把 `MockIndex` 替换成真正的 `MetricIndex`。

### 4. 结论

这说明 Module 4 和 Module 1 的关系是：

- `Module 4` 是 `Module 1` 的直接底层依赖；
- `Module 4` 提供候选 ID；
- `Module 1` 在候选结果之上做 metadata/predicate 过滤；
- 两者在当前骨架中构成最清楚的“搜索闭环”。

如果只问“你做的部分现在最先服务谁”，答案就是：**最先服务 Module 1。**

## 四、Module 4 和 Module 2 的关系：当前不是直接调用关系，而是未来查询链上的间接关系

Module 2 是 query engine / SQL parser。

根据 [metricdb/modules/query_engine/parser.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/query_engine/parser.py)，它当前负责的是：

- 解析带 metric operator 的 SQL；
- 形成逻辑查询计划；
- 后续再做逻辑优化。

在 [metricdb/tests/test_integration.py](/Users/battle.net/Desktop/dissertation/metricdb/tests/test_integration.py) 中，测试写的是：

- `Flow: Parsing (M2) -> Indexing (M4) -> Predicate Search (M1)`

但要注意，这里更多是在表达未来系统流程，而不是说当前代码里 Module 2 已经真正调起了 Module 4。因为现在 `parser.parse(sql)` 仍然返回 `None`，还没有真正形成执行计划。

所以 Module 2 和 Module 4 的关系应该写成：

- 从系统设计上看，Module 2 在上游，负责把查询解析出来；
- 从当前代码现实看，两者还没有形成真实执行耦合；
- 因此这是“未来执行链上的间接关系”，不是当前最直接的开发依赖。

## 五、Module 4 和 Module 3 的关系：概念上相关，但当前不是直接输入输出依赖

Module 3 负责 `Virtual & Hard Unions`。

根据 [metricdb/modules/union_management/union.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/union_management/union.py)，它关注的是：

- `Soft Union`：不重建索引的跨 relation 查询；
- `Hard Union`：把多个 relation 整合到统一空间。

这和你的研究主题显然有关，因为你的 proposal 一直在讨论：

- 统一 metric 视图之后如何重建索引；
- 或者已有 index 的转换与合并。

但从当前老师给的代码来看，Module 3 和 Module 4 还没有形成一个现成的接口连接。例如骨架里并没有直接提供：

- `UnionManager -> MetricIndex` 的 build 输入接口；
- index merge/import API；
- unified metric view 完成后的统一索引构建流程。

在 [metricdb/main.py](/Users/battle.net/Desktop/dissertation/metricdb/main.py) 里，`UnionManager` 和 `MetricIndex` 也只是并列初始化，并没有真正连起来。

因此这两者的关系应写成：

- 在研究问题上高度相关；
- 在当前代码实现上仍然是并列模块；
- Module 3 更像是 Module 4 的未来上游前提，而不是当前已经接上的直接依赖。

这也是为什么 proposal 里“index conversion / merge”更适合写成扩展线，而不是当前最低交付。

## 六、Module 4 和 Module 5 的关系：系统背景相关，但当前几乎没有直接耦合

Module 5 负责 entity linking / geometric hashing。

根据 [metricdb/modules/entity_linking/linker.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/entity_linking/linker.py)，它关注的是：

- 在不同 relation 之间发现 anchor points；
- 找到跨空间中可能代表同一实体的对象；
- 为后续更高层整合提供链接基础。

这和 MetricDB 整体愿景有关，也可能在更长期的系统里影响：

- relation 对齐；
- 统一 metric view 的建立；
- 后续跨库查询与整合。

但在当前骨架里，Module 5 和 Module 4 没有直接方法调用关系。`main.py` 和 integration tests 里，它们也是并列存在，而不是一个已经驱动另一个。

所以这里更准确的写法是：

- Module 5 属于更上游、更跨关系的系统支撑模块；
- 它可能在长期影响 Module 4 的输入前提；
- 但在当前代码和当前阶段中，两者没有直接依赖关系。

## 七、Module 4 和核心接口层的关系：这是你当前最硬的约束

对你来说，最重要的不是别的模块，而是 [metricdb/core/base.py](/Users/battle.net/Desktop/dissertation/metricdb/core/base.py)。

这里明确规定了：

- `MetricRelation.get_vectors(ids)`
- `MetricRelation.get_metadata(ids)`
- `BaseMetricIndex.build(data: MetricRelation)`
- `BaseMetricIndex.search(query_vector, k) -> List[str]`

README 还特别强调：

- 不要随意改这些接口；
- 如需修改，要先和 supervisor 沟通。

所以从开发现实上说，Module 4 当前最强的关系不是“先和 Module 3/5 对接”，而是：

- 必须先满足核心抽象接口；
- 必须先在 `MetricRelation` 上 build/search；
- 必须先返回别人可以消费的 `item IDs`。

## 八、从 main.py 和 integration test 看，当前系统中的模块关系可以怎么概括

当前老师给的骨架代码中，最小的真实流程是：

1. synthetic data 被组织成 `SimpleMetricRelation`
2. `MetricIndex.build(relation)`
3. `MetricIndex.search(query_vector, k)` 返回候选 ID
4. `PredicateSearchModule(index, relation)` 在候选结果上结合 metadata 做 hybrid search

与此同时：

- `SQLParser` 表示未来查询上游；
- `UnionManager` 表示未来跨 relation / 跨空间整合；
- `EntityLinker` 表示未来跨 relation 链接与 anchor-point 支撑。

所以当前最准确的结构，不是“五个模块全部已经形成完整链路”，而是：

- `Module 4 + Module 1` 构成当前最现实的可执行主线；
- `Module 2` 是未来上游查询入口；
- `Module 3` 和 `Module 5` 是未来跨 relation / 跨空间扩展的重要前提；
- 但它们现在还没有和 Module 4 构成稳定的直接接口链。

## 九、对你这一部分的最直接启示

如果只从当前代码和 README 出发，你的部分在现阶段应当这样定位：

- 你做的是共享基础能力，不是完整系统总装；
- 你当前最直接的协作对象是 Module 1；
- 你当前最硬的技术约束是 `BaseMetricIndex` 接口；
- 你和 Module 3/5 在研究目标上高度相关，但在代码上还没有直接耦合；
- 你和 Module 2 在未来执行链上相关，但当前仍以逻辑流程关系为主。

这也意味着，在 proposal 里更稳妥的写法应该是：

- 主线：先完成 relation-level metric indexing prototype，并使其能支撑 Module 1 的候选生成与基本集成；
- 扩展：后续再探索在 Module 3/5 所代表的跨 relation、统一 metric view 场景下，如何进行索引转换与合并。

## 十、一句话结论

老师给的 `metricdb` 骨架并没有要求你现在就把 `metric indexing` 直接做成整个 MetricDB 的最终统一索引层；它更明确要求你先实现一个遵守 `BaseMetricIndex` 接口、能在单个 `MetricRelation` 上 build/search、并能被 `Module 1` 直接使用的基础索引模块。与 `Module 3`、`Module 5` 的关系目前更多是研究方向上的上游前提和后续扩展，而不是当前已经接好的直接接口依赖。
