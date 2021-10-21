return {
  getActionBarItems = @() ::get_action_bar_items?()
  getWheelBarItems = @() ::getWheelBarItems?()
  getActionShortcutIndexByType = @(code) ::get_action_shortcut_index_by_type?(code)
  activateActionBarAction = @(shortcutIdx) ::activate_action_bar_action?(shortcutIdx)
  getActionBarUnitName = @() ::get_action_bar_unit_name?()
  getForceWeapTriggerGroup = @() ::get_force_weap_trigger_group?()
  getAiGunnersState = @() ::get_ai_gunners_state?()
  getAutoturretState = @() ::get_autoturret_state?()
  getCurrentTriggerGroup = @() ::get_current_trigger_group?()
  singleTorpedoSelected = @() ::single_torpedo_selected?()
}
