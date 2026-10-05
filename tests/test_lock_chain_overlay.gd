extends SceneTree

const OverlayScript := preload("res://scripts/ui/lock_chain_overlay.gd")
const BreakScript := preload("res://scripts/ui/lock_chain_break.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Control.new()
	host.size = Vector2(96, 96)
	root.add_child(host)
	var cell := {"locked_turns": 1}
	var overlay = OverlayScript.new()
	overlay.locked_cell = cell
	host.add_child(overlay)
	assert(overlay.texture != null and overlay.visible)
	assert(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(overlay.scale.x > 1.0, "新锁定播放收紧动画")
	cell["lock_vfx_started_msec"] = Time.get_ticks_msec() - 1000
	var timestamp: int = cell["lock_vfx_started_msec"]
	overlay.free()
	overlay = OverlayScript.new()
	overlay.locked_cell = cell
	host.add_child(overlay)
	assert(cell["lock_vfx_started_msec"] == timestamp, "重绘不能重置动画时间")
	assert(overlay.scale.is_equal_approx(Vector2.ONE), "重绘继续显示稳定的锁链")
	cell["locked_turns"] = 0
	overlay._process(0.0)
	assert(not overlay.visible, "解锁后立即隐藏锁链")
	var burst = BreakScript.new()
	burst.size = Vector2(96, 96)
	host.add_child(burst)
	assert(burst.get_child_count() == 4, "锁链从中心断成四段")
	assert(burst.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var fragment = burst.get_child(0)
	var initial_position: Vector2 = fragment.position
	await create_timer(0.15).timeout
	assert(fragment.position != initial_position and fragment.modulate.a < 1.0, "碎片向外移动并淡出")
	await create_timer(0.5).timeout
	assert(not is_instance_valid(burst), "动画结束后清理碎片节点")
	host.free()
	# Reproduce the actual battle parent: VBox layout used to move every
	# burst to its bottom-left, regardless of the source cell coordinates.
	var layout := VBoxContainer.new()
	layout.position = Vector2(35, 50)
	layout.size = Vector2(500, 400)
	root.add_child(layout)
	var content := Control.new()
	content.custom_minimum_size = Vector2(400, 300)
	layout.add_child(content)
	var bursts: Array = []
	var origins := [Vector2(120, 90), Vector2(370, 260)]
	for origin in origins:
		var effect = BreakScript.new()
		effect.size = Vector2(72, 72)
		layout.add_child(effect)
		effect.global_position = origin
		bursts.append(effect)
	layout.queue_sort()
	await process_frame
	await process_frame
	for index in range(bursts.size()):
		assert(bursts[index].global_position.is_equal_approx(origins[index]), "布局刷新不能改变破碎动画的棋盘位置")
		assert(bursts[index].size.is_equal_approx(Vector2(72, 72)), "布局不能重设碎片尺寸")
	layout.free()
	print("lock chain overlay tests passed")
	quit()
