class_name Os
extends Control

enum Command {
	Unknown,
	GoToQueryScreen,
	ViewMap,
	ViewLog,
	ConsoleInfo,
	GoBack,
	Home,
	PerformQuery,
}

enum State {
	List,
	About,
	Login,
	Image,
	Query,
}

const days: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const weekdays: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const month_names: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var _login_done := false
var _call_stack: Array[Callable] = []
var _list_idx := 0

var _date_idx := 0
var _date_keys_pressed := 0
var _is_searching := false
@onready var _date_parts := [%Year, %Month, %Day, %Hour, %Minute]

var _state := State.List:
	set(val):
		_state = val
		%ListContainer.visible = _state == State.List

@onready var crt: flowerwallCRT = $flowerwall_crt
const list_el: PackedScene = preload("res://src/list_element.tscn")

func _ready() -> void:
	show_self(true)
	# display_image()
	display_home()
	# display_login()

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
		State.Query:
			for i in range(_date_parts.size()):
				_date_parts[i].theme_type_variation = &"InvertedLabel" if i == _date_idx else &""


func _trigger_right() -> void:
	var i = InputEventAction.new()
	i.action = "right"
	i.pressed = true
	Input.parse_input_event(i)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		handle_command(Command.GoBack)
	match _state:
		State.Image:
			if event.is_action_pressed("up", true):
				%ImageScroll.scroll_vertical -= 25
			elif event.is_action_pressed("down", true):
				%ImageScroll.scroll_vertical += 25
			elif event.is_action_pressed("select"):
				handle_command(Command.GoBack)
		State.List:
			if event.is_action_pressed("up"):
				_list_idx = (_list_idx - 1 + %ListElements.get_child_count()) % %ListElements.get_child_count()
			elif event.is_action_pressed("down"):
				_list_idx = (_list_idx + 1) % %ListElements.get_child_count()
			elif event.is_action_pressed("select"):
				handle_command(%ListElements.get_child(_list_idx).command)
		State.Query:
			var part = _date_parts[_date_idx]
			var n = int(part.text)
			var should_recalc := false

			if event is InputEventKey and event.pressed and event.keycode >= KEY_0 and event.keycode <= KEY_9:
				n = (n * 10 + event.keycode - 48)
				_date_keys_pressed += 1
				n %= 100
				part.text = "%02d" % n
				if _date_keys_pressed >= 2:
					should_recalc = true
					_trigger_right()

			if event.is_action_pressed("up", true):
				should_recalc = true
				n += 1
			elif event.is_action_pressed("down", true):
				should_recalc = true
				n -= 1

			
			if should_recalc:
				part.text = "%02d" % n

				%Year.text = "%02d" % clamp(int(%Year.text), 42, 43)
				%Month.text = "%02d" % clamp(int(%Month.text), 1, 12)
				%Day.text = "%02d" % clamp(int(%Day.text), 1, days[int(%Month.text) - 1])
				%Hour.text = "%02d" % clamp(int(%Hour.text), 0, 23)
				%Minute.text = "%02d" % clamp(int(%Minute.text), 0, 59)
				
				var info := Time.get_datetime_dict_from_datetime_string("%s-%s-%sT%s:%s:00" % [%Year.text, %Month.text, %Day.text, %Hour.text, %Minute.text], true)
				%DayAndMonthLabel.text = "%s, %s %02d" % [weekdays[info["weekday"]], month_names[int(%Month.text) - 1], int(%Day.text)]
				var ampm := "am" if int(%Hour.text) < 12 else "pm"
				var twelve := int(%Hour.text) % 12 if int(%Hour.text) > 12 else (int(%Hour.text) if int(%Hour.text) >= 1 else 12)
				%TimeLabel.text = "At %d:%02d%s" % [twelve, int(%Minute.text), ampm]

			elif event.is_action_pressed("right"):
				_date_idx = (_date_idx + 1) % _date_parts.size()
				_date_keys_pressed = 0
			elif event.is_action_pressed("left"):
				_date_idx = (_date_idx + _date_parts.size() - 1) % _date_parts.size()
				_date_keys_pressed = 0
			elif event.is_action_pressed("select"):
				handle_command(Command.PerformQuery)
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
		Command.ViewLog:
			display_image()
		Command.GoBack:
			if _call_stack.size() > 1:
				_call_stack.pop_front()
				_call_stack[0].call()
				_call_stack.pop_front()
		Command.PerformQuery:
			if _state == State.Query and not _is_searching:
				do_query()
		Command.GoToQueryScreen:
			display_query()


func do_query():
	_is_searching = true
	%OutcomeMsg.visible = false
	%SearchBar.visible = true
	%SearchBar/ProgressBar.indeterminate = false
	%SearchBar/ProgressBar.indeterminate = true
	await get_tree().create_timer(1.0).timeout
	%SearchBar.visible = false
	%OutcomeMsg.visible = true
	%OutcomeMsg.text = "<No Results Found.>"
	_is_searching = false

func display_home() -> void:
	display_list(
		"Admin Home", 
		{
			"Admin Console Info": Command.ConsoleInfo,
			"Perform Date/Time Query": Command.GoToQueryScreen,
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
	%QueryContainer.visible = false
	%TopTitle.visible = false
	%BottomHelp.visible = false
	%ImageContainer.visible = false

func display_image() -> void:
	display_nothing()
	_call_stack.push_front(display_image)
	_state = State.Image

	%ImageContainer.visible = true
	if get_tree().current_scene.name == "Main":
		%ImageRect.texture.viewport_path = get_tree().current_scene.get_node("HallwayCamSVP").get_path()
	
	display_bottom(["Done", "Scroll"])

func display_query() -> void:
	display_nothing()
	_call_stack.push_front(display_query)
	_state = State.Query

	%QueryContainer.visible = true
	%SearchBar.visible = false
	%OutcomeMsg.visible = false
	display_title("Camera Query")
	display_bottom(["Back", "NavigateH", "Adjust", "Search"])

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
