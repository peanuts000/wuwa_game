# 设置与图鉴：舞台剧木板重设计

日期：2026-10-13。使用内置 `image_gen.imagegen`，依据项目现有设置和图鉴运行截图生成三套成对概念图。每张上半为设置、下半为图鉴。完整提示词、参考路径见 `prompts.json`。

| 方案 | 文件 | 设计重点 | 取舍 |
| --- | --- | --- | --- |
| A 纸艺彩绘木板 | a-paper-painted.png | 奶油底、浅紫细木边、柔和彩绘与纸艺层次 | 与当前纸剧场协调，木材质感较弱 |
| B 午夜星幕木板 | b-midnight-stage.png | 深紫漆木、金色细线、星月与浅色字 | 星月主题强，落地需拉开深色面板与幕布的明度 |
| C 复古剧院告示板 | c-vintage-playbill.png | 胡桃木窄框、酒红票头、旧纸内衬 | 木制舞台道具感明确，形状更规整 |

建议优先考虑 A；若希望保留明显的木制剧院道具感，选择 C。

三套沿用悬挂双绳、设置现有功能，以及卡牌/补给品/藏品三入口。原始概念图是美术方向预览，非准确尺寸的运行截图。

## 已应用：A 版粗糙木板

用户先要求增加手工粗糙感，随后确认选用 `a-paper-painted-rough.png`，现已接入设置和图鉴。

- 设置使用 `assets/ui/settings/rough-board.png`、`rough-ticket.png`，图鉴使用 `assets/ui/compendium/rough-boards.png`。全部为内置 imagegen 生成的透明无字素材，完整提示词见 `runtime-asset-prompts.json`。
- 修改 `scripts/v2/settings_popup.gd` 和 `scripts/v2/compendium_choice.gd` 的素材、配色、图集取样与文字位置；保留原生文字、交互、双绳和入场动画。
- `applied-settings-*.png` 与 `applied-compendium-*.png` 为 960×540、1280×720、1920×1080 实际运行截图。
- 实际渲染测试：设置 65 项检查、图鉴 99 项检查全部通过。另设置无窗口测试 57 项通过；图鉴测试还覆盖 1280×960。
- 修正设置测试在全屏切换后的点击坐标：等待窗口布局稳定，再使用包含画布缩放的坐标定位控件；游戏窗口切换逻辑未修改。
