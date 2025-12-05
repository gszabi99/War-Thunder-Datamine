require DagorSystem
require PhysVars
require ecs


[es(tag=gameClient, on_appear, before=anim_phys_init_es)]
def custom_animvars_on_create_es(evt : Event;
                                 eid : EntityId;
                                 var phys_vars : PhysVars;
                                 customAnimcharVars : Array;
                                 var customAnimcharVarIds : IntList;
                                 var customAnimcharVarValues : FloatList)
  let numOfCustomParams = length(customAnimcharVars)
  resize(customAnimcharVarIds, numOfCustomParams)
  resize(customAnimcharVarValues, numOfCustomParams)
  for i in iter_range(customAnimcharVars)
    customAnimcharVarIds[i] = -1
    let obj = get_ecs_object(customAnimcharVars[i])
    if obj == null
      continue
    let varName = get_string(*obj, "varName", "")
    let value = get_float(*obj, "value")
    if varName == "" || value == null
      logerr("can't apply custom animvars for {eid} and {getEntityTemplateName(eid)}, some of them hasn't varName or value")
      continue
    customAnimcharVarIds[i] = registerVar(phys_vars, varName, 0.f)
    customAnimcharVarValues[i] = *value

[es(tag=gameClient, on_event=EventApplyCustomAnimcharVars)]
def custom_animvars_applyer_es(evt : Event;
                               var phys_vars : PhysVars;
                               customAnimcharVarIds : IntList;
                               customAnimcharVarValues : FloatList)
  if length(customAnimcharVarIds) != length(customAnimcharVarValues)
    logerr("The number of values ​​does not match the number of ids")
    return
  for i in iter_range(customAnimcharVarIds)
    if customAnimcharVarIds[i] >= 0
      setVar(phys_vars, customAnimcharVarIds[i], customAnimcharVarValues[i])
