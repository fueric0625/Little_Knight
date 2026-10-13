class_name HitKnockback
extends RefCounted

## 命中时的击退速度。力度来自攻击，重量是抽象单位。
## 敌人沿攻击朝向被推；主角用同一公式，方向相反。
## 挥空不调用这里，所以不会推动角色。


static func speed(force: float, mass: float) -> float:
	return force / maxf(mass, 0.001)
