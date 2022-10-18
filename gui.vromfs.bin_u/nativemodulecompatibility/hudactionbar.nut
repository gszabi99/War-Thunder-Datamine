#allow-root-table
return {
  getActionBarItems = @() getroottable()?["get_action_bar_items"]()
  getWheelBarItems = @() getroottable()?["getWheelBarItems"]()
  getActionShortcutIndexByType = @(code) getroottable()?["get_action_shortcut_index_by_type"](code)
  activateActionBarAction = @(shortcutIdx) getroottable()?["activate_action_bar_action"](shortcutIdx)
  getActionBarUnitName = @() getroottable()?["get_action_bar_unit_name"]()
  getOwnerUnitName = @() getroottable()?["get_owner_unit_name"]()
  getForceWeapTriggerGroup = @() getroottable()?["get_force_weap_trigger_group"]()
  getAiGunnersState = @() getroottable()?["get_ai_gunners_state"]()
  getAutoturretState = @() getroottable()?["get_autoturret_state"]()
  getCurrentTriggerGroup = @() getroottable()?["get_current_trigger_group"]()
  singleTorpedoSelected = @() getroottable()?["single_torpedo_selected"]()
  selectActionBarAction = @(_shortcutId) null
}
