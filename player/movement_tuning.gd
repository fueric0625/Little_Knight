class_name MovementTuning
extends Resource

## 改这个文件里的默认值，然后重新运行场景。
## 时间单位是秒，速度单位是像素/秒。这些数字只是起点，不是原版参数。
##
## 砖块和角色图都是 128 像素。按现在的默认值粗估：
## 点按跳跃大约能上一格高的台、跨过一格宽的坑。
## 按住跳跃大约能上两格高的台、跨过两格宽的坑。
## 冲刺大约冲出三格。右边的墙有四格高，跳不上去。

@export_group("跑")
## 水平速度。按下立刻达到，松手立刻归零，空中也一样。
@export var run_speed: float = 420.0

@export_group("跳")
## 起跳瞬间的垂直速度。Godot 里向上为负。
@export var jump_velocity: float = -1220.0
## 上升过程中松开跳跃键时，剩余向上速度乘上这个系数。越小，点按跳得越矮。
@export_range(0.0, 1.0, 0.01) var jump_cut_multiplier: float = 0.72
## 恒定重力加速度。
@export var gravity: float = 2300.0
## 下落速度上限。向下为正。
@export var max_fall_speed: float = 1500.0
## 走下平台边缘后，仍可起跳的时间。主动跳离平台不会重新获得这段时间。
@export var coyote_time: float = 0.08
## 落地前按下跳跃、落地后仍会补一次跳的时间。
@export var jump_buffer_time: float = 0.08

@export_group("冲刺")
## 冲刺水平速度。冲刺期间垂直速度为 0，不受重力，也不能转向。
@export var dash_speed: float = 2100.0
## 冲刺持续时间。
@export var dash_duration: float = 0.18
## 冲刺结束后的冷却。落地刷新是否生效由下面的开关决定。
@export var dash_cooldown: float = 0.6
## 为真时，从空中落地会立刻清掉冲刺冷却。站在地上冲刺仍要等冷却。
@export var refresh_dash_on_land: bool = true

@export_group("连跳")
## 离开地面后还能再跳的次数。落地恢复。郊狼时间里的起跳算地面跳，不消耗次数。
@export var air_jumps: int = 1
## 连跳瞬间的垂直速度。Godot 里向上为负。松手截断和地面跳共用 jump_cut_multiplier。
@export var air_jump_velocity: float = -1100.0

@export_group("攻击")
## 主角重量。命中时自己被击退的速度 = 力度 / 重量。抽象单位，不是千克。
@export var player_mass: float = 2.0
## 调试预览用的敌人重量。出手时用它估算敌人会被推多快。
@export var sample_enemy_mass: float = 1.0

@export_subgroup("轻击")
## 前摇、出手、后摇。武器图片只在出手段出现。单位是秒。
@export var light_startup: float = 0.05
@export var light_active: float = 0.07
@export var light_recovery: float = 0.09
## 命中时的力度。击退速度 = 力度 / 重量。
@export var light_force: float = 500.0

@export_subgroup("重击")
@export var heavy_startup: float = 0.20
@export var heavy_active: float = 0.10
@export var heavy_recovery: float = 0.34
@export var heavy_force: float = 1400.0
## 空中重击的下砸速度。按下后水平速度立刻归零，垂直速度固定为这个值，直到落地或这次攻击结束。向下为正。
@export var heavy_air_drop_speed: float = 4800.0
