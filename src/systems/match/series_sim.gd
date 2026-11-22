## 系列賽（Bo1/Bo3/Bo5），AI 全自動版本。逐局邏輯見 SeriesState。
class_name SeriesSim
extends RefCounted


static func play(a: TeamContext, b: TeamContext, best_of: int, champions: Dictionary, patch: PatchState, rng: SimRng, detail: bool = true, stakes: float = 1.0) -> Dictionary:
	var s := SeriesState.new(a, b, best_of, champions, patch, rng, detail, stakes)
	while not s.is_done():
		var ds = s.new_draft()
		ds.run_all()
		s.play_game(ds)
	return s.result()
