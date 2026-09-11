class_name Os
extends Control

# Not doing:
# AM/PM mode instead of 24 hr
# Add click mode
# add computer startup sound

enum Command {
	Unknown,
	GoToQueryScreen,
	ViewMap,
	ViewLog,
	ConsoleInfo,
	GoBack,
	Home,
	PerformQuery,
	PerformRequery,
	LoadImage,
	ViewMail,
	ViewMailList,
	ViewNameInput,
}

enum State {
	List,
	About,
	Login,
	Image,
	ImageBig,
	Query,
	Mail,
	NameInput,
	Map,
}

const days: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const weekdays: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const month_names: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

const true_name := "GRAYSON"

var _is_going_back := false
var _skip_intro := false

var _login_done := false
var _call_stack: Array[Callable] = []
var _list_idx := 0
var _list_idx_stack: Array[int] = []

var _current_results_list := []

var _current_list_names := []

var _date_idx := 0
var _date_keys_pressed := 0
var _is_searching := false
@onready var _date_parts := [%Year, %Month, %Day, %Hour, %Minute]

var _curr_name_guess := ""
var _name_succeeded := false

var _successful_queries: Array[String] = []

@onready var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split()

class Mail:
	var subject: String
	var content: String
	var hidden: bool
	var unread: bool
	var order: int

var mails: Array[Mail] = []
var _current_shown_mails: Array[Mail] = []

var _has_played_music := false

var _state := State.List:
	set(val):
		var prev = _state
		if prev == State.List and not _is_going_back:
			_list_idx_stack.push_front(_list_idx)

		if val == State.List and _is_going_back:
			var idx: int = _list_idx_stack.pop_front()
			_list_idx = idx if idx != null else 0
		elif val == State.List:
			_list_idx = 0

		if prev == State.Mail and not _has_played_music:
			_has_played_music = true
			# handle_music()

		_state = val
		%ListContainer.visible = _state == State.List


@onready var crt: flowerwallCRT = $flowerwall_crt
const list_el: PackedScene = preload("res://src/list_element.tscn")

func handle_music() -> void:
	var _orig_ambience_vol: float = $Ambience.volume_db
	await create_tween().tween_property($Ambience, "volume_db", _orig_ambience_vol * 4, 3.0).finished
	$Music.play()
	await $Music.finished
	await create_tween().tween_property($Ambience, "volume_db", _orig_ambience_vol, 3.0).finished

func _ready() -> void:
	crt.enable_shader()
	# display_image()
	# display_home()
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
	if _skip_intro:
		should_show = true
	visible = should_show
	if not should_show and crt.is_enabled:
		crt.enable_shader()
	elif should_show and not crt.is_enabled:
		crt.enable_shader()
		if _skip_intro:
			display_home()
		else:
			display_login(false)
			await get_tree().create_timer(1.0).timeout
			display_login(true)

func _process(_delta: float) -> void:
	match _state:
		State.List:
			for i in range(%ListElements.get_child_count()):
				%ListElements.get_child(i).theme_type_variation = &"InvertedLabel" if i == _list_idx else &""
		State.Query:
			for i in range(_date_parts.size()):
				_date_parts[i].theme_type_variation = &"InvertedLabel" if i == _date_idx else &""
		State.NameInput:
			%NameInputLabel.text = _curr_name_guess + (" " if _name_succeeded or floori((Time.get_ticks_msec() / 500.0)) % 2 == 0 else "_")


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
	$Noti.play()
	await get_tree().create_timer(3.0).timeout
	await create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(%MailNoti, "offset_transform_position:x", 1000.0, 0.5).finished
	_showing_noti = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_game"):
		get_tree().reload_current_scene()
	for a in ["select", "back", "up", "down", "right", "left"]:
		if event.is_action_pressed(a):
			$Audio.play()
	if _state != State.NameInput and _state != State.ImageBig and event.is_action_pressed("back"):
		handle_command(Command.GoBack)
	match _state:
		State.NameInput:
			if not _name_succeeded:
				if event is InputEventKey and event.pressed:
					$Audio.play()
					var k: String = event.as_text_keycode()
					if k in alphabet:
						_curr_name_guess += k
					elif event.keycode == KEY_BACKSPACE:
						_curr_name_guess = _curr_name_guess.substr(0, max(0, _curr_name_guess.length() - 1))
					elif event.keycode == KEY_ENTER:
						if _curr_name_guess == true_name:
							_name_succeeded = true
							%NameResultLabel.text = "<Success>"
							push_mail_noti("A Job Well Done")
						else:
							%NameResultLabel.text = "<Failure>"
					elif event.keycode == KEY_ESCAPE:
						handle_command(Command.GoBack)
			else:
				if event.is_action_pressed("select") or event.is_action_pressed("back"):
					handle_command(Command.GoBack)
		State.Image:
			if event.is_action_pressed("up", true):
				%ImageScroll.scroll_vertical -= 25
			elif event.is_action_pressed("down", true):
				%ImageScroll.scroll_vertical += 25
			elif event.is_action_pressed("select"):
				handle_command(Command.GoBack)
			elif event.is_action_pressed("enlarge_image"):
				var cont := %ImageRect.get_parent()
				cont.offset_transform_enabled = true
				_state = State.ImageBig
		State.ImageBig:
			if event.is_action_pressed("select") or event.is_action_pressed("back") or event.is_action_pressed("enlarge_image"):
				var cont := %ImageRect.get_parent()
				cont.offset_transform_enabled = false
				_state = State.Image
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
				$Audio.play()
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

				var year := int(%Year.text)
				var month := int(%Month.text)
				var day = int(%Day.text)
				var hour = int(%Hour.text)
				var minute = int(%Minute.text)

				if year == -1:
					year = 99
				if year == 100:
					year = 0
				if month == 13:
					month = 1
				if month == 0:
					month = 12
				if day == days[clamp(month, 1, 12) - 1] + 1:
					day = 1
				if day == 0:
					day = days[clamp(month, 1, 12) - 1]
				if hour == 24:
					hour = 0
				if hour == -1:
					hour = 23
				if minute == 60:
					minute = 0
				if minute == -1:
					minute = 59
				

				%Year.text = "%02d" % clamp(year, 0, 99)
				%Month.text = "%02d" % clamp(month, 1, 12)
				%Day.text = "%02d" % clamp(day, 1, days[clamp(month, 1, 12) - 1])
				%Hour.text = "%02d" % clamp(hour, 0, 23)
				%Minute.text = "%02d" % clamp(minute, 0, 59)
				
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
			if event.is_action_pressed("up", true):
				%AboutScroll.scroll_vertical -= 25
			elif event.is_action_pressed("down", true):
				%AboutScroll.scroll_vertical += 25
		State.Map:
			if event.is_action_pressed("select"):
				handle_command(Command.GoBack)
		State.Mail:
			if event.is_action_pressed("up", true):
				%MailScroll.scroll_vertical -= 25
			elif event.is_action_pressed("down", true):
				%MailScroll.scroll_vertical += 25
			elif event.is_action_pressed("select"):
				handle_command(Command.GoBack)
		State.Login:
			if _login_done and event.is_action_pressed("select"):
				handle_command(Command.Home)
				$Success.play()


func handle_command(cmd: Command) -> void:
	match cmd:
		Command.ConsoleInfo:
			display_about()
		Command.Home:
			display_home()
		Command.ViewLog:
			display_log()
		Command.ViewMail:
			display_mail()
		Command.ViewMap:
			display_map()
		Command.ViewNameInput:
			display_name_input()
		Command.GoBack:
			if _state == State.Image:
				process_image_notis()
			if _call_stack.size() > 1:
				_is_going_back = true
				_call_stack.pop_front()
				_call_stack[0].call()
				_call_stack.pop_front()
				_is_going_back = false
		Command.PerformQuery:
			if _state == State.Query and not _is_searching:
				do_query()
		Command.PerformRequery:
			do_requery()
		Command.GoToQueryScreen:
			display_query()
		Command.LoadImage:
			display_image()
		Command.ViewMailList:
			display_mail_list()

func find_results(query_string: String) -> Array:
	var main := get_tree().current_scene
	var results := []
	if main.name == "Main":
		var cam_scenes := main.get_children().filter(func(c): return c is CamScene)
		for c in cam_scenes:
			c.visible = false
		results = cam_scenes.filter(func(c): return c.time == query_string)
		for r in results:
			r.visible = true
	return results

func do_requery() -> void:
	var results = find_results(_successful_queries[_list_idx - 1])
	display_query_results(results)

func do_query():
	_is_searching = true
	%OutcomeMsg.visible = false
	%SearchBar.visible = true
	%SearchBar/ProgressBar.indeterminate = false
	%SearchBar/ProgressBar.indeterminate = true

	var query_string := "16%s-%s-%sT%s:%s" % [%Year.text, %Month.text, %Day.text, %Hour.text, %Minute.text]
	var results = find_results(query_string)

	await get_tree().create_timer(1.0).timeout
	%SearchBar.visible = false
	%OutcomeMsg.visible = true

	if results.is_empty():
		%OutcomeMsg.text = "<No Results Found.>"
		$Error.play()
	else:
		$Success.play()
		if not query_string in _successful_queries:
			_successful_queries.append(query_string)
			_successful_queries.sort()
		%OutcomeMsg.text = "<Found %d result%s. Loading...>" % [results.size(), "s" if results.size() > 1 else ""]
		await get_tree().create_timer(1.0).timeout
		_call_stack.pop_front()
		display_query_results(results)
	_is_searching = false

func display_log() -> void:
	_call_stack.push_front(display_log)

	var dict: Dictionary[String, Command] = {}
	for q in _successful_queries:
		var res := find_results(q)
		var alias := ""
		for r in res:
			if not r.alias.is_empty():
				alias = r.alias
				break
		dict[" At ".join(pretty_date(q)) + ("" if not alias else " - " + alias)] = Command.PerformRequery

	display_list(
		"Query Log",
		dict,
		["Select", "Back", "Navigate"]
	)

func display_mail() -> void:
	display_nothing()
	_call_stack.push_front(display_image)
	_state = State.Mail

	%MailContainer.visible = true
	%MailScroll.scroll_vertical = 0
	var m = _current_shown_mails[_list_idx - 1]
	m.unread = false
	%MailLabel.text = "[b][u]" + m.subject + "[/u][/b]" + m.content + "\n-- End of Transmission --"

	display_bottom(["Done", "Scroll"])


func display_mail_list() -> void:
	_call_stack.push_front(display_mail_list)

	_current_shown_mails = mails.filter(func(m): return not m.hidden)
	_current_shown_mails.sort_custom(func(a, b):
		if a.unread and not b.unread:
			return true
		else:
			return a.order > b.order
	)

	var dict: Dictionary[String, Command] = {}
	for i in range(_current_shown_mails.size()):
		dict[_current_shown_mails[i].subject + (" [unread]" if _current_shown_mails[i].unread else "")] = Command.ViewMail
	display_list(
		"Mail",
		dict,
		["Select", "Back", "Navigate"]
	)

func display_query_results(results: Array) -> void:
	_call_stack.push_front(display_query_results.bind(results))

	_current_results_list = results
	var dict: Dictionary[String, Command] = {}
	for r in results:
		dict[r.svp.location] = Command.LoadImage
	display_list(
		"Query Results;%s" % ("" if results.size() == 0 else " At ".join(pretty_date(results[0].time))),
		dict,
		["Select", "Back", "Navigate"]
	)

func display_home() -> void:
	_call_stack.push_front(display_home)
	var dict: Dictionary[String, Command] = {}
	dict["General Info"] = Command.ConsoleInfo
	dict["Facility Map"] = Command.ViewMap
	dict["Query"] = Command.GoToQueryScreen
	#if mails.filter(func(m): return not m.hidden).size() > 0:
	dict[("Mail" + (" [unread]" if mails.filter(func(m): return not m.hidden and m.unread).size() > 0 else ""))] = Command.ViewMailList
	#if _successful_queries.size() > 0:
	dict["Past Queries"] = Command.ViewLog
	if _current_shown_mails.size() > 0:
		dict["Input Name"] = Command.ViewNameInput

	display_list(
		"Admin Home",
		dict,
		["Select", "Back", "Navigate"],
		false
	)

func display_nothing() -> void:
	%AboutContainer.visible = false
	%ListContainer.visible = false
	%LoginPortal.visible = false
	%QueryContainer.visible = false
	%TopTitle.visible = false
	%TopTitleWithSub.visible = false
	%BottomHelp.visible = false
	%ImageContainer.visible = false
	%MailContainer.visible = false
	%NameInputContainer.visible = false
	%MapContainer.visible = false

func push_mail_noti(subject_line: String) -> void:
	var idx := mails.find_custom(func(m): return m.subject == subject_line)
	if idx >= 0 and mails[idx].hidden:
		mails[idx].hidden = false
		show_noti()

func process_image_notis() -> void:
	var r: CamScene = _current_results_list[_list_idx - 1]
	push_mail_noti(r.trigger_mail)

func pretty_date(date_string: String) -> Array[String]:
	date_string += ":00"
	var date_split = date_string.split("T")[0]
	var time_split = date_string.split("T")[1]
	var month = date_split.split("-")[1]
	var day = date_split.split("-")[2]
	var hour = time_split.split(":")[0]
	var minute = time_split.split(":")[1]

	var info := Time.get_datetime_dict_from_datetime_string(date_string, true)

	var date_part := "%s, %s %02d" % [weekdays[info["weekday"]], month_names[int(month) - 1], int(day)]
	var ampm := "am" if int(hour) < 12 else "pm"
	var twelve := int(hour) % 12 if int(hour) > 12 else (int(hour) if int(hour) >= 1 else 12)
	var time_part := "%d:%02d%s" % [twelve, int(minute), ampm]
	return [date_part, time_part]

@onready var _img_header_orig: String = %ImageHeader.text
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
		var d := pretty_date(r.time)
		%ImageHeader.text = _img_header_orig.format({"title_string": r.svp.location, "date_string": d[0] + " At " + d[1]})
		%ImageScroll.scroll_vertical = 0
	
	display_bottom(["Done", "Enlarge", "Scroll"])

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
func display_login(should_fill: bool) -> void:
	display_nothing()
	# _call_stack.push_front(display_login)
	_state = State.Login

	%LoginPrompt.visible = false
	%LoginPortal.visible = true
	%Username.text = ""
	%Password.text = ""

	if should_fill:
		var username := " Felxi092"
		var password := " ********"
		if not _has_done_login:
			_has_done_login = true
			for i in range(username.length()):
				%Username.text = username.substr(0, i + 1)
				$Audio.play()
				await get_tree().create_timer(0.1).timeout
			await get_tree().create_timer(0.5).timeout
			for i in range(password.length()):
				%Password.text = password.substr(0, i + 1)
				$Audio.play()
				await get_tree().create_timer(0.1).timeout
		else:
			%Username.text = username
			%Password.text = password
		
		%LoginPrompt.visible = true
		_login_done = true

func display_name_input() -> void:
	display_nothing()
	_call_stack.push_front(display_name_input)
	_state = State.NameInput

	_curr_name_guess = "" if not _name_succeeded else true_name

	%NameInputContainer.visible = true
	%NameResultLabel.text = ""
	display_bottom(["TextBack", "TextEnter"])

func display_about() -> void:
	display_nothing()
	_call_stack.push_front(display_about)
	_state = State.About

	%AboutContainer.visible = true
	display_title("System Information")
	display_bottom(["Done"])

func display_map() -> void:
	display_nothing()
	_call_stack.push_front(display_map)
	_state = State.Map

	%MapContainer.visible = true
	display_title("Facility Map;Pelagius Asteroid Mine")
	display_bottom(["Done"])

func display_list(title: String, options: Dictionary[String, Command], keys: Array[String], show_back := true) -> void:
	display_nothing()
	_state = State.List
	_current_list_names = options.keys()

	%ListContainer.visible = true
	display_title(title)
	display_bottom(keys)

	%EmptyLabel.visible = options.size() == 0
	
	for c in %ListElements.get_children():
		c.queue_free()

	var el
	if show_back:
		el = list_el.instantiate()
		%ListElements.add_child(el)
		el.text = " > .."
		el.command = Command.GoBack
	for o in options:
		el = list_el.instantiate()
		%ListElements.add_child(el)
		el.text = " > " + o
		el.command = options[o]


@onready var _title_w_sub_orig: String = %TopTitleWithSub.text
func display_title(title: String) -> void:
	var split = title.split(";")
	if split.size() == 1:
		%TopTitle.visible = true
		%TopTitle.text = title
	else:
		%TopTitleWithSub.visible = true
		%TopTitleWithSub.text = _title_w_sub_orig.format({"top": split[0], "bot": split[1]})

func display_bottom(keys: Array[String]) -> void:
	%BottomHelp.visible = true
	for c in %BottomHelp.get_children():
		c.visible = c.name in keys
