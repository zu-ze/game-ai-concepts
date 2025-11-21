class_name BaseGameEntity extends CharacterBody2D

# Simple static ID counter
static var _next_valid_id: int = 0

var id: int
var bounding_radius: float = 10.0
var state_machine: StateMachine

func _init() -> void:
	id = _next_valid_id
	_next_valid_id += 1

func _ready() -> void:
	state_machine = StateMachine.new(self)

func _physics_process(_delta: float) -> void:
	state_machine.update()

func handle_message(telegram: Telegram) -> bool:
	return state_machine.handle_message(telegram)
