require ecs
require DagorEditor

[es(tag=server, no_order, on_event=EventLevelLoaded)]
def recons_edits_init_es(evt : Event)
  createEntity("ai_recons_edits")

[es(tag=server, no_order)]
def recons_edits_apply_es(evt : UpdateStageInfoAct;
                          var recons_edits__saveComponentsEids : EidList&;
                          var recons_edits__saveComponentsNames : StringList&)
  if empty(recons_edits__saveComponentsEids)
    return

  for eid, name in recons_edits__saveComponentsEids, recons_edits__saveComponentsNames
    entity_obj_editor_saveComponent(eid, string(name))

  clear(recons_edits__saveComponentsEids)
  clear(recons_edits__saveComponentsNames)
