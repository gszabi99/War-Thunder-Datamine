require ecs
require ecs.safe
require ecs.common
require DagorSystem
require PropsManager



def try_init_shell(shell : Object; var gun__shells : Array&)
  let shellBlk = get_ecs_string(shell, "blk")
  if shellBlk == null
    return false
  push(gun__shells, string(*shellBlk))
  return true

def init_ammo_set(eid : EntityId; ammo_set : Array const? const&; set_index : int; var gun__shells : Array&; var out_set_indices : Array)
  if ammo_set == null
    logerr("Cannot read ammo set array for {getEntityTemplateName(eid)}.
            Wrong type: gun.ammoSetsInfo should be array of arrays of objects")
    return
  for shellObj, shellIndex in *ammo_set, iter_range(*ammo_set)
    let shell = get_ecs_object(shellObj)
    if shell == null || !try_init_shell(*shell, gun__shells)
      logerr("Cannot init shell {shellIndex} in set {set_index} for {getEntityTemplateName(eid)}.")
      push(out_set_indices, -1)
      continue
    push(out_set_indices, length(gun__shells) - 1)


[es(on_appear, before=gun_init_shell_prop_ids_es)]
def ammo_sets_init_shell_props(evt : Event;
                               eid : EntityId;
                               @shared_comp gun__ammoSetsInfo : Array;
                               var gun__shells : Array&;
                               var gun__ammoSets : Array)
  clear(gun__shells)
  clear(gun__ammoSets)
  for ammoSetObj, setIndex in gun__ammoSetsInfo, iter_range(gun__ammoSetsInfo)
    let ammoSet = get_ecs_array(ammoSetObj)
    using() <| $(var ammoSetIndices : Array)
      init_ammo_set(eid, ammoSet, setIndex, gun__shells, ammoSetIndices)
      push(gun__ammoSets, ammoSetIndices)

[es(on_appear, after=(ammo_sets_init_shell_props, gun_init_shell_prop_ids_es), track=currentBulletId)]
def track_ammo_set(evt : Event;
                   eid : EntityId;
                   currentBulletId : int;
                   gun__ammoSets : Array;
                   gun__shell_prop_ids : PropsIdList;
                   var ammo_set__shellIds : IntList&)
  clear(ammo_set__shellIds)
  if currentBulletId >= length(gun__ammoSets)
    logerr("{getEntityTemplateName(eid)}: Bad ammo set id {currentBulletId}, ammoSets length: {length(gun__ammoSets)}")
    return
  let ammoSet = get_ecs_array(gun__ammoSets[currentBulletId])
  if ammoSet == null
    logerr("{getEntityTemplateName(eid)}: Cannot read ammo set {gun__ammoSets[currentBulletId]}")
    return
  let shellPropsCount = length(gun__shell_prop_ids)
  for shellIndxObj in *ammoSet
    let shellIndex = get_int(shellIndxObj) ?? -1
    if shellIndex < 0 || shellIndex >= shellPropsCount
      logerr("{getEntityTemplateName(eid)}: Wrong shell index {shellIndex} in ammo set: {ammoSet}")
    else
      push(ammo_set__shellIds, shellIndex)

[es(tag=server, on_appear, track=ammo_set__shellIds, after=track_ammo_set)]
def track_current_shell_in_set(evt : Event;
                               ammo_set__shellIds : IntList;
                               gun__shell_prop_ids : PropsIdList;
                               var gun__curShellId : PropsId&)
  let shellId = ammo_set__shellIds?[0] ?? 0
  if shellId < length(gun__shell_prop_ids)
    gun__curShellId = gun__shell_prop_ids[shellId]
