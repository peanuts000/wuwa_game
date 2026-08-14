# 棋子系统扩展说明

## 新增普通团子

1. 在 `res://data/pieces/` 新建一个 `.tres`。
2. 使用 `PieceDefinition` 脚本。
3. 填写稳定唯一的 `id`、`display_name`、`theme_color`、`multiplier`、`rarity`、`description`、`default_special_effect_id` 和 `tags`。
4. 如果要默认出现在出战池，在 `scripts/data/piece_catalog.gd` 的 `default_roster` 中加入该 `id`。

存档只保存 `id`，所以发布后不要修改已有资源的 `id`。显示名、颜色、描述和倍率可以调整。

## 新增特殊效果

1. 在 `res://data/effects/` 新建一个 `.tres`。
2. 使用 `SpecialEffectDefinition` 脚本。
3. 优先复用已有 `effect_type`：`line`、`area`、`color_clear`。
4. 只有新增全新的行为类型时，才需要扩展 `BoardModel.collect_effect_targets()` 和 `main.gd` 的组合解析。

## 核心约束

- 棋盘格只保存 `piece_id`、`special_effect_id` 和状态标记。
- UI、计分、结算统计都通过 `PieceCatalog` 查询资源定义。
- 核心棋盘逻辑不要硬编码具体团子名称。
