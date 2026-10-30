module supply_transport_common shared
require Mission

enum SupplyTransportState
  IDLE = 0
  LOADING = 1
  UNLOADING = 2

enum SupplyTransportHint
  NONE = 0
  LOADED = 1
  UNLOADED = 2
  UNDER_FIGHT = 3
  NODE_FULL = 4

enum SupplyRewardKind
  UNLOAD = 0
  RETURN = 1
  DESTROY = 2
  ESCORT = 3

def in_area(area_name : string; pos : float2) : bool
  let areaId = get_area_id(area_name)
  return areaId >= 0 && is_in_area(areaId, pos)
