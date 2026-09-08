# PNGTuber-Remix 合流版变更清单（供全量测试）

> **合流对象**：`1.4.x`（上游主线） × `Branch_ec121415`（4.4 功能分支）
> **文档目的**：给测试人员提供"更新到合流版后改了什么"的逐条清单，含来源标注与测试入口。
> 生成日期：2026-09-04 ｜ 生成依据：git 拓扑 + 双亲 diff + 代码现状核查（非文档转述）

---

## 0. 基线信息（先读）

| 项 | 值 |
|---|---|
| 合流产物分支 | `ec121415-merge-14x`（本工作区），HEAD `c448b93`（2026-09-09；`6295d64` 之后修复提交见附录续表） |
| 合流提交 | `65dba08` Merge Branch_ec121415 into 1.4.x（2026-09-02） |
| 1.4.x 侧（P1） | `c45aa8f`（合流时 tip） |
| Branch 侧（P2） | `024e51c`（合流时 tip；本地分支现指针 `1bee220` 为合流后 4.4 侧 1 个同步提交，该分支已弃维护） |
| 两分支共同祖先 | `b4119bd`（以此点为"合并前基线"划界） |
| 应用版本 / 引擎 | `config/version = "1.4.7"` ｜ `config/features = "4.7"`（Godot **4.7.2**；Branch 原为 4.4.1/1.4.1） |
| 主场景 | `res://UI/Menu/menu.tscn` |
| 扩展布局 | `addons/`（CustomMesh / GI / godotgif / miniaudio 均在此；Branch 原为根级 GI/CustomMesh） |
| Autoload（13） | VersionConverter、Global、LoadMisc、SaveAndLoad、Settings、GlobalAudioStreamPlayer、LipSyncGlobals、GlobalMicAudio、WebsocketHandler、GlobInput、CommandLine、**Tracker（新增）**、LanguageManager（新增） |

### 口径说明（重要）

1. **来源三值**：`1.4.x`＝仅主线侧引入；`Branch`＝仅 4.4 功能分支引入；`合成`＝两分支都改动、由合流提交裁决合成；`工程`＝合流后本工作区修复链（`65dba08..HEAD` 共 9 提交，非产品功能层）。
2. **对照基线**：1.4.x 用户升级 → 重点看 B/C 区；Branch(4.4) 用户升级 → 重点看 A/C/D 区 + 引擎迁移（4.4→4.7.2）。
3. **非本次增量**：`Hold to Show`、热键循环显隐（commit `1a0497a` 族）位于两分支共同祖先，合流前双方已具备，**不算本次新功能**；但 Branch 在其基础上**新增的 min_duration / cast_time 等配置字段是本次增量**（见 B3）。
4. **冲突裁决结果**（出自 `65dba08` 提交说明）：movement / animation_tab 取 1.4.x 版；properties / model_effects 手工合成；Settings_popup 取 1.4.x 基线 + 插入 Branch 热键区块；assets_box 整文件取 Branch。详见 C 区。
5. 引擎自检命令（无头 180 帧，仅看 ERROR/SCRIPT ERROR，已知噪音清单见 `.ai/AGENTS.md` §2.2）：
   `"E:/Godot/Godots/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --quit-after 180`

---

## A 区 — 来源：1.4.x（主线增量；Branch 用户升级重点）

| # | 功能/改动点 | 变更内容与大致作用 | 主要文件定位 | 测试要点 |
|---|---|---|---|---|
| A1 | **投掷物系统（新功能）** | 从模型丢出带物理的贴图物体：质量/摩擦/弹跳/吸收/重力/惯性/碰撞形状/贴图+音频；支持极坐标分布、暂停/继续、自定义键位、websocket 触发；修复 Select Images 弹窗自动关闭 | `Scripts/Misc/throwable/throwables.gd`、`throwable.gd`、`Scripts/Misc/throwable_resource.gd`、`Misc/throwables/throwable.tscn`、`Scripts/UI/RightPanel/fun_stuff.gd` + `UI/EditorUI/RightUI/Components/fun_stuff.tscn`（配置面板）、`OnlineDoc/throwables.md` | 添加投掷物→丢出→碰撞/弹跳/落地；暂停即时停；websocket 指令触发；多个同屏不卡 |
| A2 | **编辑器参考网格 + 位置吸附** | 画布网格随相机缩放绘制（X/Y 轴高亮）；网格开关/尺寸可配；对象移动支持位置吸附 | `Scripts/UI/Others/grid.gd`；网格开关 `Global.grid_visible`/`Global.grid_size` | 开关显示、格子大小调整、开启吸附后拖动对象贴格 |
| A3 | **网格变形 / 笔刷 / Mesh 面板增强** | 网格对象新增扭曲（warp）、形变笔刷、生成参数与分层管理增强，配套新 Mesh UI 面板 | 新增 `Scripts/Objects/mesh_warps.gd`、`Scripts/Misc/deform_brush.gd`、`UI/mesh_panel.tscn`；改 `Scripts/Objects/mesh_object.gd`、`custom_mesh_base.gd`、`mesh_editor.gd`、`Scripts/UI/RightPanel/mesh_deform_grid.gd`、`mesh_gen_script.gd`、`mesh_layer_manager.gd` | 创建网格对象→笔刷变形→warp→面板参数实时生效；网格分层切换 |
| A4 | **追踪后端框架（OpenSeeFace，新）** | 新增统一追踪后端：监听 UDP 127.0.0.1:11573、68 点，输出嘴形/眨眼信号；提供 OpenSeeFace 数据源实现与引用类型；Autoload `Tracker` | 新增 `Scripts/Trackings/TrackingBackend.gd`、`OpenSeeFaceBackend.gd`、`TrackingRef.gd`；`project.godot` autoload | 无追踪软件时不报错；接 OpenSeeFace 数据驱动口型/眨眼（需外部程序） |
| A5 | **Follow 跟随组件族重构** | 跟随逻辑拆分为基础/旋转/缩放组件（含鼠标坐标、左右轴输入、rest 状态），配套 movements 逻辑调整 | `Scripts/Objects/ObjectComponents/follow_component.gd`（重构）、新增 `follow_component2.gd`、`follow_rotation.gd`、`follow_scale.gd`、`Scripts/Objects/ObjectComponents/movements.gd` | 各跟随类型（鼠标/旋转/缩放/跳跃忽略）行为正确；静态物体不漂移 |
| A6 | **物理引擎恢复默认 + 抖动抑制** | 物理引擎由 dummy 切回引擎默认，降低物理抖动（影响软体附件/投掷物模拟） | `project.godot`（physics 相关设置）、`Main/Scripts/main.gd` 等物理调用路径 | 开启物理的 appendage 摆动顺滑；投掷物手感正常；无 jitter |
| A7 | **WebSocket 增强** | 可见性同步与主键触发（master key）；支持投掷物暂停等指令；配套流工具配置与文档 | `Main/Scripts/websocket_handler.gd`、`UI/StreamUI/web_socket_config.gd/.tscn`、`StreamTopUI.tscn`、`OnlineDoc/websocket.md` | 连线→指令控制资产显隐/主键/投掷；断线重连 |
| A8 | **备份与自动保存修复** | 自动保存不再错乱；备份更安静（不频繁打扰）；备份路径 `/Backups` 逻辑修正 | `Main/Scripts/SaveAndLoad.gd`（`save_backup` 等）、`Main/Scripts/main.gd` | 编辑后自动保存；手动存盘产生 _backup 文件；重启恢复 |
| A9 | **层级树 Layers Tree 重构（1.4.x 侧）** | 层级树代码重写：崩溃修复、拖拽/缩进/显隐逻辑稳定化；LayerView 旧目录与图标整合 | `Scripts/UI/LeftPanel/layers_tree.gd`、`layers_scripts.gd`、`layers_panel_scripts.gd`、`UI/EditorUI/LeftUI/Components/LayersPanel.tscn` | 多层拖拽/重命名/显隐/折叠不崩溃；大模型树流畅（Branch 侧亦改此文件，见 C7） |
| A10 | **全局输入后端更新** | GI 扩展由 uiohook 改为原生输入捕获：X11/wayland 适配与守卫、Linux dummy 后端；恢复鼠标速度；修复鼠标位置 min/max 与静态对象取值 | `addons/GI/`（二进制+配置）、`Scripts/AutoLoads/global_input.tscn`、`Main/Scripts/monitor_tracking.gd`、输入分发脚本 | 全局热键（桌面任意处）；各 OS 冒烟；鼠标边界 min/max 钳制正确 |
| A11 | **麦克风输入迁移 miniaudio + 泄漏修复** | 麦克风采集从旧方案迁至 miniaudio，修复内存泄漏 | `Main/Scripts/GlobalMicAudio.gd`、`addons/miniaudio/`、`Scripts/AutoLoads/audio_stream_player.tscn` | 麦克风口型驱动正常；长时间挂机内存平稳 |
| A12 | **本地化体系重构（1.4.x）** | 拆分 csv 合并为单一 `Localization/translations.csv`；新增 `LanguageManager` Autoload 支持运行时语言切换；字体精简 | `Localization/translations.csv`、新增 `Scripts/AutoLoads/LanguageManager.gd`、字体目录 | 语言切换即时生效；`tr("TR_XXX")` 无遗漏（含 Branch 补的中文，见 B14） |
| A13 | **菜单 / 项目管理 UI 调整** | ProjectManager 独立场景（project_manager.tscn / project_selector.tscn）移除，入口收敛到 FileManager 流程 | `UI/FileManager/file_manager.tscn`、`Scripts/UI/Menu/menu.gd`、`UI/Menu/menu.tscn`；`Scripts/UI/ProjectManager/*.gd` 仅残留未引用 | 打开工程/最近工程/新建流程通畅；无死链报错 |
| A14 | **UI 资产图集化与整理** | 散图合并为图集（ui_buttons.png / demo_icons.png），LayerView 图标、部分按钮图（Tumblr/Flip 等）清理 | `UI/Assets/ui_buttons.png`、`DemoModels/Icons/demo_icons.png`、`Misc/TestAssets/`、`UI/EditorUI/` 多处 .import | 眼睛/上下移/删除/复制等按钮图标齐全；无缺失纹理红框 |
| A15 | **口型 / 校准 / 指纹等 Lipsync 修复** | godot-lip-sync 相关面板与导入小修 | `UI/Lipsync stuff/godot-lip-sync/*.gd`、`Scripts/Lipsync Scripts/calibration_tree.gd`、`fingerprint_tab.gd`、`inspector_tab.gd`、`lipsync_configuration_popup.gd` | 口型校准、指纹采集、嘴形素材导入正常 |
| A16 | **编辑器杂项修复** | 修剪对话框更新、blink 选项、cycle 修补、跟随移动小修、投掷物 pivot/参数、网格细节（c45aa8f）等一批小修 | 分散于 `Scripts/UI/RightPanel/`、`Scripts/Misc/TrimClass.gd`、`Scripts/UI/States/` | 修剪弹窗；blink 勾选；cycle 按钮行为；Select Images 弹窗不自动关 |
| A17 | **版本号 / CI / 文档** | 版本提至 1.4.7；CI 镜像恢复与 Godot 版本更新；README/OnlineDoc 增补（websocket/throwables/atlas 文档） | `project.godot`、`.github/workflows/_build.yml`、`README.md`、`OnlineDoc/*.md` | 无功能影响；CI 打包可跑（构建验证） |

---

## B 区 — 来源：Branch_ec121415（4.4 功能分支增量；1.4.x 用户升级重点）

| # | 功能/改动点 | 变更内容与大致作用 | 主要文件定位 | 测试要点 |
|---|---|---|---|---|
| B1 | **自定义热键映射（新 UI）** | Settings 新增"自定义热键"：动作↔任意键录制绑定，可关联状态按钮/资产显示/消失/cycle 组；存储于 `settings_dict.custom_hotkeys` | 新增 `Scripts/UI/TopPanel/Components/CustomHotkeyMapButton.gd`、`UI/EditorUI/TopUI/Components/hotkey_item.tscn`；改 `Settings_popup.tscn`、`popup_panel.tscn`、`top_ui.tscn`、`settings_script.gd`、`Scripts/AutoLoads/Settings.gd`、`Main/Scripts/Global.gd` | 录制/改绑/清除键；开关"Detected Hotkeys"后失效；保存重启仍生效；重复键冲突提示 |
| B2 | **周期资产 Cycle** | 资产热键循环：一个组内多资产用一键循环切换，显隐互斥切换；资产盒内周期树管理 | `Scripts/AutoLoads/cycle.gd`、新增 `Scripts/UI/RightPanel/cycle_item_tree.gd`、`Scripts/UI/States/AssetStateButton.gd`、`UI/EditorUI/RightUI/Components/MiniComponents/assets_box.tscn` | 建 cycle 组→热键循环切下一项；切到尾回第一项；显隐互斥正确 |
| B3 | **资产显隐行为配置扩展** | 在共同祖先 Hold-to-Show 基础上新增控制字段：`min_duration`（最短显示时长，防连按抖动）、`cast_time`、`inclusive_key_check`、`saved_keys`/`disappear_keys` 等；反应配置同步扩展 | `Scripts/Objects/SpriteObjectClass.gd`、`Scripts/UI/RightPanel/assets_panel.gd`、`Scripts/Objects/ObjectComponents/reaction_config.gd`、`Scripts/UI/States/AssetStateButton.gd`、`Scripts/UI/LeftPanel/layers_panel_scripts.gd` | 资产键显隐/消失键；按住显示时长；快速连按不抖；反应(表情)触发配置 |
| B4 | **混合模式新 shader 族 + BlendMode 修复** | 新增 Multiply(乘法)/Masking(蒙版透明度)/Add/Sub 四类混合 shader；修复属性面板 BlendMode 下拉取值错位（改用 get_item_index） | 新增 `Scripts/Shaders/SpriteMultiplyShader.gdshader`、`SpriteMaskingShader.gdshader`、`SpriteAddShader.gdshader`、`SpriteSubShader.gdshader`；改 `SpriteObjectClass.gd`、`sprite_object.gd`、`Scripts/UI/RightPanel/properties_script.gd` | 各混合模式渲染正确（4.7 下）；蒙版区域透明；与颜色/染色叠加正确；切换状态后混合保持 |
| B5 | **Skew 斜切 + 变换统一** | 对象位置/旋转/缩放/斜切统一经 `apply_transform()` 一次性应用（修复合成遗漏与性能）；Skew 控件在属性面板平铺布局 | `Scripts/Objects/append_object.gd`、`sprite_object.gd`、`SpriteObjectClass.gd`、`Scripts/UI/RightPanel/properties_script.gd`、`UI/.../properties.tscn`、`model_effects.tscn` | 斜切值调节；翻转(F/H/V)后斜切方向正确；状态切换保持；无性能回退 |
| B6 | **RawMouseInput + StandGlobalInput 输入路径** | 桌面低层原始鼠标输入（相对移动/高精度）；StandGlobalInput 接线至 global_input 场景；gdextension 4.5 绑定重编版（4.7.2 可加载） | `RawMouseInput/rawmouseinput.gdextension` + `windows/*.dll`、新增 `Scripts/Global/StandGlobalInput.gd`、`Scripts/AutoLoads/global_input.tscn` | Windows 鼠标跟随平滑；与 GI 后端共存不冲突；窗口化/透明窗下边界正确 |
| B7 | **编辑器状态持久化 / 撤销修复** | 状态==当前状态时切状态不再误保存；ZIndex 正确保存；colored/tint（颜色/染色）跨状态切换正确；撤销还原修复；状态按钮不再锁死 | `Scripts/UI/RightPanel/properties_script.gd`、`Scripts/UI/States/StateButton.gd`、`StateRemapButton.gd`、`StatesStuff.gd`、`Scripts/AutoLoads/UndoRedoManager.gd` | 切换状态→颜色/染色/斜切随动；撤销/重做链完整；ZIndex 保存后重载一致；按钮状态不卡死 |
| B8 | **窗口交互修复** | 小窗无边框拉伸修复；小窗拖动时鼠标穿透空白区域（点击穿空） | `Scripts/UI/WindowHandler/window_handler.gd`、`extra_window.gd`、`UI/control.tscn` | 边框拖拽缩放各向正确；点击透明/空白区可穿透到桌面；双屏不越界 |
| B9 | **控件改进（Slider/Spinbox/Toggle）** | 长按增减按钮可连续拖动修改；Spinbox 大值域（PositionX/Y 至 10000/-359..359）；Toggle 交互修正 | `UI/BetterSlider/better_slider.gd`、`better_Spinboxesgd.gd`、`BetterToggles.gd`、`better_slider.tscn`、`better_spinboxes.tscn` | 长按增减；拖拽滑条；输入大数值/负值不被钳死 |
| B10 | **wiggly appendage 跟随全局变换** | 软体附加肢体在模型整体缩放/旋转下正确跟随（全局变换一致性） | `addons/wiggly_appendage_2d/wiggly_appendage_2d.gd`、`Scripts/UI/RightPanel/wiggle_appendage.gd`、`wiggle.tscn` | 缩放/旋转整个模型时附件不脱节不拉伸变形 |
| B11 | **右面板可滚动** | 属性/特效等右面板改 ScrollContainer，矮窗口可用 | `UI/EditorUI/RightUI/Components/properties.tscn`、`model_effects.tscn`、`animation_parameters.tscn` 等布局 | 低分辨率窗口下右面板全部控件可达 |
| B12 | **启动音频时序修复** | 修复启动时音频设备过早重启触发的问题（AudioSystem 时序，原理待考） | `Scripts/AutoLoads/Settings.gd`、`audio_stream_player.tscn`、`GlobalAudioStreamPlayer` | 冷启动无爆音/无声；设置页切设备不重启错乱 |
| B13 | **性能优化批** | 帧内重复计算收敛、渲染路径减负（多文件批量优化） | 分散于 `Scripts/Objects/`、`Scripts/UI/RightPanel/`、`Main/Scripts/` | 大模型/长会话 FPS 稳定；切换状态无卡顿尖峰 |
| B14 | **简体中文本地化补充** | 大量界面文本 TR_XXX 化并补中文词条（叠加在 1.4.x 单表结构上） | `Localization/translations.csv`（中文条目）、`UI/` 多处 .tscn 文本 | 中文界面无遗漏英文；切换 EN 正常 |

---

## C 区 — 双源合成 / 冲突裁决（重点回归区）

| # | 功能/改动点 | 裁决结果与现状 | 主要文件定位 | 测试要点 |
|---|---|---|---|---|
| C1 | **合流冲突裁决总览** | movement/animation_tab 取 1.4.x；properties/model_effects 手工块合成；Settings_popup 1.4.x 基线+Branch 热键区块；assets_box 整文件取 Branch；Global.gd/sprite_object.gd 缩进损坏修复；assets_box CheckBox `changed→toggled` 无效连接修复 | 合流提交 `65dba08` | 逐面板冒烟：属性页（Skew/连接）、模型特效页、设置页热键区、资产盒、movement 页、动画 Tab 无断连 |
| C2 | **Global 信号总线 / 入口逻辑合成** | 两侧均扩充 Global 信号与引用注册（Branch 侧大量信号、1.4.x 侧扩展），合成后信号链完整 | `Main/Scripts/Global.gd`、`Main/Scripts/main.gd`、`SpritesContainer.gd`、`SaveAndLoad.gd` | 对象创建/删除/切换状态/显隐等跨系统信号全部正常触发（重点 regression） |
| C3 | **properties / model_effects 合成区** | Skew 平铺 Layouts、控件 connection 直连为手工合成结果 | `UI/EditorUI/RightUI/Components/properties.tscn`、`model_effects.tscn`、`Scripts/UI/RightPanel/properties_script.gd`、`model_effects.gd` | 属性页所有滑条/输入框/按钮可操作且写回正确；特效页参数联动 |
| C4 | **assets_box 合成区（取 Branch）** | 资产盒 UI 采用 Branch 版（周期资产入口/资产列表）；连接修复 changed→toggled | `UI/EditorUI/RightUI/Components/MiniComponents/assets_box.tscn`、`Scripts/UI/RightPanel/assets_panel.gd` | 资产增删/换图/排序/勾选 cycle 均正常；CheckBox 状态即时生效 |
| C5 | **Settings_popup 合成区** | 1.4.x 基线 + 插入 Branch 自定义热键区块（HotkeyItemList） | `UI/EditorUI/TopUI/Components/Settings_popup.tscn`、`hotkey_item.tscn`、`Scripts/UI/TopPanel/Components/settings_script.gd` | 设置页除热键外其余项（检测/音频/画质/快捷键总开关）无回归；热键区块完整可用 |
| C6 | **movement / animation_tab 裁决提示** | 取 1.4.x 版：Branch 在此处的语义改动（含部分跳跃/物理语义）未进入合流产物，以 1.4.x 行为为准 | `UI/EditorUI/RightUI/Components/movement.tscn`、`animation_tab.tscn`、`Scripts/UI/RightPanel/movement_tab.gd`、`animation_tab.gd` | ① Branch(4.4) 老用户如有依赖旧 movement 行为的场景请复核提报；② 1.4.x 用户按原行为回归 |
| C7 | **reaction / 计算 / wiggly 双源改动** | reaction_config.gd、global_calculations.gd 两侧均改；wiggly_appendage_2d.gd 双方优化合成 | `Scripts/Objects/ObjectComponents/reaction_config.gd`、`Scripts/Global/global_calculations.gd`、`addons/wiggly_appendage_2d/wiggly_appendage_2d.gd`、`Scripts/UI/LeftPanel/layers_panel_scripts.gd` | 反应(表情/音频)触发、层级面板联动、附件跟随三项冒烟 |

---

## D 区 — 合流工程修复（本工作区修复链 `65dba08..HEAD`，全体回归）

| # | 改动点 | 内容与作用 | 提交 | 测试要点 |
|---|---|---|---|---|
| D1 | **RawMouseInput 重编（4.5 绑定）** | 用 godot-cpp 4.5 绑定重新编译 dll，实测 4.7.2 可加载（GDExtension 4.x 向后兼容） | `b8918d5` | Windows 输入后端正常；无 raw input 加载失败 |
| D2 | **main.tscn 直跑噪音清理** | 清理 4 个上游遗留失效 UI 引用（light_source UI 路径等），根治启动 SCRIPT ERROR 噪音（4.4 侧同步提交 `1bee220`） | `a3077ac`（对应 `7abf312`/`1bee220`） | 启动日志干净；光源/灯光控件不失效 |
| D3 | **SpriteObjectClass shader/blend 修复** | shader 与混合纹理改 const preload；set_blend 幂等短路；legacy-blend 兜底——修复 4.7 下 Branch 新混合模式（B4）的稳定性 | `10c4044` | 所有混合模式/旧存档混合值加载不报错；切换状态外观正确 |
| D4 | **default_bus_layout 引用修复** | project.godot 以 `res://` 路径引用总线布局 + 补 .uid 旁文件 + 接受编辑器删行——根治冷启动 Unrecognized UID 噪音 | `84d2b3e`、`9d7eb5b`/`88da450`、`6295d64` | 冷启动（删 .godot/uid_cache 后）无 UID 报错；音频总线/音量正常 |
| D5 | **main_scene 路径化** | 主场景引用由 uid 改为 `res://` 路径，消除 uid 解析依赖 | `c49d188` | 任意入口启动到菜单正常 |
| D6 | **follow_component 死绑定清理** | 移除失效的 follow_component unique-node 绑定 | `f2fbab3` | Follow 型对象创建/存档加载无 Null 引用 |
| D7 | **引擎迁移 4.4→4.7.2（总体）** | features=4.7；GI/godotgif/CustomMesh/miniaudio/RawMouseInput 五类 GDExtension 在 4.7.2 下全部可加载（二进制勿动） | 合流 + D1 | 透明窗口、SubViewport、OBS 捕获、全局热键全功能在 4.7.2 冒烟 |
| D8 | **MCP 工具链（非产品功能）** | 编辑器插件 Godot MCP Native v1.0.8 + gdmcp CLI（端口 9081） | `1eb18e4` | 不参与产品测试；注意导出/CI 时 addons/godot_mcp 若被打包含入不影响运行 |

---

## 测试优先级建议（按本次合流风险排序）

| 优先级 | 范围 | 理由 |
|---|---|---|
| P0 冒烟 | B 区全部新功能（热键映射/cycle/min_duration/混合模式/Skew）+ C1–C5 合成面板 + D3 | 本次合流真正"新增/拼接"的功能面，风险最高 |
| P1 回归 | A1/A2/A4/A5/A7（大功能在合流产物中的完整性）、A9/A10 输入与层级、B7/B8 状态与窗口 | 两侧代码交汇区，易出交互回归 |
| P2 常规 | A 区其余行、B12–B14、D2/D4/D5/D6 噪音与引用修复、E 类工程整理 | 改动小但需确认无副作用 |
| P3 构建 | A17 CI、D8 导出、GDExtension 兼容（D7） | 打包/换机场景 |

**回归基线建议**：保存/加载（旧 4.4 存档 → 4.7 迁移）、撤销/重做、状态机切换、层级树拖拽、全局热键、麦克风/口型、透明窗捕获 —— 7 条主链路逐条过。

---

## 附录：Git 追溯（关键提交）

| 引用 | 提交 | 说明 |
|---|---|---|
| 共同祖先 | `b4119bd` | 1.4.x 与 Branch 的分叉点（合并前基线） |
| 1.4.x tip | `c45aa8f` | 合流时 1.4.x 侧；1.4.x 相对祖先 234 提交 |
| Branch tip(合流时) | `024e51c` | 合流时 Branch 侧；Branch 相对祖先 19 提交 |
| Branch 现指针 | `1bee220` | 合流后 4.4 侧 1 个同步提交（D2 的 4.4 版），分支已弃维护 |
| **合流提交** | `65dba08` | Merge Branch_ec121415 into 1.4.x（含裁决说明） |
| 合流后修复链 | `1eb18e4 → b8918d5 → a3077ac → 10c4044 → 84d2b3e → 9d7eb5b → c49d188 → f2fbab3 → 6295d64` | D 区对应提交 |
| 6295d64 后收尾（09-04→09-09） | `4955a52`(assets_box 合流布局重建 + cycle tr 恢复) ／ `af13c49`(effect size 标签同步、lipsync 守卫) ／ `4f8360c`(合流 changelog + assets_box 双源审查报告) ／ `4bef687`(translations 增 zh_CN 列 B14) ／ `23c9b23`(恢复 Branch 丢失的状态重映射控件 %StateHoldToShowCheck 等 + 三处鼠标绑定捕获区) ／ `978bdc7`(miniaudio UTF-8 设备名修复 DLL 落地) ／ `20227cc`(Grid 菜单中文化、Window 菜单 id 与枚举对齐) ／ `8e041fe`(movement 栈移除、sprite_show/hide 签名简化、调试残留清理) ／ `54ffc1b`(场景 unique_id 补全、wiggle 面板参数修正、project 设置) ／ `c448b93`(extra window 居中/非 transient 显示) | 合流回归收尾 |

**Branch 侧 19 提交功能索引**（B/C 区来源依据）：`3417fa5`（资产/状态/动画特性、自定义热键、Multiply shader、翻译、右面板滚动）、`a726107`（apply_transform 统一 + wiggly 跟随）、`43aa18e`（Masking 蒙版、raw mouse 准备）、`1295a53`（启动音频时序、raw mouse、BlendMode bug）、`f8a0f4e`/`59a71d6`（性能优化）、`19e8f75`（movement 语义，裁决未入产物见 C6）、`ec12141`（跟随运动/窗口穿透/长按拖动）、`61d4186`（窗口拉伸/状态锁死/撤销还原/Skew 修复）、`ab409c9`/`0115e3c`/`70c3fb0`/`36b75d4`（状态/ZIndex 持久化系列）、`abaed1a`（StandGlobalInput 修复）、`0577df9`/`2ea1194`/`2b0b501`/`02842fb`/`024e51c`（merge/杂项）。

**1.4.x 侧代表性提交**（A 区来源依据）：投掷物 `be1a45b`/`31763a2`/`724b8c0`(PR#98 暂停)/`c246c07`(PR#99 极坐标)/`04f1f0d`/`f801997`；网格 `760c352`(PR#126 吸附)/`c45aa8f`；Layers `0cc946d`/`26010fb`；4.7 升级 `4585353`/`27201fe`；物理 `946dfd1`/`0d3c3b4`；输入 `ac19b75`/`1a755a3`/`2df6e8b`；mic `22dae25`/`f28336b`；备份 `587a5a0`/`0790bd2`；CI `44a3c84`/`fe12105`。
