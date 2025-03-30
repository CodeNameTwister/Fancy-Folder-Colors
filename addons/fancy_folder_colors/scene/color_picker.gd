@tool
@icon("res://addons/fancy_folder_colors/images/icon.svg")
extends Window
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Fancy Folder Colors
#
#	https://github.com/CodeNameTwister/Fancy-Folder-Icons
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

signal confirmed()
signal removed()
signal canceled()

var _wt : float = 0
var _selected_color : Color = Color.WHITE

func _ready() -> void:
	set_physics_process(false)
	theme = get_tree().root.theme

func _on_color_picker_color_changed(color: Color) -> void:
	_selected_color = color

func get_color() -> Color:
	return _selected_color

func reset() -> void:
	_selected_color = Color.WHITE

func _physics_process(delta: float) -> void:
	_wt -= delta
	if _wt < 0.1:
		name = &"_n"
		set_physics_process(false)
		queue_free()

func update_state() -> void:
	if !visible:
		_wt = 120
		if is_queued_for_deletion():
			return
		set_physics_process(true)
	else:
		set_physics_process(false)

func _on_accept_pressed() -> void:
	confirmed.emit()
	hide()

func _on_remove_pressed() -> void:
	removed.emit()
	hide()

func _on_cancel_pressed() -> void:
	canceled.emit()
	hide()

func _on_close_requested() -> void:
	_on_cancel_pressed()

func _on_go_back_requested() -> void:
	_on_cancel_pressed()
