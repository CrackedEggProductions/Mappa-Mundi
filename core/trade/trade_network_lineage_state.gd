class_name TradeNetworkLineageState
extends RefCounted
## Last reconciled membership identifies history; never substitutes for rebuilt connectivity.

var lineage_id: int = 0
var parent_ids: Array[int] = []
var active: bool = true
var road_lineage_ids: Array[int] = []
var settlement_lineage_ids: Array[int] = []
