# little knight

Godot 4.7.2 的二维动作手感试验。目标是接近空洞骑士的跑、跳、冲刺和近战衔接。目前没有攻击判定、敌人、伤害和受击。

启动调试：

```powershell
Start-Process "C:\Users\eric_\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" -ArgumentList '--path','e:\little_knight'
```

## v0.0.1

提交：`4d02a18`（2026-10-13）  
说明：`v0.0.1-simple 2D demo-character move`

第一版可玩的移动演示。

- 角色是黄色方块，武器是两把斧头占位。场景用 `art/tile_brick.png` 按文本布局搭出测试房间。
- 移动：按下方向立刻达到跑步速度，松手立刻停下，空中同样。跳跃有短跳、土狼时间和跳跃缓冲，离地后再跳一次。冲刺是水平的，落地刷新冷却。
- 轻击和重击已有预备、出手、收招计时。出手时显示斧头；空中重击强制下砸。冲刺可以在攻击任意阶段开始，攻击计时继续走。冲刺途中不能再攻击。
- 时长写在秒上。攻击期间仍能移动和转向。
- 设计笔记在 `design/deepseek_thought.txt`。

## v0.0.2

相对 v0.0.1。手感、角色和待机、走、跑都已提交。

### 已提交

`c07ad10`（2026-10-16）  
说明：`v0.0.2-simple 2D demo-character art design`

- 手感定稿写进 `design/simple_move_v1.md`，角色定稿写进 `design/simple_character_v1.md`。时长改为毫秒，速度仍是像素/秒。
- 地面攻击锁住水平速度、朝向和新的跳跃。空中轻击保持原来的水平速度。只有收招窗口能用冲刺取消，并立刻结束这次攻击：轻击整段 90 毫秒，重击前 120 毫秒。预备和出手阶段的冲刺输入直接丢掉。
- 角色换成橄榄绿斗篷、猫耳兜帽。剑单独一张，背在身后，攻击时挥到身前。碰撞按大约 128 像素高的身体计算，不跟着大图边距变。
- 黄色方块、两把斧头和旧设计笔记已从工程里拿掉。PNG 走 Git LFS。

`62ab321`（2026-10-16）  
说明：`v0.0.2-simple 2D demo-fix .gitignore`

- `.gitignore` 收成只忽略 `.godot/`。

`c6769d0`（2026-10-16）  
说明：`v0.0.2-simple 2D demo-run,walk,idle animation`

- 待机、走、跑接进角色，按源视频 24 帧每秒循环。站着播待机（241 帧）。方向键播跑，用选出的 50 帧，速度仍是 420。按住 Ctrl 播走（241 帧），速度 200。
- 镜头不再缓追，避免移动时边缘发虚。
- 砖块改到 `art/map/tile_brick.png`，格子仍是 128。
- `art/reference/` 和 `art/resource/` 不进 Godot，也不进 git。`art/character/` 和 `art/map/` 保留。

## v0.0.3

相对 `c6769d0`。还没提交。2026-10-20。

跳跃、冲刺姿势和轻击刀光接进了演示。没有攻击判定，重击先拿掉了。

### 跳跃

- 空中用 `art/character/v2/jump/air`，落地用 `jump/land`，落地动作 0.2 秒。按住方向上升时停在 `jump_up/selected` 的最后一帧；一开始下落就回到 `jump/air` 的下落。
- 每一帧按自己的脚钉在碰撞盒底边上，画布里的升降不会再叠一次。
- 空中冲刺会把垂直速度清成 0，结束后只下落、不再上升，并接上下落动作。

### 冲刺

- 180 毫秒播 `art/character/v2/dash/dash.png` 这一张，地面和空中同一姿势。高度和待机对齐，披风留在身后，脚落在碰撞盒底边。
- 这张图的灰底和水印已去掉，旧脚掌改成现在的短黑脚。

### 轻击

- 攻击没有身体姿势，身体继续走、跑或跳。剑不再挂在身上。
- 刀光是 `art/character/v2/attack/light/` 里的 8 帧，从笔尖沿弧线画到完整的一刀。挂在图片中心，放在角色身前半格（64 像素）。
- 前摇 50 毫秒不显示刀光。出手 70 毫秒里前几帧走得快，这一段结束就画满。后摇 90 毫秒停在最后一帧。
- 攻击时可以继续走和跑，这一下挥完之前不转向，也不能起新的跳。后摇整段仍可以用冲刺取消。冲刺途中不能攻击。

### 拿掉的

- 重击和空中加速落地已从操作里去掉，右键不再出手。对应的时长、力度和下砸速度也从 `movement_tuning.gd` 里删了。

### 图的位置

- 游戏在用的帧仍在 `art/character/v2/`。这个文件夹没有挪走。
- 旧的 v1 立绘、剑的贴图，以及不再使用的刀光草稿，放到 `art/character/explore/`。方向探索图收进 `explore/character_direction/`。
