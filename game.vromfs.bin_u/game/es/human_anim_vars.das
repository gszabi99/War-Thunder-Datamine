require ecs
require PhysVars

[es(on_appear)]
def init_human_anim_vars(evt : Event;
                         var human_anim__horizontalSpeedVarId : int&;
                         var human_anim__selectedWeaponVarId : int&;
                         var phys_vars : PhysVars)
  human_anim__selectedWeaponVarId = phys_vars |> registerVar("weapon_selected", 0.0)
  human_anim__horizontalSpeedVarId = phys_vars |> registerVar("horizontal_speed", 0.0)
