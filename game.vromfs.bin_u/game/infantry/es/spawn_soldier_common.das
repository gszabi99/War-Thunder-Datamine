module spawn_soldier_common shared

require ecs
require ecs.safe
require DagorSystem

def private gather_dependent_templates(baseTemplate : Template;
                                       soldierComponents : Object const?;
                                       depcb : block<(ptname : das_string const?) : void>)
  
  var weapTemplatesPtr = get_ecs_object(soldierComponents, "human_weap__weapTemplates")
  if weapTemplatesPtr == null
    weapTemplatesPtr = getTemplateComponent(baseTemplate, "human_weap__weapTemplates") ?as Object
  if weapTemplatesPtr != null
    for kv in *weapTemplatesPtr
      depcb |> invoke(get_ecs_string(kv.value))

  var weapInfoPtr = get_ecs_array(soldierComponents, "human_weap__weapInfo")
  if weapInfoPtr == null
    weapInfoPtr = getTemplateComponent(baseTemplate, "human_weap__weapInfo") ?as Array
  if weapInfoPtr != null
    for weapInfoSlot in *weapInfoPtr
      let weapInfoSlotObj = weapInfoSlot as Object

      depcb |> invoke(weapInfoSlotObj |> get_ecs_string("reserveAmmoTemplate"))

      let additionalAmmoTemplates = weapInfoSlotObj?.additionalReserveAmmoTemplates ?as Array
      if additionalAmmoTemplates != null
        for ammoTemplateItem in *additionalAmmoTemplates
          depcb |> invoke(ammoTemplateItem as string)

  var itemRemapPtr = get_ecs_object(soldierComponents, "human_weap__itemRemap")
  if itemRemapPtr == null
    itemRemapPtr = getTemplateComponent(baseTemplate, "human_weap__itemRemap") ?as Object
  if itemRemapPtr != null
    for kv in *itemRemapPtr
      depcb |> invoke(get_ecs_string(kv.value))


def init_soldier_tpl_deps(baseTemplate : Template;
                          var initOut : ComponentsInitializer;
                          soldierComponents : Object const? = null)
  let depsCompKey = "human_weap__template_deps_list"
  let depsCompHash = ecs_hash(depsCompKey)
  if !templateHasComponent(baseTemplate, depsCompKey, depsCompHash)
    return false

  using() <| $(var depsList : StringList)
    
    let baseDepsPtr = get_ecs_StringList(getTemplateComponent(baseTemplate, "human_weap__template_deps_list"))
    if baseDepsPtr != null
      for ptname in *baseDepsPtr
        if ptname != ""
          depsList |> push(ptname)
        else
          logerr("Unexpected empty template in human_weap__template_deps_list")

    gather_dependent_templates(baseTemplate, soldierComponents) <| $(ptname : das_string const?) : void
      if ptname != null && *ptname != ""
        depsList |> push(*ptname)
    set(initOut, depsCompKey, depsCompHash, depsList)
  return true

def get_item_sub_template(itemTemplate; slot) : string
  let tpl = getTemplateByName(itemTemplate)
  if tpl == null
    logerr("Cannot create an equipment: template '{itemTemplate}' is not found for the slot '{slot}'")
    return ""

  return getTemplateComponent(*tpl, "item__recreateInEquipment") ?? "base_vis_item"

def get_item_template_for_equipment(item_template : string; is_spawn_in_vehicle : bool)
  let tpl = getTemplateByName(item_template)
  if tpl == null
    logerr("Cannot replace an equipment: template '{item_template}' is not found")
    return item_template

  let baseTemplate = (!is_spawn_in_vehicle
    ? getTemplateComponent(*tpl, "item__replaceOnSpawnOnGround") ?? item_template
    : item_template)
  if empty(baseTemplate)
    return ""

  let addTemplate = getTemplateComponent(*tpl, "item__recreateInEquipment") ?? "base_vis_item"
  return "{baseTemplate}+{addTemplate}"
