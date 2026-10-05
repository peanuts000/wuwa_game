# 敌人配置

统一编辑本目录的 `bosses.csv`，普通、精英和Boss各占一行。保留文件名以兼容现有加载流程。修改后重新启动游戏生效。

| 字段 | 含义 |
| --- | --- |
| id | 唯一ID；已有存档可能引用，不建议改名 |
| name | 显示名称 |
| encounter_type | battle 普通、elite 精英、boss 首领；同类型多行时使用表中第一行 |
| hp / defense | 首层生命 / 防御 |
| hp_growth_per_floor | 每层增加的首层血量比例；0.2代表20% |
| texture | 贴图路径，使用 res://assets/... |
| skill_effect_id | 常态技能类型 |
| skill_effect_params | 技能参数JSON，例如 {"count":2} |
| skill_interval | 每多少次玩家行动检查一次技能，至少1 |
| skill_chance | 每次检查触发概率，0～1 |
| enrage_hp_ratio | 狂暴生命比例阈值，0禁用；0.3333333333约为三分之一 |
| enrage_skill_interval | 狂暴后的技能检查间隔 |
| enrage_skill_chance | 狂暴后的技能触发概率 |
| enrage_skill_effect_id | 狂暴后的技能类型 |
| enrage_skill_effect_params | 狂暴后的技能参数JSON |
| description | 敌人名称悬停说明；调整数值后同步修改描述 |

支持技能：`none` 无效果、`lock_cells` 锁格、`break_combo` 打断连击、`lock_and_break_combo` 锁格并打断连击、`boss_random_interference` 随机干扰。锁格数量由 `count` 控制；随机干扰使用 `lock_large` 和 `lock_small`。新增技能机制仍需在代码中实现效果处理。

生命公式：round(hp × (1 + hp_growth_per_floor × (层数 - 1)))。狂暴替换常态技能，不额外叠加一次释放。无限生命练习模式不狂暴。节点显式指定 boss_id 时优先使用指定敌人，否则按 encounter_type 选择。

CSV中JSON字段需双引号转义，例如 `"{""count"":2}"`；可参考现有行。不要修改同目录自动生成的 `.translation` 文件。
`locked_turns` 是内部兼容字段，现作为锁定标志使用，不再表示倒计时；所有锁格技能统一遵循相邻消除解锁规则。
