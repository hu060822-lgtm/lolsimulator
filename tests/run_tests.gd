## 執行方式：godot --headless --path . -s tests/run_tests.gd [-- --filter=名稱]
extends SceneTree


func _init() -> void:
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
	var dir = DirAccess.open("res://tests")
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()
	var total := 0
	var failed: Array = []
	var t0 = Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			failed.append("%s: 無法載入（語法錯誤）" % f)
			continue
		var inst = script.new()
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			if filter != "" and not (filter in name or filter in f):
				continue
			total += 1
			inst.current = "%s::%s" % [f, name]
			var before: int = inst.failures.size()
			var ts = Time.get_ticks_msec()
			inst.call(name)
			var ok: bool = inst.failures.size() == before
			print("%s %s (%d ms)" % ["PASS" if ok else "FAIL", inst.current, Time.get_ticks_msec() - ts])
		failed.append_array(inst.failures)
	print("")
	for msg in failed:
		print("  ✗ ", msg)
	print("%d tests, %d failures, %.1fs" % [total, failed.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failed.size() > 0 else 0)
