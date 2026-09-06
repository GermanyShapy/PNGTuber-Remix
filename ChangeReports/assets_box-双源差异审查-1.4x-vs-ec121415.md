# assets_box 双源差异审查报告（1.4.x × Branch_ec121415）

> 起因：merge-changelog-1.4x-ec121415.xlsx C1/C4 项测试中提出质疑 —— 合流时 `assets_box`（资产盒）整文件取 Branch_ec121415，
> 而 1.4.x 主线在 2026-01-22 ~ 2026-07-01 对其有 4 个提交（`7e78fbc` `2dd3967` `edface4` `4480128`），质疑这些改动被"直接抛弃"。
> 本文基于 git 拓扑 + 三方版本逐行对比，结论先行：**存在被覆盖的内容，但功能净损失极小；真正需要手动处理的是 3 个定点问题，不建议整文件反向回滚**。
> 审查日期：2026-09-06 ｜ 基线：合流提交 `65dba08`、1.4.x tip `c45aa8f`、Branch tip `1bee220`（= `36b75d4` 版）、当前 HEAD `6295d64`

---

## 0. 结论速览

| # | 结论 | 依据 |
|---|---|---|
| 1 | "整文件取 Branch"属实：当前工作区 `assets_box.tscn` 与 Branch 版仅差 1 行（CheckBox 信号 `changed→toggled` 修复，出自合流提交） | 三方 blob diff |
| 2 | 1.4.x 那 4 个提交对 tscn 的改动**绝大部分是无害格式/资源差异**（图集化、unique_id、节点拍平、拼写修正），无功能节点被丢弃 | 逐提交 node 级 diff（见 §2） |
| 3 | 4 个提交的**功能性脚本改动已全部保留**（blink fix、`release_focus()`、`InputEventKey` 过滤、死代码清除）——它们在合流中被手工合成进 `AssetStateButton.gd` 等，而非被弃 | §2 + §3 hash 归属 |
| 4 | 真正需要手动处理的合流缺陷有 2 处（**多语言文本被 1.4.x 旧写法覆盖**，详见 §5），需实机确认 1 处（焦点行为），资源风格 1 处（低优先） | §5 |
| 5 | **不建议**把 1.4.x 版 assets_box 整文件合回 —— Branch 版含 cycle 树 / InclusiveKey / MinDuration / CastTime / AutoShow 等 1.4.x 没有的功能（B2/B3），直接替换会反向丢掉 Branch 的增量 | §3 函数集对比 |

---

## 1. 裁决事实（git 可复现）

| 文件 | 合流(65dba08)裁决 | 现状 hash | 说明 |
|---|---|---|---|
| `UI/.../MiniComponents/assets_box.tscn` | **整文件取 Branch** + 1 行修复 | 454 行 = Branch 版 | 仅 445 行 `changed→toggled` 与 Branch 不同 |
| `Scripts/UI/RightPanel/assets_panel.gd` | 取 Branch（合成版=Branch 删 2 空行） | `cd2dfdc` | Branch 函数集 ⊇ 1.4.x 函数集（§3） |
| `Scripts/UI/States/AssetStateButton.gd` | **三方手工合成** | `bd195115` | Branch 基础 + 保留 1.4.x 的 edface4/4480128 改动 |
| `Scripts/UI/RightPanel/CycleToggles.gd` | 取 1.4.x | = `c45aa8f` 版 | **Branch 的 `tr()` 修复被覆盖（缺陷，§5）** |
| `Scripts/UI/RightPanel/CycleForward.gd` | 取 1.4.x | = `c45aa8f` 版 | 同上 |
| `Scripts/UI/RightPanel/CycleBackward.gd` | 取 1.4.x | = `c45aa8f` 版 | 同上 |
| `Scripts/UI/RightPanel/cycle_item_tree.gd` | Branch 新增文件，照搬 | = Branch | 1.4.x 无此文件 |

---

## 2. 1.4.x 四个提交逐项去向（核心）

### `7e78fbc` 2026-01-22 partial adding a small warning symbol for image sizes
- **tscn 内实际改动**：无新增功能节点。全部为 —— 按钮图标 3 张散图 → `ui_buttons.png` 图集（AtlasTexture）；全节点加 `unique_id`；结构拍平（`HBoxContainer/HBox/CycleChoice` → `HBoxContainer/CycleChoice`、`CycleMargin/Margin2/Grid` → `CycleMargin/Grid`）；删除 `ShouldDisLabel`。
- **连带**：warning symbol 本体在 `file_manager.gd` / `image_data.gd` / `Global.gd` 等（不在 assets_box 文件域）。
- **合流产物状态**：图标退回引用散图 `DeleteButton.png` / `ZoominButton.png` / `ZoomOutButton.png` —— **三张散图在 1.4.x tip、Branch tip、当前工作区均存在，无缺纹理风险**；图集化（A14 风格）未覆盖该文件。无功能丢失。
- 结论：**无需处理**（若产品要求全 UI 图集统一，属风格项，低优先，见 §5-D）。

### `2dd3967` 2026-03-07 refactory: Localization strings in scenes
- **tscn 内改动**：仅 1 行拼写修正 `TR_BLIND_KEY` → `TR_BIND_KEY`（按钮"绑定按键"）。
- **合流产物状态**：Branch 版本来就用正确拼写 `TR_BIND_KEY`。
- 结论：**无实际丢失**。

### `edface4` 2026-05-26 tiny fix for blink option
- **tscn 内改动**：全部控件加 `focus_mode = 1` + `focus_behavior_recursive = 1`（键盘 Tab 可达性），移除 Branch 系 `focus_mode = 0`。blink 修复本身不在 tscn。
- **连带脚本改动**（关键）：
  - `AssetStateButton.gd`：`_on_is_asset_check_toggled(false)` 后补 `%IsAssetButton.release_focus()`；
  - `sprite_object.gd` / `append_object.gd` / `comment_object.gd`：状态/加载路径补 `if !get_value("should_blink"): %Modifier1.show(); %Modifier1.modulate.a = 1`（blink 关闭时防 Modifier1 被误隐藏）；
  - 删除 `func zazaza(parent)` 死代码（append/comment 对象）。
- **合流产物状态**：`release_focus()` 保留（HEAD 110 行）；三个对象脚本 `should_blink` 块均保留（各 ≥2 处）、`zazaza` 残留 0；`reaction_config.gd` 的 should_blink 分支链完整。
- 被覆盖的仅为 tscn 焦点属性（Branch 版以 `focus_mode=0` 为主）→ 见 §5-C。
- 结论：**功能性修复 100% 保留，无需处理**。

### `4480128` 2026-07-01 updated global input libs
- **tscn 内改动**：仅 1 行 —— `IsAssetButton` 的 `focus_behavior_recursive` 1→2（键盘焦点链）。
- **连带脚本改动**（配合 GI 库事件模型更新，关键）：
  - `_toggled`：录制时 `release_focus()`/`grab_focus()` → `set_focus_mode(FOCUS_ALL)`/`release_focus()`；
  - `_unhandled_input`：排除式 `if !event is InputEventMouseMotion` → 白名单式 `if event is InputEventKey`（只允许键盘键作热键，防鼠标/滚轮误录）。
- **合流产物状态**：脚本改动**全部保留**（HEAD 31/34/39/50 行）；tscn 的 1 行属性未保留。
- GI dll 更新属 A10（addons/GI 域），独立于本文件。
- 结论：脚本侧无需处理；tscn 侧 1 行属性缺失的**实机影响需确认**（§5-C）。

---

## 3. 两版 tscn 功能差异总表（1.4.x 369 行 vs Branch/合流 454 行）

### Branch 版独有（合流后新增/保留，1.4.x 用户升级所得 —— 正常增量）
| 元素 | 归属功能 |
|---|---|
| `InclusiveKeyCheck` / `HBoxMinDuration`+SpinBox / `IgnoreIfRestCheck` / `HBoxCastTime`+SpinBox / `AutoShowCheck` | B3 资产显隐行为配置（1.4.x 无） |
| `CycleDeleteTip` 面板（删除 cycle 悬停提示 + `mouse_entered/exited` 连接） | B2 周期树配套 |
| `Panel2` + `CycleItemTree`（Tree + `cycle_item_tree.gd`） | B2 周期资产树管理（1.4.x 无） |
| `ShouldDisLabel`（"消失键列表"标题） | Branch 保留（1.4.x 在 7e78fbc 删过） |

### 1.4.x 版独有 / Branch 版已无（被覆盖项）
| 元素 | 性质 | 是否需要补 |
|---|---|---|
| `focus_mode=1`+`focus_behavior_recursive=1` 全控件（edface4） | 键盘可达性；Branch 有意 `focus_mode=0` | 行为差异，按产品取舍（§5-C） |
| `IsAssetButton` `focus_behavior_recursive=2`（4480128） | 与已保留的脚本焦点逻辑配套 | 建议实机确认后补（§5-C） |
| AtlasTexture 图集图标（7e78fbc） | 纯资源用法 | 否（散图均在） |
| `HoldToShowCheck` tooltip（1.4.x 有，Branch 无） | Branch `ec12141` **有意**删除 | 否（Branch 决策） |
| 拍平结构 + unique_id | 4.7 编辑器格式产物 | 否（纯格式） |

### 脚本层函数集归属
- `assets_panel.gd`：1.4.x 函数集是 Branch 子集（Branch 多 `clear_cycle_choice` / `_on_is_cycle_checkbox_changed` / `_on_delete_cycle_mouse_entered/exited`）。取 Branch 版合理。
- Branch 版 cycle 删除实现比 1.4.x 更完整：1.4.x 是 `remove_at` + 留下 `TODO: move forward remained IDs`（编号不前移的已知缺陷）；Branch 版会清理关联 sprite 的 cycle 绑定、把后续编号前移并刷新 CycleItemTree。**取 Branch 属增强而非丢失**。

---

## 4. 合流现状与 Branch 的 1 行差异（已正确修复）

```
445: [connection signal="changed" from="CycleGrid/CheckBox"...  （Branch 版，信号已废弃）
445: [connection signal="toggled"  from="CycleGrid/CheckBox"...  （合流版，正确）
```
合流提交把 Branch 版 assets_box.tscn 里 CheckBox 的无效 `changed` 连接修为 `toggled`（4.x 中 CheckBox 无 `changed` 信号，原连接会报错/失效）。**此项无需再动**。

---

## 5. 需要手动合并 / 注意的点（按优先级）

### ⚠️ P1-A【缺陷·必修】Cycle 三脚本多语言被覆盖（Branch 修复丢失）
合流裁决 CycleToggles / CycleForward / CycleBackward **取 1.4.x 版**，而 1.4.x 版是裸字符串写法，Branch 版已修为 `tr()`。当前产物共 **9 处**直接显示 key 文本（`TR_AWAITING_INPUT` / `TR_BIND_KEY` 词条在 `translations.csv` 中均存在且有翻译，UI 会显示 "TR_AWAITING_INPUT" 原文而非 "Awaiting Input…"）：

```
Scripts/UI/RightPanel/CycleToggles.gd    : 12, 33, 35
Scripts/UI/RightPanel/CycleForward.gd    : 11, 31, 33
Scripts/UI/RightPanel/CycleBackward.gd   : 11, 32, 35
```
**手动合并方案**：直接以 Branch 版（`git show 1bee220:<path>`）覆盖三个脚本即可 —— Branch 与 1.4.x 版仅差 `tr()` 包装与空行，无逻辑分歧，无风险。

### ⚠️ P1-B【缺陷·建议修】AssetStateButton 合成版残留硬编码英文
合成版 `_on_should_dis_remap_button_toggled` 中：

```gdscript
%ShouldDisList.set_item_text(id, "Awaiting Input.")   # 合成版 = 1.4.x 写法
%ShouldDisList.set_item_text(id, tr("TR_AWAITING_INPUT"))  # Branch 版（被覆盖）
```
同样属 Branch 多语言修复被 1.4.x 写法覆盖。**手动合并方案**：该 1 行改回 `tr("TR_AWAITING_INPUT")`。

### 🟡 P2-C【实机确认】资产盒控件焦点行为
- 1.4.x（edface4/4480128）逐步给资产盒控件**开启**键盘焦点（`focus_mode=1`），Branch 版**关闭**大量控件焦点（`focus_mode=0`，含 CycleChoiceSprite/CycleChoice/AddCycle/DeleteCycle 等）。合流产物 = Branch 行为。**鼠标用户无感**；需确认产品是否要求 Tab 键盘可达（无障碍/平板场景）。
- 4480128 的脚本逻辑（`set_focus_mode(FOCUS_ALL)` 录制焦点 + `InputEventKey` 白名单）已保留，但其配套 tscn 行（`IsAssetButton` `focus_behavior_recursive=2`）缺失。请实机验证：**点 "Bind Key" 录制热键 → 按任意键 → 按钮文本更新、焦点不卡死**；以及消失键 Remap 流程。若异常，补 `focus_behavior_recursive = 2` 到 Branch 版 tscn 的 `IsAssetButton` 节点。

### 🟢 P3-D【可选】图标资源风格统一（图集 vs 散图）
Branch 版 assets_box 图标引用散图 png（文件在两分支及工作区均存在，无缺失风险）；1.4.x 7e78fbc 已把这些按钮切到 `ui_buttons.png` 图集（A14 风格）。功能等价。若产品统一图集化再处理，可把 4 个图标改回 AtlasTexture 引用（参考 1.4.x 版 sub_resource 定义）。

### ✅ 明确不需要处理
- edface4 blink fix 主体（三个对象脚本 + reaction_config）—— 已保留；
- 4480128 的 AssetStateButton 改动 —— 已保留；
- 2dd3967 拼写修正 —— Branch 版本就正确；
- 7e78fbc 图集化 —— 无资源缺失；
- `ShouldDisLabel` / `HoldToShowCheck` tooltip 等 Branch 主动取舍 —— 尊重 Branch 版 UI 决策。

---

## 6. 风险提示（主动报告）

1. **不建议整文件回滚**：若把 `assets_box.tscn` 换回 1.4.x 版（369 行），将丢失 CycleItemTree（周期树管理入口）、cycle 删除的绑定清理+编号前移逻辑、`InclusiveKeyCheck`/`min_duration`/`cast_time`/`auto_show` 等 B2/B3 全部功能字段与配套脚本调用 —— 回归面远大于本次修复收益。
2. **与 1.4.x 上游的后续同步**：1.4.x 若继续在 assets_box.tscn / AssetStateButton.gd / Cycle* 上演进（如 edface4 之后的修复），因本文件已与 1.4.x 分叉且 Branch 已弃维护，需人工以"Branch 版为底座、逐项搬 1.4.x 修复"的方式处理，git 三方合并会持续冲突。建议在项目约定中把 assets_box 标注为"Branch 版底座 + 人工搬运修复"。
3. 本地化回归项建议纳入测试：中文界面下操作资产盒 cycle 键绑定 / 消失键 Remap / IsAsset Check，观察按钮与列表项文本是否出现裸 "TR_XXX" key（对应 P1-A / P1-B）。

---

---

## 7. 修复执行记录（2026-09-06，用户决策后）

**用户方针**：Branch 无额外改动的部分一律以 1.4.x 为基底（图集 / focus / unique_id 全保留）；Branch 只取其功能增量（B2 cycle 树 / B3 配置字段 / 冲突裁决项）；P1 两处多语言缺陷获批修复；P2 的 `focus_behavior_recursive=2` 一并合入待用户实测。

### 7.1 已修改文件（6 个，均未提交）

| 文件 | 改动 |
|---|---|
| `UI/.../MiniComponents/assets_box.tscn` | **重建为合成版**：1.4.x 版（369 行）为基底 + Branch 功能增量。保留：ui_buttons.png 图集图标×4、全控件 `focus_mode=1`/`focus_behavior_recursive=1`、`IsAssetButton` `focus_behavior_recursive=2`（4480128）、26 处 `unique_id`、拍平结构；叠加：InclusiveKeyCheck / MinDuration / IgnoreIfRest / CastTime / AutoShow / CycleDeleteTip / CycleItemTree + 对应 8 条连接 + `toggled` 修复。去 Branch 装饰（散图 icon、ShouldDisLabel、隐藏 VSeparator） |
| `Scripts/UI/RightPanel/CycleToggles.gd` `CycleForward.gd` `CycleBackward.gd` | 直接取 Branch 版（P1-A）：9 处裸 `"TR_..."` → `tr("TR_...")`，消除多语言显示 bug |
| `Scripts/UI/States/AssetStateButton.gd` | P1-B：`"Awaiting Input."` → `tr("TR_AWAITING_INPUT")` |
| `Localization/translations.csv` | 补 11 条缺失词条（en 取 Branch 原文，ru 俄译），修复 5 行 CSV 引号列错乱 |

### 7.2 验证结果

| 验证 | 结果 |
|---|---|
| 静态校验（54 节点 / 26 连接 / 脚本 % 引用 / 连接方法） | 全部通过，0 错误 |
| headless 实例化 assets_box.tscn | `ASSETS_BOX_TEST_OK`，脚本挂载正确，无 SCRIPT ERROR |
| 无头编辑器全量编译（`--headless --editor --quit`） | 0 Parse Error / Compilation failed |
| 全项目无头 180 帧回归 | 0 ERROR / SCRIPT ERROR（已知噪音除外） |
| CSV 结构（python csv 校验） | 0 坏行，11 新词条 3 列齐 |

### 7.3 待用户实机确认
1. **focus 行为**：资产盒 Bind Key / 消失键 Remap 录制流程（合成版已含 `focus_behavior_recursive=2`，如无异常即以此为准）。
2. **B3 控件词条**：需在编辑器重导入 `translations.csv`（`--editor` 或 GUI 打开触发）使 11 条新词条进入 `.translation`，否则运行时 `tr()` 仍取不到（显示 key 原文）。
3. **发现但未处理（超出本文件范围）**：合流 `translations.csv` 仅有 `keys,en,ru` 三列，**无中文列**——Branch(4.4) 用户的简中界面（B14）在合流产物中缺失，若需中文界面需另行加列（涉及 LanguageManager/字体，建议单独任务）。

### 7.4 环境备注
- headless `--editor --quit` 会因本机 APPDATA 为空把编辑器数据落到工作区根（`Godot/` 目录）并可能重写已打开场景（本次 top_ui.tscn popup id 噪音，已还原）；跑编辑器命令前应先 `export APPDATA="C:/Users/Admin/AppData/Roaming"`（同 gh 凭据坑），且跑完 `git status` 核对无编辑器噪音改动。

## 附录：核查命令速查（复现用）

```bash
# 三方 blob 对比
git show c45aa8f:UI/EditorUI/RightUI/Components/MiniComponents/assets_box.tscn > /tmp/v14x.tscn
git show 1bee220:UI/EditorUI/RightUI/Components/MiniComponents/assets_box.tscn > /tmp/vb.tscn
diff /tmp/vb.tscn UI/EditorUI/RightUI/Components/MiniComponents/assets_box.tscn   # 应仅 445 行 toggled 差异

# 提交逐项
git log 1.4.x --oneline -- "**/assets_box.tscn"          # 7e78fbc/2dd3967/edface4/4480128
git log Branch_ec121415 --oneline -- "**/assets_box.tscn" # 3417fa5/ec12141/36b75d4(02842fb merge)
git show edface4 --format="" -- Scripts/UI/States/AssetStateButton.gd
git diff 1bee220 HEAD -- Scripts/UI/States/AssetStateButton.gd | grep '^-'   # 合成删的26行=Branch旧写法
```
