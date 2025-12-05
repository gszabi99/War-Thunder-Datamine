let { canHoldBreath, canScopeChange } = require("%appGlobals/hud/humanPhysState.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")

canHoldBreath.subscribe(function(v) {
  g_hud_event_manager.onHudEvent(v
    ? "hint:human_hold_breath_show"
    : "hint:human_hold_breath_hide"
  )
})

canScopeChange.subscribe(function(v) {
  g_hud_event_manager.onHudEvent(v
    ? "hint:human_change_scope_show"
    : "hint:human_change_scope_hide"
  )
})