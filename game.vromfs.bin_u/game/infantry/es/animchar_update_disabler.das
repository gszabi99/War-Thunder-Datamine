require ecs

[es(on_appear, REQUIRE=(human, deadEntity))]
def disable_attachhes_animchar_update_on_die(evt : Event; attaches_list : EidList)
  for eid in attaches_list
    query(eid) <| $ [es(REQUIRE=animchar__noUpdateOnDeath)] (var animchar__updatable : bool&)
      animchar__updatable = false

[es(on_appear, track=animchar_attach__attachedTo, REQUIRE=animchar__noUpdateOnDeath)]
def disable_attachhes_animchar_on_create_to_dead_entity(evt : Event;
                                                        animchar_attach__attachedTo : EntityId;
                                                        var animchar__updatable : bool&)
  query(animchar_attach__attachedTo) <| $ [es(REQUIRE=(human, deadEntity))] ()
    animchar__updatable = false
