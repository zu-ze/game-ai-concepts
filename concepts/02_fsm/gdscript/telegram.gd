class_name Telegram

var sender: Object
var receiver: Object
var msg: String
var dispatch_time: float
var extra_info: Dictionary

func _init(p_sender: Object, p_receiver: Object, p_msg: String, p_dispatch_time: float, p_extra_info: Dictionary = {}) -> void:
	sender = p_sender
	receiver = p_receiver
	msg = p_msg
	dispatch_time = p_dispatch_time
	extra_info = p_extra_info
