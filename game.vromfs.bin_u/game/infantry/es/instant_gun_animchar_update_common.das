module instant_gun_animchar_update_common shared

require ecs
require AnimV20
require PhysVars
require AnimatedPhys




def instant_gun_animchar_anim_update(eid : EntityId)
  query(eid) <| $ [es] (attaches_list : EidList;
                        var animchar aka gun_animchar : AnimcharBaseComponent;
                        var phys_vars : PhysVars;
                        var anim_phys : AnimatedPhys;
                        var animchar_node_wtm : AnimcharNodesMat44&;
                        var animchar_render__root_pos : vec4f&)
    var attachmentIds : array<int>
    for modEid in attaches_list
      query(modEid) <| $ [es] (var animchar aka mod_animchar : AnimcharBaseComponent;
                               slot_attach__slotId : int)
        attachmentIds.push(gun_animchar |> animchar_setAttachedChar(slot_attach__slotId, uint(modEid), mod_animchar, false))

    
    
    
    
    anim_phys |> anim_phys_update(animchar, phys_vars)
    
    animchar |> animchar_act(0.f, true)
    animchar |> animchar_act(0.f, true)
    animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)

    for attachmentId in attachmentIds
      if attachmentId >= 0
        animchar |> animchar_releaseAttachment(attachmentId)
