# Proposal 结构复核清单

## 当前结论

当前中文初稿已经不是“缺骨架”的状态，而是进入了“统一口径、收紧承诺、准备给老师讨论”的阶段。现阶段的首要目标仍然是把 proposal 写完整、写稳、写成一份说明未来 10 周将做什么的计划书，而不是提前进入代码实现。

## 一、已完成修正与可复用经验

### 已完成修正

- proposal 主体结构已经完整，包含背景、问题定义、目标、相关工作、方法、评估、预期成果、时间计划与参考文献。
- `1 -> 5` 的逻辑链已经基本顺畅，前半部分不再需要结构性重写。
- `6 - 10` 已经改成 future work proposal 的口径，不再把当前代码说明写成当前任务本身。
- `第 9 段` 已明确写成 proposal 之外的 10 周实施计划，而不是把 proposal 写作本身纳入执行期。
- 当前代码骨架已经完成一轮系统对齐：`Module 4` 的真实边界是实现 `BaseMetricIndex.build/search`，服务单一 `MetricRelation` 场景，并直接支撑 `Module 1` 的 candidate generation。
- `Module 3` 已明确被定位为主线之后最自然的扩展方向，而不是当前最低交付前提。

### 从中提取的经验

- 先收紧模块边界，再写方法与时间计划，否则 proposal 很容易过度承诺。
- 先区分主线与扩展线，再写 deliverables，否则不同路线会被写成并列最低目标。
- 代码信息在 proposal 里应服务于 feasibility 和 stage planning，而不是喧宾夺主变成代码说明书。
- 真正高价值的代码阅读，不是“看懂每个文件”，而是找出接口、最短执行链、直接依赖关系和当前尚未接上的扩展链路。
- 对当前项目而言，最重要的系统关系不是“全模块一次打通”，而是先把 `Module 4 -> Module 1` 这条主线写实。

## 二、拿到代码之后应该怎么做

现在已经拿到 `metricdb` 代码，因此清单的工作重点需要固定为下面这个顺序：

1. 先确认代码骨架中的真实接口与模块边界。
   当前已确认的核心接口是 `MetricRelation` 与 `BaseMetricIndex`。
2. 再识别最短可执行主线。
   当前已确认的最短主线是：
   `MetricRelation -> MetricIndex.build/search -> PredicateSearchModule`
3. 再区分直接依赖和扩展场景。
   当前已确认：
   - `Module 1` 是直接下游
   - `Module 2` 是未来查询上游
   - `Module 3` 和 `Module 5` 是更高层扩展前提
4. 再反向修正 proposal。
   也就是把代码现实写进 `2.3 / 3.1 / 4.3 / 6.4 / 9 / 10`，让主线、扩展线和里程碑与真实代码边界一致。
5. 最后才考虑进一步具体化实现路线。
   例如 VP-tree、M-tree 或 FAISS wrapper 的取舍，应放在 proposal 口径稳定之后。

换句话说，拿到代码之后的目标不是立刻开始 coding，而是先用代码把 proposal 的主线、扩展线、依赖关系和阶段计划校正到位。

## 三、当前仍需推进

### 1. 文稿统一

- 继续检查摘要、预期成果、结论是否完全对齐当前主线：
  先完成 relation-level metric index prototype，再探索扩展路线。
- 继续避免把 `Module 3/5` 写成主线强依赖。

### 2. 方法与系统设计

- 方法部分要继续保持当前边界：
  - 输入：单个 `MetricRelation`
  - 核心接口：`BaseMetricIndex.build(data)` 与 `search(query_vector, k)`
  - 直接系统价值：为 `Module 1` 提供 candidate generation
- 方法方向可以保留为开放选择：
  - `M-Tree`
  - `VP-Tree`
  - `FAISS wrapper`
- 但当前不应在 proposal 中提前承诺某个具体实现。

### 3. 评估与实验

- 评估仍应围绕当前代码最直接支持的条件来写：
  - synthetic data
  - unit tests / integration tests
  - brute-force ground truth
  - build/search 评估
- 暂不把复杂跨库整合实验写成近期必做项。

### 4. 文献补充

- 前半部分文献已经够支撑 draft，不需要继续机械扩张。
- 下一轮如补文献，应优先补：
  - 更贴近 baseline 的实验文献
  - 更贴近方法与评估的 direct metric indexing 文献
  - 更贴近扩展路线的少量直接依据

## 四、当前最高优先级

当前最高优先级是：继续把 proposal 收口成一份与代码现实一致的 10 周工作计划。

这一优先级下最重要的判断是：

- 当前目标是写稳 proposal，不是开始改代码。
- 代码阅读的目的，是帮助规划未来 10 周做什么。
- proposal 的最低主线应明确写成：
  一个遵守 `BaseMetricIndex` 接口、能直接服务 `Module 1` 的 metric indexing prototype。
- proposal 的扩展线应明确写成：
  与 `Module 3` 更直接相关的 index conversion / merge。

## 五、完成这一轮后的下一步顺序

1. 继续压缩并统一摘要、预期成果和结论中的主线/扩展口径。
2. 将中文稿进一步收口成一版可以直接转换为英文稿的稳定 draft。
3. 在中文稿稳定之后，推进英文转写并完成英文 draft。
4. 英文 draft 完成后，把这一版 draft 发给老师做一轮验收和反馈。
5. 根据老师反馈再决定是否继续补文献、压缩表达或调整主线承诺。
6. proposal 稳定之后，再进入真正的代码实现阶段。

## 当前阶段成功标准

- proposal 的承诺和当前代码现实一致。
- `Module 4 -> Module 1` 的主线关系已经在正文中写清。
- `Module 3` 已被稳定写成扩展方向。
- `第 9 段` 已稳定对应 proposal 之后的 10 周实施期。
- 后续代码实现范围与优先级已被文稿合理约束。
