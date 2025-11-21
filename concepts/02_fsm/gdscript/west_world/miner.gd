class_name Miner extends BaseGameEntity

var location: String = Location.SHACK
var gold_carried: int = 0
var money_in_bank: int = 0
var thirst: int = 0
var fatigue: int = 0

# Using a weakref or direct reference if guaranteed to exist. 
# In a real game, use an ID or a service locator.
var wife: BaseGameEntity

const COMFORT_LEVEL = 5
const MAX_NUGGETS = 3
const THIRST_LEVEL = 5
const TIREDNESS_THRESHOLD = 5

func _ready() -> void:
	super._ready()
	# Setup states
	var go_home_state = GoHomeAndSleepTilRested.new()
	state_machine.set_current_state(go_home_state)

func update_stats() -> void:
	thirst += 1
	
func add_gold(amount: int) -> void:
	gold_carried += amount
	
func deposit_gold() -> void:
	money_in_bank += gold_carried
	gold_carried = 0
	
func buy_and_drink_whiskey() -> void:
	thirst = 0
	money_in_bank -= 2

func is_pockets_full() -> bool:
	return gold_carried >= MAX_NUGGETS

func is_thirsty() -> bool:
	return thirst >= THIRST_LEVEL

func is_fatigued() -> bool:
	return fatigue > TIREDNESS_THRESHOLD

# States --------------------------------------------------------------

class EnterMineAndDigForGold extends State:
	func enter(entity: Node) -> void:
		if entity.location != Location.GOLD_MINE:
			print(entity.name, ": Walkin' to the goldmine")
			entity.location = Location.GOLD_MINE
			
	func execute(entity: Node) -> void:
		entity.add_gold(1)
		entity.fatigue += 1
		entity.update_stats()
		print(entity.name, ": Pickin' up a nugget")
		
		if entity.is_pockets_full():
			entity.state_machine.change_state(VisitBankAndDepositGold.new())
		elif entity.is_thirsty():
			entity.state_machine.change_state(QuenchThirst.new())

	func exit(entity: Node) -> void:
		print(entity.name, ": Ah'm leavin' the goldmine with mah pockets full o' sweet gold")

class VisitBankAndDepositGold extends State:
	func enter(entity: Node) -> void:
		if entity.location != Location.BANK:
			print(entity.name, ": Goin' to the bank. Yes siree")
			entity.location = Location.BANK
			
	func execute(entity: Node) -> void:
		entity.deposit_gold()
		print(entity.name, ": Depositing gold. Total savings now: ", entity.money_in_bank)
		
		if entity.money_in_bank >= 5: # Rich enough
			print(entity.name, ": WooHoo! Rich enough for now. Back home to mah li'l lady")
			entity.state_machine.change_state(GoHomeAndSleepTilRested.new())
		elif entity.is_thirsty():
			entity.state_machine.change_state(QuenchThirst.new())
		else:
			entity.state_machine.change_state(EnterMineAndDigForGold.new())
			
	func exit(entity: Node) -> void:
		print(entity.name, ": Leavin' the bank")

class GoHomeAndSleepTilRested extends State:
	func enter(entity: Node) -> void:
		if entity.location != Location.SHACK:
			print(entity.name, ": Walkin' home")
			entity.location = Location.SHACK
			
			# Message wife
			if entity.wife:
				MessageDispatcher.dispatch_message(0, entity, entity.wife, MessageTypes.MSG_HI_HONEY_IM_HOME)

	func execute(entity: Node) -> void:
		if entity.fatigue < 0: # Rested
			print(entity.name, ": All mah fatigue has drained away. Time to find more gold!")
			entity.state_machine.change_state(EnterMineAndDigForGold.new())
		else:
			entity.fatigue -= 1
			print(entity.name, ": ZZZZ...")

	func exit(entity: Node) -> void:
		print(entity.name, ": Leaving the house")
	
	func on_message(entity: Node, telegram: Telegram) -> bool:
		if telegram.msg == MessageTypes.MSG_STEW_READY:
			print(entity.name, ": Okay Hun, ahm a comin'!")
			entity.state_machine.change_state(EatStew.new())
			return true
		return false

class QuenchThirst extends State:
	func enter(entity: Node) -> void:
		if entity.location != Location.SALOON:
			print(entity.name, ": Boy, ah sure is thusty! Walking to the saloon")
			entity.location = Location.SALOON
	
	func execute(entity: Node) -> void:
		if entity.money_in_bank >= 2:
			entity.buy_and_drink_whiskey()
			print(entity.name, ": That's mighty fine sippin liquer")
			entity.state_machine.change_state(EnterMineAndDigForGold.new())
		else:
			print(entity.name, ": Error! Not enough money!")
			entity.state_machine.change_state(GoHomeAndSleepTilRested.new())
			
	func exit(entity: Node) -> void:
		print(entity.name, ": Leaving the saloon, feelin' good")

class EatStew extends State:
	func enter(entity: Node) -> void:
		print(entity.name, ": Smells Reaaal goood Elsa!")
	
	func execute(entity: Node) -> void:
		print(entity.name, ": Tastes real good too!")
		entity.state_machine.revert_to_previous_state()
		
	func exit(entity: Node) -> void:
		print(entity.name, ": Thankya li'l lady.")
