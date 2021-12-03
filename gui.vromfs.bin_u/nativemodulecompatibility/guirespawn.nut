return {
  fetchChangeAircraftOnStart = @() ::fetch_change_aircraft_on_start?()
  canRespawnCaNow = @() ::can_respawn_ca_now?()
  canRequestAircraftNow = @() ::can_request_aircraft_now?()
  setSelectedUnitInfo = @(unitName, slot_num) null
  getAvailableRespawnBases = @(arr) ::get_available_respawn_bases?(arr)
  getAvailableRespawnBasesDebug = @(arr) ::get_available_respawn_bases_debug?(arr)
  getRespawnBaseNameById = @(id) ::get_respawn_base_name_by_id?(id)
  getRespawnBaseTimeLeftById = @(id) ::get_respawn_base_time_left_by_id?(id)
  isDefaultRespawnBase = @(id) ::is_default_respawn_base?(id)
  selectRespawnBase = @(id) ::select_respawnbase?(id)
  highlightRespawnBase = @(id) null
  getRespawnBase = @(x, y) ::get_respawn_base?(x, y)
}
