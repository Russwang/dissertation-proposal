# MetricDB Module 4 要求与方法方向调查

## 目的

这份调查的目标是回答三个问题：

- 老师给的 `metricdb/` 骨架代码和 README 对 `Module 4: Metric Indexing` 的要求到底是什么；
- 在方法上，老师给了哪些方向提示，哪些部分又没有被写死；
- `Module 4` 和 `Module 1/2/3/5` 的关系应该如何理解，以及这些关系应如何反映到 proposal 中。

这里的判断主要基于以下文件：

- [metricdb/README.md](/Users/battle.net/Desktop/dissertation/metricdb/README.md)
- [metricdb/core/base.py](/Users/battle.net/Desktop/dissertation/metricdb/core/base.py)
- [metricdb/modules/metric_indexing/indexing.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/metric_indexing/indexing.py)
- [metricdb/modules/predicate_search/engine.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/predicate_search/engine.py)
- [metricdb/modules/union_management/union.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/union_management/union.py)
- [metricdb/modules/query_engine/parser.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/query_engine/parser.py)
- [metricdb/modules/entity_linking/linker.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/entity_linking/linker.py)
- [metricdb/main.py](/Users/battle.net/Desktop/dissertation/metricdb/main.py)
- [metricdb/tests/test_integration.py](/Users/battle.net/Desktop/dissertation/metricdb/tests/test_integration.py)

## 一、老师对 Module 4 的最低要求是什么

从 README、接口定义和模块文件看，老师对 `Module 4` 的要求是明确且聚焦的：

- 实现一个遵守 `BaseMetricIndex` 的索引模块；
- 至少实现 `build(data: MetricRelation)` 和 `search(query_vector, k)`；
- 索引建立在 `MetricRelation` 之上，而不是脱离系统骨架单独设计；
- 搜索结果需要返回 item IDs，供其他模块继续消费；
- 方法重点应体现 `metric properties / distances`，而不是只把它当成普通坐标搜索问题。

在 [metricdb/core/base.py](/Users/battle.net/Desktop/dissertation/metricdb/core/base.py) 中，最硬的接口约束是：

- `MetricRelation.get_vectors(ids)`
- `MetricRelation.get_metadata(ids)`
- `BaseMetricIndex.build(data)`
- `BaseMetricIndex.search(query_vector, k) -> List[str]`

README 还明确强调：这些接口不应随意修改。

因此，老师对 `Module 4` 的最低要求并不是“立刻完成整个 MetricDB 的统一索引系统”，而是先完成一个 **可 build、可 search、可被系统其他模块调用的 metric indexing 原型**。

## 二、老师给了哪些方法方向

老师在方法上给了方向提示，但没有指定唯一答案。

README 和 `indexing.py` 中明确提到的方向包括：

- `M-Tree`
- `VP-Tree / Vantage Point Tree`
- `FAISS wrapper`

同时，代码里还给出了两个额外提示：

- index 应该对所使用的 `distance metric` 有明确意识；
- search 逻辑可以考虑 `triangular inequality pruning`。

这说明老师期待的不是一个随意命名为 “metric index” 的普通检索壳子，而是至少在设计上体现出 metric indexing 的思路。

## 三、老师没有明确指定什么

虽然方法方向被提示了，但老师并没有把下面这些决定写死：

- 没有指定必须使用 `M-Tree`；
- 没有指定必须使用 `VP-Tree`；
- 没有指定必须包 `FAISS`；
- 没有指定必须先做 exact 还是 approximate；
- 没有给出现成的 `index conversion / merge` API；
- 没有给出现成的 unified metric view 执行接口。

这意味着：当前 proposal 最合理的写法，不是宣称“老师已经指定我们要做某一种方法”，而是说明 **老师给出了一个允许的方法范围，我们将在后续实施中根据可实现性、系统兼容性和实验需求做出选择。**

## 四、Module 4 和其他模块的关系

### 1. 和 Module 1 的关系：当前最直接的下游关系

这是当前代码里最明确的模块关系。

[metricdb/modules/predicate_search/engine.py](/Users/battle.net/Desktop/dissertation/metricdb/modules/predicate_search/engine.py) 明确要求：

- `PredicateSearchModule(index, relation)`

其中 `index` 就是 `BaseMetricIndex` 的实例。伪代码也写得很直接：

- 先 `self.index.search(query_vector, k=...)`
- 再结合 metadata 做 predicate filtering

在 [metricdb/tests/test_predicate_search.py](/Users/battle.net/Desktop/dissertation/metricdb/tests/test_predicate_search.py) 中，还特别说明：

- Module 1 现在可以先用 `MockIndex` 独立开发；
- 后续可以直接换成真正的 `MetricIndex`。

因此最直接的结论是：

- `Module 4` 当前最直接服务的是 `Module 1`；
- 你做的索引模块首先要承担 `candidate generation` 的角色；
- 这也是 proposal 主线最应该写清楚的系统关系。

### 2. 和 Module 2 的关系：未来查询链上的上游逻辑关系

`Module 2` 负责 SQL parser 和 query optimiser。

[metricdb/tests/test_integration.py](/Users/battle.net/Desktop/dissertation/metricdb/tests/test_integration.py) 里把理想流程写成：

- `Parsing (M2) -> Indexing (M4) -> Predicate Search (M1)`

但当前代码现实是：

- parser 还没有真正输出可执行的查询计划；
- Module 2 还没有真实调用到 Module 4。

因此 Module 2 和 Module 4 的关系应理解为：

- 在系统设计上，Module 2 是未来查询入口；
- 在当前代码现实里，它还不是你必须直接依赖的开发前提。

### 3. 和 Module 3 的关系：最自然的扩展方向

`Module 3` 负责：

- `Soft Union`: query translation without re-indexing
- `Hard Union`: physical data integration into a common space

这和你的研究主题高度相关，因为：

- 你的 proposal 一直关注统一 metric view 之后的索引问题；
- 你也在讨论已有 index 的 conversion / merge。

但在当前代码里，`Module 3` 并没有和 `MetricIndex` 形成现成的直接接口链。当前骨架中还没有：

- `UnionManager -> MetricIndex` 的直接 build 输入；
- index import / merge API；
- hard union 完成后自动重建索引的系统流程。

所以最合理的理解是：

- `Module 3` 不是你当前主线实现的直接前提；
- 它是你主线之后最自然的扩展方向；
- proposal 中把 conversion / merge 写成和 `Module 3` 相关的 stretch goal，是符合代码现实的。

### 4. 和 Module 5 的关系：更高层整合场景的支撑模块

`Module 5` 负责 geometric hashing 和 anchor points。

它的重要性在于：

- 支撑跨 relation 的链接；
- 为更高层的统一视图或整合逻辑提供依据；
- 可能在长期影响后续索引构建场景。

但在当前骨架里，`Module 5` 并没有和 `Module 4` 形成直接方法调用关系。因此它更适合被写成：

- 长期系统背景；
- 与 `Module 3` 类似的上游支撑模块；
- 不是当前 10 周主线必须先完成的依赖。

## 五、对 proposal 写法的直接启示

从当前代码和文档出发，proposal 最稳妥的写法应该是：

- 主线：先完成一个 relation-level metric indexing prototype，并使其能够直接支撑 `Module 1` 的候选生成与基础集成；
- 扩展：在主线跑通之后，再探索与 `Module 3` 相关的 index conversion / merge，以及与 `Module 5` 所代表的更复杂跨 relation 场景之间的关系。

换句话说：

- 你做的是索引基础设施模块，不是整个 MetricDB 全系统总代；
- 你当前最直接的系统价值，是先把 `Module 4 -> Module 1` 这条链做实；
- `Module 3` 是 proposal 里最自然的扩展方向，而不是主线最低交付。

## 六、一句话结论

老师对 `Module 4` 的要求很聚焦：先实现一个遵守 `BaseMetricIndex` 接口、基于距离组织、能在单个 `MetricRelation` 上 build/search、并能为 `Module 1` 提供候选结果的 metric indexing 原型。方法上老师给了 `M-Tree / VP-Tree / FAISS wrapper` 等方向提示，但没有指定唯一实现；而你和 `Module 3` 的关系，最合理的定位就是 proposal 中的扩展路线。
