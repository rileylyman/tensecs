class_name Os
extends Control

#TODO
# Add search query button to query screen
# Add list of successful queries to query screen
# Add correct date to image loads
# Add viewing of mails
# Add map

enum Command {
	Unknown,
	GoToQueryScreen,
	ViewMap,
	ViewLog,
	ConsoleInfo,
	GoBack,
	Home,
	PerformQuery,
	LoadImage,
	ViewMail,
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

var _current_results_list := []

var _date_idx := 0
var _date_keys_pressed := 0
var _is_searching := false
@onready var _date_parts := [%Year, %Month, %Day, %Hour, %Minute]

class Mail:
	var subject: String
	var content: String
	var hidden: bool
	var unread: bool
	var order: int

var mails: Array[Mail] = []

var _state := State.List:
	set(val):
		_state = val
		%ListContainer.visible = _state == State.List

@onready var crt: flowerwallCRT = $flowerwall_crt
const list_el: PackedScene = preload("res://src/list_element.tscn")

func _ready() -> void:
	show_self(true)
	# display_image()
	# display_home()
	display_login()

	var all_mail: String = %Mail.mail
	var i = 0
	for s in all_mail.split("=", false):
		var idx = s.find('\n')
		var m = Mail.new()
		m.subject = s.substr(0, idx)
		m.content = s.substr(idx)
		m.unread = true
		m.hidden = true
		m.order = i
		mails.append(m)
		i += 1

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

var _showing_noti := false
func show_noti() -> void:
	if _showing_noti:
		return
	_showing_noti = true
	await create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(%MailNoti, "offset_transform_position:x", 0.0, 0.5).finished
	await get_tree().create_timer(3.0).timeout
	await create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(%MailNoti, "offset_transform_position:x", 1000.0, 0.5).finished
	_showing_noti = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		show_noti()
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
			if event.is_action_pressed("up") and %ListElements.get_child_count() > 0:
				_list_idx = (_list_idx - 1 + %ListElements.get_child_count()) % %ListElements.get_child_count()
			elif event.is_action_pressed("down") and %ListElements.get_child_count() > 0:
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

				%Year.text = "%02d" % clamp(int(%Year.text), 0, 99)
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
			if _state == State.Image:
				process_image_notis()
			if _call_stack.size() > 1:
				_call_stack.pop_front()
				_call_stack[0].call()
				_call_stack.pop_front()
		Command.PerformQuery:
			if _state == State.Query and not _is_searching:
				do_query()
		Command.GoToQueryScreen:
			display_query()
		Command.LoadImage:
			display_image()
		Command.ViewMail:
			display_mail_list()


func do_query():
	_is_searching = true
	%OutcomeMsg.visible = false
	%SearchBar.visible = true
	%SearchBar/ProgressBar.indeterminate = false
	%SearchBar/ProgressBar.indeterminate = true

	var query_string := "16%s-%s-%sT%s:%s" % [%Year.text, %Month.text, %Day.text, %Hour.text, %Minute.text]

	var main := get_tree().current_scene
	var results := []
	if main.name == "Main":
		var cam_scenes := main.get_children().filter(func(c): return c is CamScene)
		for c in cam_scenes:
			c.visible = false
		results = cam_scenes.filter(func(c): return c.time == query_string)
		for r in results:
			r.visible = true

	await get_tree().create_timer(1.0).timeout
	%SearchBar.visible = false
	%OutcomeMsg.visible = true

	if results.is_empty():
		%OutcomeMsg.text = "<No Results Found.>"
	else:
		%OutcomeMsg.text = "<Found %d result%s. Loading...>" % [results.size(), "s" if results.size() > 1 else ""]
		await get_tree().create_timer(1.0).timeout
		display_search_results(results)
	_is_searching = false

func display_mail_list() -> void:
	_call_stack.push_front(display_mail_list)

	var to_show := mails.filter(func(m): return not m.hidden)
	to_show.sort_custom(func(a, b):
		if a.unread and not b.unread:
			return true
		else:
			return a.i > b.i
	)

	var dict: Dictionary[String, Command] = {}
	for i in range(to_show.size()):
		dict[to_show[i].subject + " [unread]" if to_show[i].unread else ""] = Command.GoBack
	display_list(
		"Mail",
		dict,
		["Select", "Back", "Navigate"]
	)
	_list_idx = 0

func display_search_results(results: Array) -> void:
	_call_stack.push_front(display_search_results.bind(results))

	_current_results_list = results
	var dict: Dictionary[String, Command] = {}
	for r in results:
		dict[r.svp.location] = Command.LoadImage
	display_list(
		"%s %s" % [%DayAndMonthLabel.text, %TimeLabel.text], 
		dict,
		["Select", "Back", "Navigate"]
	)
	_list_idx = 0

func display_home() -> void:
	_call_stack.push_front(display_home)
	display_list(
		"Admin Home", 
		{
			"General Info": Command.ConsoleInfo,
			"Query": Command.GoToQueryScreen,
			"Facility Map": Command.ViewMap,
			("Mail" + (" [unread]" if mails.filter(func(m): return not m.hidden and m.unread).size() > 0 else "")): Command.ViewMail,
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

func process_image_notis() -> void:
	var r: CamScene = _current_results_list[_list_idx - 1]
	var idx := mails.find_custom(func(m): return m.subject == r.trigger_mail)
	if idx >= 0 and mails[idx].hidden:
		mails[idx].hidden = false
		show_noti()

func display_image() -> void:
	display_nothing()
	_call_stack.push_front(display_image)
	_state = State.Image

	%ImageContainer.visible = true
	if get_tree().current_scene.name == "Main":
		var r: CamScene = _current_results_list[_list_idx - 1]
		%ImageRect.texture.viewport_path = r.svp.get_path()
		%ImageDesc.text = ""
		%ImageDesc.append_text("\n-- Automatic Audio Transcription --\n\n" + r.transcript.replace("{", "[font_size=20][b]").replace("}", "[/b][/font_size]") + "\n\n-- End of Transcript --\n")
	
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

var _has_done_login := false
func display_login() -> void:
	display_nothing()
	_call_stack.push_front(display_login)
	_state = State.Login

	%LoginPortal.visible = true
	%Username.text = ""
	%Password.text = ""

	var username := " Felxi092"
	var password := " ********"
	if not _has_done_login:
		_has_done_login = true
		for i in range(username.length()):
			%Username.text = username.substr(0, i + 1)
			await get_tree().create_timer(0.1).timeout
		await get_tree().create_timer(0.5).timeout
		for i in range(password.length()):
			%Password.text = password.substr(0, i + 1)
			await get_tree().create_timer(0.1).timeout
	else:
		%Username.text = username
		%Password.text = password

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
	_state = State.List

	%ListContainer.visible = true
	display_title(title)
	display_bottom(keys)

	%EmptyLabel.visible = options.size() == 0
	
	for c in %ListElements.get_children():
		c.queue_free()

	var el := list_el.instantiate()
	%ListElements.add_child(el)
	el.text = " > .."
	el.command = Command.GoBack
	for o in options:
		el = list_el.instantiate()
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
