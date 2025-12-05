require ecs
require soundEvent
require AnimV20
require GeomNodeTree


[es(tag=sound, on_appear, REQUIRE_NOT=clientSide)]
def shell_appear_sound(evt : Event;
                       shell_appear_sound__hero : string;
                       shell_appear_sound__enemy : string;
                       shell__owner : EntityId)
  
  
  
  
  query(shell__owner) <| $ [es] (is_watched_sound : bool; animchar : AnimcharBaseComponent)
    let nodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, "weapon_right")
    if nodeIdx >= 0
      let pos = geomtree_getNodeWpos(*animchar.nodeTree, nodeIdx)
      oneshot(is_watched_sound ? shell_appear_sound__hero : shell_appear_sound__enemy, pos)
