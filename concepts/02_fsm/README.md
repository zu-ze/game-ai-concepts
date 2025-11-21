# State-Driven Agent Design (FSM)

This module implements a Finite State Machine (FSM) with message passing capabilities (Telegram system), similar to the implementation described in *Programming Game AI by Example* by Mat Buckland.

## Components

1.  **BaseGameEntity**: The base class for game entities. It holds a unique ID and a reference to the StateMachine.
2.  **State**: An abstract base class (or interface) defining `enter`, `execute`, `exit`, and `on_message`.
3.  **StateMachine**: Manages the current, previous, and global states. It delegates updates and messages to the active state.
4.  **Telegram**: A data structure holding message details (sender, receiver, message type, dispatch time, extra info).
5.  **MessageDispatcher**: A singleton that manages immediate and delayed message delivery.

## Setup

### GDScript
1.  Go to **Project -> Project Settings -> Globals -> Autoload**.
2.  Add `concepts/02_fsm/gdscript/message_dispatcher.gd` as an Autoload named **MessageDispatcher**.
3.  Create your entities by extending `BaseGameEntity`.
4.  Create your states by extending `State`.

### C#
1.  Go to **Project -> Project Settings -> Globals -> Autoload**.
2.  Add `concepts/02_fsm/csharp/MessageDispatcher.cs` as an Autoload named **MessageDispatcherCS** (to avoid conflict if using both, or just MessageDispatcher if using only C#).
3.  Build the solution to ensure Godot recognizes the C# classes.
4.  Create your entities by inheriting `BaseGameEntity`.
5.  Create your states by inheriting `State<T>`.

## Usage Example (GDScript)

```gdscript
# MyEntity.gd
extends BaseGameEntity

func _ready():
    super._ready()
    var start_state = MyIdleState.new()
    state_machine.set_current_state(start_state)

# MyIdleState.gd
class_name MyIdleState extends State

func enter(entity):
    print("Entering Idle")

func execute(entity):
    if entity.some_condition:
        entity.state_machine.change_state(MyActionState.new())

func on_message(entity, telegram):
    if telegram.msg == "Attack":
        print("Attacked!")
        return true
    return false
```

## Messaging
To send a message:
```gdscript
# GDScript
MessageDispatcher.dispatch_message(2.0, self, target_entity, "Hello", {"data": 123})
```

```csharp
// C#
MessageDispatcher.Instance.DispatchMessage(2.0f, this, targetEntity, "Hello", null);
```
