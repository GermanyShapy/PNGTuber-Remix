extends Node

var undo_redo_data : Array = []
var undo_redo_id : int = 0

func _input(event: InputEvent) -> void:
	if Global.mode == 0:
		if event.is_action_pressed("ui_undo"):
			undo_info()
		if event.is_action_pressed("ui_redo"):
			redo_info()

func undo_info():
	undo_redo_id = max(0, undo_redo_id - 1)
	#printt("undo id : ", undo_redo_id)
	if undo_redo_data.size() > 0:
		match_data_type(undo_redo_data[max(undo_redo_id - 1, 0)], "undo")

func redo_info():
	undo_redo_id = min(undo_redo_data.size(), undo_redo_id+1)
	#printt("redo id : ", undo_redo_id)
	if undo_redo_data.size() > 0:
		match_data_type(undo_redo_data[max(undo_redo_id - 1, 0)], "redo")

func add_data_to_manager(data : Array):
	if undo_redo_id != undo_redo_data.size():
		undo_redo_data.resize(undo_redo_id)
	undo_redo_data.append(data)
	undo_redo_id = undo_redo_data.size()
	#printt("undo redo data : ", undo_redo_data.size())

func match_data_type(data, un_re):
	if data is Array:
		for i in data:
			match_object_data_type(i, un_re)
		
	elif data is Dictionary:
		pass

func match_object_data_type(object, un_re):
	match object.data_type:
		"sprite_data":
			if un_re == "undo":
				update_sprite_data(object.sprite_object, object.og_data, object.state)
			if un_re == "redo":
				update_sprite_data(object.sprite_object, object.data, object.state)

func update_sprite_data(object ,sprite_data, state):
	object.states[state] = sprite_data.duplicate()
	
	if Global.current_state == state:
		object.get_state(Global.current_state)
		Global.reinfo.emit()


'''
undo_redo_data.append({sprite_object = i, 
data = i.sprite_data, 
og_data = og_val,
data_type = "sprite_data", 
state = Global.current_state})'''
