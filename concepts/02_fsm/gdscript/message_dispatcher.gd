extends Node

# MessageDispatcher
# Singleton that manages the sending of messages between entities.
# To use this, add it as an Autoload in Project Settings -> Autoload with the name "MessageDispatcher".

var _priority_queue: Array[Telegram] = []

func dispatch_message(delay: float, sender: Object, receiver: Object, msg: String, extra_info: Dictionary = {}) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var telegram = Telegram.new(sender, receiver, msg, 0, extra_info)
	
	if delay <= 0.0:
		# Immediate dispatch
		discharge(receiver, telegram)
	else:
		# Delayed dispatch
		telegram.dispatch_time = current_time + delay
		_add_to_queue(telegram)

func discharge(receiver: Object, telegram: Telegram) -> void:
	if is_instance_valid(receiver) and receiver.has_method("handle_message"):
		receiver.handle_message(telegram)

func _add_to_queue(telegram: Telegram) -> void:
	_priority_queue.append(telegram)
	# Sort so the earliest dispatch time is at the front (index 0)
	_priority_queue.sort_custom(func(a, b): return a.dispatch_time < b.dispatch_time)

func _process(_delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Process all telegrams that are due
	while not _priority_queue.is_empty() and _priority_queue[0].dispatch_time <= current_time:
		var telegram = _priority_queue.pop_front()
		discharge(telegram.receiver, telegram)
