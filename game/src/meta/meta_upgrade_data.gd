class_name MetaUpgradeData
extends Resource
## One file per permanent upgrade, bought with cells between runs. Each rank adds
## `amount_per_rank` of its effect to every later run; `costs[r]` buys rank r + 1.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect: BoonData.Effect = BoonData.Effect.MAX_HEALTH
@export var amount_per_rank: float = 0.0
@export var costs: Array[int] = []
