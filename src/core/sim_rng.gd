## 可決定性（seeded）的隨機數產生器。
## 模擬核心中所有隨機性都必須經由 SimRng，禁止使用全域 randf()/randi()，
## 才能保證「同一個種子 + 同一份存檔 = 同一個世界」。
class_name SimRng
extends RefCounted

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func randf() -> float:
	return _rng.randf()


func range_f(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func range_i(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func chance(p: float) -> bool:
	return _rng.randf() < p


func normal(mean: float = 0.0, sd: float = 1.0) -> float:
	return _rng.randfn(mean, sd)


func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]


## 依權重抽出索引；權重 <= 0 的項目不會被選中。
func weighted_index(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(float(w), 0.0)
	if total <= 0.0:
		return -1
	var roll = _rng.randf() * total
	for i in weights.size():
		roll -= maxf(float(weights[i]), 0.0)
		if roll <= 0.0:
			return i
	return weights.size() - 1


func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## 衍生一個獨立的子串流（例如每場比賽一個），避免子系統互相影響隨機序列。
func fork(salt: int) -> SimRng:
	return SimRng.new(hash([_rng.seed, _rng.state, salt]))


## 以字串保存：64 位元整數存成 JSON 數字會失去精度（double 只有 53 位元）。
func get_state() -> Dictionary:
	return {"seed": str(_rng.seed), "state": str(_rng.state)}


func set_state(d: Dictionary) -> void:
	_rng.seed = str(d.get("seed", "0")).to_int()
	_rng.state = str(d.get("state", "0")).to_int()
