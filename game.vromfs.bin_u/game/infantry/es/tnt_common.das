module tnt_common shared
require ecs
require ecs.enum_macro
require %appGame.infantry.es.throwable_common

enum TntExploderAnimState
  TEAS_NONE
  TEAS_DETONATING
  TEAS_RELOADING

def detonate_tnt_block(eid : EntityId)
  query(eid) <| $ [es] (transform : float3x4;
                        tnt_block__activatorTemplate : string;
                        tnt_block__owner : EntityId)
    createEntity(tnt_block__activatorTemplate) <| $(var init : ComponentsInitializer)
      set(init, "ownerEid", tnt_block__owner)
      set(init, "transform", transform)
    destroyEntity(eid)

def tnt_exploder_with_launcher_throw_tnt(owner : EntityId;
                                         tnt_exploder_with_launcher : EntityId;
                                         at_time : float;
                                         throwable_launcher__itemsCount : int;
                                         throwable_launcher__inProgress : bool;
                                         tnt_exploder__inProgress : bool)

  if tnt_exploder__inProgress || throwable_launcher__inProgress || throwable_launcher__itemsCount <= 0
    return
  throwable_launcher_request_throw(owner, tnt_exploder_with_launcher, at_time)
