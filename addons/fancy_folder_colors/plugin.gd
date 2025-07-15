@tool
extends EditorPlugin
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
 #	Fancy Folder Colors
 #
 #	https://github.com/CodeNameTwister/Fancy-Folder-Icons
 #	author:	"Twister"
 # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
var DOT_USER : String = "res://addons/fancy_folder_colors/user/fancy_folder_colors.dat"
var _buffer : Dictionary = {}
var _tree : Tree = null
var _busy : bool = false

var _menu_service : EditorContextMenuPlugin = null
var _popup : Window = null

var _tchild : TreeItem = null

var _ref_buffer : Dictionary[Variant, TreeItem] = {}
	
func _setup(load_buffer : bool = true) -> void:
	var dir : String = DOT_USER.get_base_dir()
	if !DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		return
	if DOT_USER == "res://addons/fancy_folder_colors/user/fancy_folder_colors.dat":
		#(?) Do not ignore a possible important folder.
		if !FileAccess.file_exists(dir.path_join(".gdignore")):
			var file : FileAccess = FileAccess.open(dir.path_join(".gdignore"), FileAccess.WRITE)
			file.store_string("Fancy Folder Icons Saved Folder")
			file.close()	
		
	if !load_buffer:
		return
		
	if !FileAccess.file_exists(DOT_USER):
		if FileAccess.file_exists("user://editor/fancy_folder_colors.dat"):
			var cfg : ConfigFile = ConfigFile.new()
			if OK != cfg.load("user://editor/fancy_folder_colors.dat"):return
			_buffer = cfg.get_value("DAT", "PTH", {})
			if _buffer.size() > 0 and _quick_save() == OK:
					print("[Fancy Folder Icons] Loaded from old version, now is secure manual delete: ", ProjectSettings.globalize_path("user://editor/fancy_folder_colors.dat"))
	else:
		var cfg : ConfigFile = ConfigFile.new()
		if OK != cfg.load(DOT_USER):return
		_buffer = cfg.get_value("DAT", "PTH", {})

func _quick_save() -> int:
	var cfg : ConfigFile = ConfigFile.new()
	var result : int = -1
	if FileAccess.file_exists(DOT_USER):
		cfg.load(DOT_USER)
	cfg.set_value("DAT", "PTH", _buffer)
	result = cfg.save(DOT_USER)
	cfg = null
	set_deferred(&"_is_saving" , false)
	return result

#region callbacks
func _moved_callback(_a : String, _b : String ) -> void:
	if _a != _b:
		if _buffer.has(_a):
			_buffer[_b] = _buffer[_a]
			_buffer.erase(_a)

func _remove_callback(path : String) -> void:
	if _buffer.has(path):
		_buffer.erase(path)
#endregion

func _def_update() -> void:
	update.call_deferred()

func _update_draw(x : Variant) -> void:
	for __ : int in range(2):
		var tree : SceneTree = get_tree()
		if !is_instance_valid(tree):
			return
		await tree.process_frame
			
		if is_instance_valid(x):
			if x is Tree:
				var _root: TreeItem = x.get_root()
				if _root != null:
					var child : TreeItem = _root.get_first_child()
					if child == null:
						return
					if _ref_buffer.has(x) and _ref_buffer[x] == child:
						return
					_ref_buffer[x] = child
					var value : Variant = _root.get_metadata(0)
					if value == null:
						if child:
							value = child.get_metadata(0)
							if value is String and (value == "Favorites" or DirAccess.dir_exists_absolute(value) or FileAccess.file_exists(value)):
								_explore(_root)
								return
					elif value is String:
						if FileAccess.file_exists(value):
							_explore(_root)
					elif value is RefCounted:
						if value.get(&"_saved_path") is String:
							_tabby_explore(_root)
			elif x is ItemList:
				if x.item_count > 0:
					var tlp : String = x.get_item_tooltip(0)
					if !tlp.ends_with("`"):
						x.set_item_tooltip(0, tlp + "`")
						var m : Variant = x.get_item_metadata(0)
						if m is String and (DirAccess.dir_exists_absolute(m) or FileAccess.file_exists(m)):
							for y : int in x.item_count:
								var path : Variant = x.get_item_metadata(y)
								if path is String:
									if _buffer.has(path):
										x.set_item_icon_modulate(y, _buffer[path])
									elif path.get_extension().is_empty():
										var tmp : String = path.path_join("")
										if _buffer.has(tmp):
											x.set_item_icon_modulate(y, _buffer[tmp])
										else:
											path = path.substr(0, path.rfind("/", path.length()-2)).path_join("")
											if _buffer.has(path):
												x.set_item_icon_modulate(y, _buffer[path])
						elif m is Dictionary and m.has("path"):
							for y : int in x.item_count:
								var data : Variant = x.get_item_metadata(y)
								if data is Dictionary and data.has("path"):
									var path : Variant = data["path"]
									if path is String:
										if _buffer.has(path):
											x.set_item_icon_modulate(y, _buffer[path])
										elif path.get_extension().is_empty():
											var tmp : String = path.path_join("")
											if _buffer.has(tmp):
												x.set_item_icon_modulate(y, _buffer[tmp])
											else:
												path = path.substr(0, path.rfind("/", path.length()-2)).path_join("")
												if _buffer.has(path):
													x.set_item_icon_modulate(y, _buffer[path])
						else:
							if x is Control:
								if x.draw.is_connected(_update_draw):
									x.draw.disconnect(_update_draw)

func _is_tabby(tree : Tree, root : TreeItem) -> bool:
	var meta : Variant = root.get_metadata(0)
	if meta is RefCounted:
		if meta.get(&"_saved_path") is String:
			if !tree.draw.is_connected(_update_draw):
				tree.draw.connect(_update_draw.bind(tree))
			return true
	return false

func _tabby_explore(item : TreeItem, color : Color = Color.WHITE, alpha : float = 1.0) -> void:
	var meta : Variant = item.get_metadata(0)
	if meta is RefCounted:
		meta = meta.get(&"_saved_path")
		if meta is String:
			if _buffer.has(meta):
				color = _buffer[meta]
				alpha = 0.15

			if alpha != 1.0:
				var bg_color : Color = color
				bg_color.a = alpha
				item.set_custom_bg_color(0, bg_color)
				if alpha == 0.15 or !FileAccess.file_exists(meta):
					item.set_icon_modulate(0, color)
				alpha = 0.1

			for i : TreeItem in item.get_children():
				_tabby_explore(i, color, alpha)

func update() -> void:
	if _busy or _buffer.size() == 0 or _tree == null:
		return
	_busy = true
	for x : Variant in _ref_buffer.keys():
		if !is_instance_valid(x):
			_ref_buffer.erase(x)
			continue
		if x is Tree:
			var _root: TreeItem = x.get_root()
			if _root != null:
				var child : TreeItem = _root.get_first_child()
				if child == null:
					continue
				var value : Variant = _root.get_metadata(0)
				if value == null:
					if child:
						value = child.get_metadata(0)
						if value is String and (value == "Favorites" or DirAccess.dir_exists_absolute(value) or FileAccess.file_exists(value)):
							if !x.draw.is_connected(_update_draw):
								x.draw.connect(_update_draw.bind(x))
							_update_draw(x)
							continue
				elif value is String:
					if FileAccess.file_exists(value):
						if !x.draw.is_connected(_update_draw):
							x.draw.connect(_update_draw.bind(x))
						_update_draw(x)
						continue
				elif value is RefCounted:
					if value.get(&"_saved_path") is String:
						if !x.draw.is_connected(_update_draw):
							x.draw.connect(_update_draw.bind(x))
						_update_draw(x)
						continue
		elif x is ItemList:
			if !x.draw.is_connected(_update_draw):
				x.draw.connect(_update_draw.bind(x))
			if x.item_count > 0:
				var m : Variant = x.get_item_metadata(0)
				if m is String and (DirAccess.dir_exists_absolute(m) or FileAccess.file_exists(m)):
					if !x.draw.is_connected(_update_draw):
						x.draw.connect(_update_draw.bind(x))
					_update_draw(x)
				elif m is Dictionary and m.has("path"):
					if !x.draw.is_connected(_update_draw):
						x.draw.connect(_update_draw.bind(x))
					_update_draw(x)
				else:
					if !x.draw.is_connected(_update_draw):
						x.draw.connect(_update_draw.bind(x))
			continue
		
	set_deferred(&"_busy", false)

func _explore(item : TreeItem, color : Color = Color.WHITE, alpha : float = 1.0) -> void:
	var meta : String = str(item.get_metadata(0))
	if _buffer.has(meta):
		color = _buffer[meta]
		alpha = 0.15

	if alpha != 1.0:
		var bg_color : Color = color
		bg_color.a = alpha
		item.set_custom_bg_color(0, bg_color)
		if alpha == 0.15 or !FileAccess.file_exists(meta):
			item.set_icon_modulate(0, color)
		alpha = 0.1

	for i : TreeItem in item.get_children():
		_explore(i, color, alpha)

func _on_visibility_changed() -> void:
	_popup.update_state()


func _on_changes() -> void:
	var editor : EditorSettings = EditorInterface.get_editor_settings()
	if editor:
		var packed : PackedStringArray = editor.get_changed_settings()
		if "plugin/fancy_folder_colors/save_location" in packed:
			var new_path : String = editor.get_setting("plugin/fancy_folder_colors/save_location")		
			if new_path.is_empty():
				editor.set_setting("plugin/fancy_folder_colors/save_location", DOT_USER)
			else:
				DOT_USER = new_path
			_setup(false)

func _init() -> void:
	var editor : EditorSettings = EditorInterface.get_editor_settings()
	if editor:
		if !editor.has_setting("plugin/fancy_folder_colors/save_location"):
			editor.set_setting("plugin/fancy_folder_colors/save_location", DOT_USER)
		else:
			var new_path : String = editor.get_setting("plugin/fancy_folder_colors/save_location")		
			if new_path.is_empty():
				editor.set_setting("plugin/fancy_folder_colors/save_location", DOT_USER)
			else:
				DOT_USER = new_path
		editor.settings_changed.connect(_on_changes)

func _on_confirmed(paths : PackedStringArray) -> void:
	if is_instance_valid(_popup):
		var color : Color = _popup.get_color()
		for p : String in paths:
			_buffer[p] = color
		for x : Variant in _ref_buffer.keys():
			if !is_instance_valid(x):
				_ref_buffer.erase(x)
				continue
			_ref_buffer[x] = null
		_quick_save()
		_def_update.call_deferred()

func _on_removed(paths : PackedStringArray) -> void:
	if is_instance_valid(_popup):
		for p : String in paths:
			if _buffer.has(p):
				_buffer.erase(p)
		var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
		fs.filesystem_changed.emit()

func _on_canceled() -> void:
	if is_instance_valid(_popup):
		if _popup.confirmed.is_connected(_on_confirmed):
			_popup.confirmed.disconnect(_on_confirmed)
		if _popup.removed.is_connected(_on_removed):
			_popup.removed.disconnect(_on_removed)

func _on_colorize_paths(paths : PackedStringArray) -> void:
	#SHOW MENU
	_popup = get_tree().root.get_node_or_null("_POP_FANCY_COLORS_")
	if !is_instance_valid(_popup) or _popup.is_queued_for_deletion():
		_popup = (ResourceLoader.load("res://addons/fancy_folder_colors/scene/color_picker.tscn") as PackedScene).instantiate()
		_popup.name = &"_POP_FANCY_COLORS_"
		_popup.visibility_changed.connect(_on_visibility_changed)
		_popup.canceled.connect(_on_canceled)
		get_tree().root.add_child(_popup)

	if _popup.confirmed.is_connected(_on_confirmed):
		_popup.confirmed.disconnect(_on_confirmed)
	if _popup.removed.is_connected(_on_removed):
		_popup.removed.disconnect(_on_removed)
	_popup.confirmed.connect(_on_confirmed.bind(paths), CONNECT_ONE_SHOT)
	_popup.removed.connect(_on_removed.bind(paths), CONNECT_ONE_SHOT)
	_popup.popup_centered()

func _get_dummy_tree_node() -> void:
	set_physics_process(false)
	var root : TreeItem = _tree.get_root()
	if root:
		_tchild = root.get_first_child()
	if is_instance_valid(_tchild):
		set_physics_process(true)

func _ready() -> void:
	set_physics_process(false)
	var dock : FileSystemDock = EditorInterface.get_file_system_dock()
	var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	_n(dock)

	_get_dummy_tree_node()

	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _menu_service)

	dock.files_moved.connect(_moved_callback)
	dock.folder_moved.connect(_moved_callback)
	dock.folder_removed.connect(_remove_callback)
	dock.file_removed.connect(_remove_callback)
	dock.folder_color_changed.connect(_def_update)
	fs.filesystem_changed.connect(_def_update)

	_def_update()
	
func _on_child(n : Node) -> void:
	if n is Tree:
		if !_ref_buffer.has(n):
			_ref_buffer[n] = null
			_def_update()
	if n is ItemList:
		if !_ref_buffer.has(n):
			_ref_buffer[n] = null
			_def_update()
	for x : Node in n.get_children():
		_on_child(x)

func _enter_tree() -> void:
	_setup()
	
	var root : Node = get_tree().root
	get_tree().node_added.connect(_on_child)
	_on_child(root)

	_menu_service = ResourceLoader.load("res://addons/fancy_folder_colors/menu_fancy.gd").new()
	_menu_service.colorize_paths.connect(_on_colorize_paths)

func _exit_tree() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()

	if is_instance_valid(_menu_service):
		remove_context_menu_plugin(_menu_service)
		
	if get_tree().node_added.is_connected(_on_child):
		get_tree().node_added.disconnect(_on_child)
		
	var dock : FileSystemDock = EditorInterface.get_file_system_dock()
	var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	if dock.files_moved.is_connected(_moved_callback):
		dock.files_moved.disconnect(_moved_callback)
	if dock.folder_moved.is_connected(_moved_callback):
		dock.folder_moved.disconnect(_moved_callback)
	if dock.folder_removed.is_connected(_remove_callback):
		dock.folder_removed.disconnect(_remove_callback)
	if dock.file_removed.is_connected(_remove_callback):
		dock.file_removed.disconnect(_remove_callback)
	if dock.folder_color_changed.is_connected(_def_update):
		dock.folder_color_changed.disconnect(_def_update)
	if fs.filesystem_changed.is_connected(_def_update):
		fs.filesystem_changed.disconnect(_def_update)

	#region user_dat
	var cfg : ConfigFile = ConfigFile.new()
	for k : String in _buffer.keys():
		if !DirAccess.dir_exists_absolute(k) and !FileAccess.file_exists(k):
			_buffer.erase(k)
			continue
	cfg.set_value("DAT", "PTH", _buffer)
	if OK != cfg.save(DOT_USER):
		push_warning("Error on save HideFolders!")
	#endregion

	_menu_service = null
	_buffer.clear()

	if !fs.is_queued_for_deletion():
		fs.filesystem_changed.emit()

#region rescue_fav
func _n(n : Node) -> bool:
	if n is Tree:
		var t : TreeItem = (n.get_root())
		if null != t:
			t = t.get_first_child()
			while t != null:
				if t.get_metadata(0) == "res://":
					_tree = n
					return true
				t = t.get_next()
	for x in n.get_children():
		if _n(x): return true
	return false
#endregion
