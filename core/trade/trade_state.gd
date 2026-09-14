class_name TradeState
extends RefCounted
## Persistent economic history. Current graph membership is reconstructed.

var lineages: Array[TradeNetworkLineageState] = []
var history: Array[TradeHistoryRecord] = []
## Contributions from an authorized rule layer; Phase 4 only uses controlled fixtures.
var authorized_links: Array[TradeLinkState] = []
var trade_revision: int = 0
var topology_signature: String = ""


func lineage(id: int) -> TradeNetworkLineageState:
	for value: TradeNetworkLineageState in lineages:
		if value != null and value.lineage_id == id:
			return value
	return null
