## 小型數學工具。
class_name MathX
extends RefCounted


static func sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))


static func norm100(v: float) -> float:
	return clampf(v / 100.0, 0.0, 1.0)


static func mean(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := 0.0
	for v in arr:
		s += float(v)
	return s / arr.size()


static func lerp_clamped(a: float, b: float, t: float) -> float:
	return lerpf(a, b, clampf(t, 0.0, 1.0))
