class_name Os
extends Control

enum Command {
	Unknown,
	QueryDate,
	ViewMap,
	ViewLog,
	ConsoleInfo,
	GoBack,
	Home,
}

enum State {
	List,
	About,
	Login,
}

var _login_done := false
var _call_stack: Array[Callable] = []
var _list_idx := 0
var _state := State.List:
	set(val):
		_state = val
		%ListContainer.visible = _state == State.List

@onready var crt: flowerwallCRT = $flowerwall_crt
const list_el: PackedScene = preload("res://src/list_element.tscn")

func _ready() -> void:
	show_self(true)
	# display_home()
	display_login()

func show_self(should_show: bool) -> void:
	visible = should_show
	if not should_show and crt.is_enabled: 
		crt.enable_shader()
	elif should_show and not crt.is_enabled:
		crt.enable_shader()

func _process(_delta: float) -> void:
	match _state:
		State.List:
			for i in range(%ListElements.get_child_count()):
				%ListElements.get_child(i).theme_type_variation = &"InvertedLabel" if i == _list_idx else &""


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		handle_command(Command.GoBack)
	match _state:
		State.List:
			if event.is_action_pressed("up"):
				_list_idx = (_list_idx - 1 + %ListElements.get_child_count()) % %ListElements.get_child_count()
			elif event.is_action_pressed("down"):
				_list_idx = (_list_idx + 1) % %ListElements.get_child_count()
			elif event.is_action_pressed("select"):
				handle_command(%ListElements.get_child(_list_idx).command)
		State.About:
			if event.is_action_pressed("select"):
				handle_command(Command.GoBack)
		State.Login:
			if _login_done and event.is_action_pressed("select"):
				handle_command(Command.Home)


func handle_command(cmd: Command) -> void:
	match cmd:
		Command.ConsoleInfo:
			display_about()
		Command.Home:
			display_home()
		Command.GoBack:
			if _call_stack.size() > 1:
				_call_stack.pop_front()
				_call_stack[0].call()
				_call_stack.pop_front()

func display_home() -> void:
	display_list(
		"Admin Home", 
		{
			"Admin Console Info": Command.ConsoleInfo,
			"Perform Date/Time Query": Command.QueryDate,
			"Inspect Real-Time Data": Command.Unknown,
			"View Facility Map": Command.ViewMap,
			"Successful Query Log": Command.ViewLog,
		},
		["Select", "Back", "Navigate"]
	)

func display_nothing() -> void:
	%AboutContainer.visible = false
	%ListContainer.visible = false
	%LoginPortal.visible = false
	%TopTitle.visible = false
	%BottomHelp.visible = false

func display_login() -> void:
	display_nothing()
	_state = State.Login

	%LoginPortal.visible = true
	%Username.text = ""
	%Password.text = ""

	var username := " Felxi092"
	var password := " ********"
	for i in range(username.length()):
		%Username.text = username.substr(0, i + 1)
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.5).timeout
	for i in range(password.length()):
		%Password.text = password.substr(0, i + 1)
		await get_tree().create_timer(0.1).timeout

	_login_done = true

func display_about() -> void:
	display_nothing()
	_call_stack.push_front(display_about)
	_state = State.About

	%AboutContainer.visible = true
	display_title("System Information")
	display_bottom(["Done"])

func display_list(title: String, options: Dictionary[String, Command], keys: Array[String]) -> void:
	display_nothing()
	_call_stack.push_front(display_list.bind(title, options, keys))
	_state = State.List
	_list_idx = 0

	%ListContainer.visible = true
	display_title(title)
	display_bottom(keys)
	
	for c in %ListElements.get_children():
		c.queue_free()
	for o in options:
		var el := list_el.instantiate()
		%ListElements.add_child(el)
		el.text = " > " + o
		el.command = options[o]

func display_title(title: String) -> void:
	%TopTitle.visible = true
	%TopTitle.text = title

func display_bottom(keys: Array[String]) -> void:
	%BottomHelp.visible = true
	for c in %BottomHelp.get_children():
		c.visible = c.name in keys
