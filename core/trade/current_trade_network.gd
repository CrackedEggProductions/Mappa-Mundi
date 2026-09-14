class_name CurrentTradeNetwork
extends RefCounted
## Derived connected economic graph, never a replacement for physical Road topology.

var lineage_id: int = 0
var road_lineage_ids: Array[int] = []
var settlement_lineage_ids: Array[int] = []
var links: Array[TradeLinkState] = []


func signature() -> String:
	var edge_signatures: Array[String] = []
	for link: TradeLinkState in links:
		edge_signatures.append(link.signature())
	edge_signatures.sort()
	return "%s/%s/%s" % [road_lineage_ids, settlement_lineage_ids, "|".join(edge_signatures)]
