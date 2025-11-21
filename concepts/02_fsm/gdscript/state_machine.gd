class_name StateMachine extends RefCounted

var owner: Node
var current_state: State
var previous_state: State
var global_state: State

func _init(p_owner: Node) -> void:
	owner = p_owner

func set_current_state(s: State) -> void:
	current_state = s

func set_global_state(s: State) -> void:
	global_state = s

func set_previous_state(s: State) -> void:
	previous_state = s

func update() -> void:
	if global_state:
		global_state.execute(owner)
	if current_state:
		current_state.execute(owner)

func change_state(new_state: State) -> void:
	if new_state == null:
		push_error("StateMachine: trying to change to null state")
		return

	previous_state = current_state
	
	if current_state:
		current_state.exit(owner)
		
	current_state = new_state
	current_state.enter(owner)

func revert_to_previous_state() -> void:
	if previous_state:
		change_state(previous_state)

func handle_message(telegram: Telegram) -> bool:
	# First see if the current state handles it
	if current_state and current_state.on_message(owner, telegram):
		return true
	
	# Then check the global state
	if global_state and global_state.on_message(owner, telegram):
		return true
		
	return false

func is_in_state(state_check: State) -> bool:
	return current_state == state_check
