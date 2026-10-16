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

尚未提交。下面是当前工作区相对 v0.0.1 的内容。

- 手感定稿写进 `design/simple_move_v1.md`，角色定稿写进 `design/simple_character_v1.md`。时长改为毫秒，速度仍是像素/秒。
- 地面攻击锁住水平速度、朝向和新的跳跃。空中轻击保持原来的水平速度。只有收招窗口能用冲刺取消，并立刻结束这次攻击：轻击整段 90 毫秒，重击前 120 毫秒。预备和出手阶段的冲刺输入直接丢掉。
- 角色换成橄榄绿斗篷、猫耳兜帽的立绘，剑单独一张。背在身后，攻击时挥到身前。碰撞仍按原来约 128 像素高的身体计算，不跟着大图边距变。
- 黄色方块、两把斧头和旧设计笔记已从工程里拿掉。砖块图加回 `art/tile_brick.png`，格子固定 128，贴图按格子缩放。
- 参考图在 `art/reference/`。正式接入游戏的是 `art/character/character_Idle_Right_NoWeapon.png` 和 `art/character/weapon_Sword.png`。其余姿势还没接进角色。
