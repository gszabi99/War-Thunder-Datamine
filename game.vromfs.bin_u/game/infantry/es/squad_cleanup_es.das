require ecs

[es(tag=server, after=(squad_members_count_es, squad_members_count_trigger_es))]
def squad_cleanup_es(act : UpdateStageInfoAct; eid : EntityId;
                     squad__leader : EntityId; squad__numAliveMembers : int;
                     var squad__hasMembersBefore : bool&;
                     squad__doNotCleanUp : bool = false)
  if squad__doNotCleanUp
    return
  if squad__numAliveMembers > 0
    squad__hasMembersBefore = true
  elif squad__hasMembersBefore
    if !doesEntityExist(squad__leader)
      destroyEntity(eid)
