class_name FeatureLineageState
extends RefCounted
## Historical identity. Merged parents remain archived, with their own records intact.

var lineage_id: int = 0
var feature_type: DomainTypes.FeatureType = DomainTypes.FeatureType.ROAD
var parent_ids: Array[int] = []
var active: bool = true
var completed: bool = false
var growth_phase: int = 1
var member_ids: Array[int] = []
var scored_component_ids: Array[int] = []
## Support/contact identities are stable physical board-base IDs, scoped to this lineage.
var scored_field_ids: Array[int] = []
var scored_river_ids: Array[int] = []
var scored_forest_ids: Array[int] = []
## Reserved for Phase 4. Phase 3 never awards the network connection bonus.
var scored_settlement_ids: Array[int] = []
var completion_ids: Array[int] = []
var highest_settlement_class: int = 0
