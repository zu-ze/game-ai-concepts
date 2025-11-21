class_name MinnersWife extends BaseGameEntity

var location: String = Location.SHACK
var cooking: bool = false

# States --------------------------------------------------------------

func _ready() -> void:
	super._ready()
	var global_state = WifesGlobalState.new()
	state_machine.set_global_state(global_state)
	var start_state = DoHouseWork.new()
	state_machine.set_current_state(start_state)

class WifesGlobalState extends State:
	func execute(entity: Node) -> void:
		# 1 in 10 chance of needing to go to the bathroom
		if randf() < 0.1:
			entity.state_machine.change_state(VisitBathroom.new())
			
	func on_message(entity: Node, telegram: Telegram) -> bool:
		if telegram.msg == MessageTypes.MSG_HI_HONEY_IM_HOME:
			print(entity.name, ": Hi honey. Let me make you some of mah fine stew")
			entity.state_machine.change_state(CookStew.new())
			return true
		return false

class DoHouseWork extends State:
	func enter(entity: Node) -> void:
		print(entity.name, ": Time to do some more housework!")
		
	func execute(entity: Node) -> void:
		var chore = randi() % 3
		match chore:
			0: print(entity.name, ": Moppin' the floor")
			1: print(entity.name, ": Washin' the dishes")
			2: print(entity.name, ": Makin' the bed")

	func exit(entity: Node) -> void:
		pass

class VisitBathroom extends State:
	func enter(entity: Node) -> void:
		print(entity.name, ": Walkin' to the can. Need to powda mah nose")
		
	func execute(entity: Node) -> void:
		print(entity.name, ": Ahhhhhh! Sweet relief!")
		entity.state_machine.revert_to_previous_state()
		
	func exit(entity: Node) -> void:
		print(entity.name, ": Leavin' the Jon")

class CookStew extends State:
	func enter(entity: Node) -> void:
		if not entity.cooking:
			print(entity.name, ": Putting the stew in the oven")
			# Send delayed message to self
			MessageDispatcher.dispatch_message(1.5, entity, entity, MessageTypes.MSG_STEW_READY)
			entity.cooking = true
			
	func execute(entity: Node) -> void:
		print(entity.name, ": Fussin' over food")
		
	func exit(entity: Node) -> void:
		print(entity.name, ": Puttin' the stew on the table")
		
	func on_message(entity: Node, telegram: Telegram) -> bool:
		if telegram.msg == MessageTypes.MSG_STEW_READY:
			print(entity.name, ": StewReady! Lets eat")
			# Notify Miner (sender of the original HiHoney msg is lost here unless stored, 
			# so we assume we can find the miner or pass it in extra_info. 
			# For simplicity, let's assume the miner is findable or we broadcast)
			# In this specific simplified implementation we need a ref to miner.
			
			# HACK: Assuming parent has reference or finding by name for demo
			var miner = entity.get_parent().find_child("Miner", true, false)
			if miner:
				MessageDispatcher.dispatch_message(0, entity, miner, MessageTypes.MSG_STEW_READY)
			
			entity.cooking = false
			entity.state_machine.change_state(DoHouseWork.new())
			return true
		return false
