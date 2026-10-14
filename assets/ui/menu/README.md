# 主页面 · 纸偶舞台

依据用户确认的去掉两个团子与六个元素球的主页面设计制作。

- 背景：paper-theater-background.png。已移除所有烘焙按钮、图标和文字，用于独立舞台底图。
- 按钮：paper-ticket-atlas.png。带真实 Alpha 的四种空白票券底图；依次为酒红、深紫、奶油长票券和奶油短票券。
- 图标：settings.svg、book.svg、star.svg，为可缩放的原生 UI 图标。
- 生成方式：内置 image_gen.imagegen；完整提示词保存在 generation-prompts.json。
- 来源概念：output/ui_concepts/v3/main-menu-clean-v3.png。

scripts/v2/paper_menu_theme.gd 负责背景、图集区域、按钮状态和图标。文字由 Godot Button 与系统字体绘制，五个按钮仍连接 game_app.gd 现有的探索、继续、历史、设置和图鉴逻辑。

逻辑画布为 1280×720，沿用项目等比缩放。三个主按钮在舞台下方居中纵排，两个角落入口统一为 124×60、距右边缘 24 像素；设置与图鉴页面的返回入口沿用对应位置和大小。禁用、悬停、按下、键盘焦点均有独立视觉状态。
