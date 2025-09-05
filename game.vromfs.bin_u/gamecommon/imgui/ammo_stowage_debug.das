options no_aot
require ecs
require imgui
require daslib/enum_trait
require %danetlibs.imgui_daeditor.imgui.imgui_common
require %game.utils.component_bundle_macro

require app
require AmmoStowage
require Unit
require Weapon
require %game.unit.ammo_stowage_common
require %game.utils.utils_common


[generic]
def iter_enum_values_and_names(en : auto(T), f : block<(val : T; name : string) : void>) : void
  let names = typeinfo enum_names(type<T>)
  for val, idx in each_enum(en), 0..typeinfo enum_length(type<T>)
    f |> invoke(val, names[idx])

[generic]
def imgui_text_flags_inline(en; flags) : void
  iter_enum_values_and_names(en) <| $(flag; name : string)
    if get_flag(flags, flag)
      imgui::SameLine()
      imgui::Text(name)


[es(on_event=CmdImGuiDebug, REQUIRE=unit__ref), with_bundle(v)]
def ammo_stowage_im_dbg(evt : Event;
                        v : tuple<
                          unit__ref : UnitRef;
                          ammo_stowage__ammoState : uint;
                          ammo_stowage__weaponTriggers : IntList;
                          ammo_stowage__ammoTypeRemap : IPoint4List;
                          ammo_stowages__state : UInt32List;
                          ammo_stowages__weaponTriggersRange : IPoint2List;
                          ammo_stowages__clustersRange : IPoint2List;
                          ammo_clusters__state : UInt32List;
                          ammo_clusters__slotsRange : IPoint2List;
                          ammo_clusters__typeAndStage : UInt16List;
                          ammo_slots__numAmmo : IPoint2List;
                          ammo_slots__ammoMaskAndType : UInt32List;
                          ammo_per_type_data__state : UInt32List;
                          ammo_per_type_data__numAmmoFs : IntList
                          >)
  if !imgui::TreeNodeEx("Ammo Stowage", ImGuiTreeNodeFlags.Framed)
    return
  imgui::BeginGroup()
  let show_types = imgui_edit_blk_val("ammo_stowage", "showTypes", true) <| $(var val : bool?#)
    imgui::Checkbox("Show Types", val)
  imgui::EndGroup()
  for stowage_id in 0..length(v.ammo_stowages__state)
    if !imgui::TreeNode("stowage #{stowage_id}")
      continue
    imgui::Text("Flags:")
    imgui_text_flags_inline(AmmoStowageState.HAS_AUTO_LOAD, v.ammo_stowages__state[stowage_id])
    imgui::BeginGroup()
    let triggers_range = v.ammo_stowages__weaponTriggersRange[stowage_id]
    for i in triggers_range.x..triggers_range.y
      if v.unit__ref.unit.weap.Weapons |> is_weapon_reloading(v.ammo_stowage__weaponTriggers[i], get_sync_time())
        imgui::Text("reloading: {v.ammo_stowage__weaponTriggers[i]}")
    imgui::EndGroup()

    let ammo_type_count = length(v.ammo_stowage__ammoTypeRemap)
    let per_ammo_offset = stowage_id * ammo_type_count
    imgui::Text("Ammo Types & State:")
    for ammo_type in 0..ammo_type_count
      let glob_ammo_idx = per_ammo_offset + ammo_type
      let ammo_type_remap = v.ammo_stowage__ammoTypeRemap[ammo_type]
      if ammo_type_remap.x != stowage_id
        continue
      imgui::BeginGroup()
      imgui::Indent()
      imgui::Text("type #{ammo_type} fsNum:{v.ammo_per_type_data__numAmmoFs[glob_ammo_idx]}")
      imgui_text_flags_inline(AmmoStowagePerAmmoState.EMPTY, v.ammo_per_type_data__state[glob_ammo_idx])
      imgui::EndGroup()

    let clusters_range = v.ammo_stowages__clustersRange[stowage_id]
    for cluster_id in clusters_range.x..clusters_range.y
      let cluster_type_str = get_ammo_cluster_type(cluster_id, v) == int(AmmoClusterType.SHELLS) ? "shells" : "charges"
      let cluster_stage = get_ammo_cluster_stage(cluster_id, v)
      var cluster_stage_str = ""
      if cluster_stage == int(AmmoClusterStage.LOADED_IN_GUN)
        cluster_stage_str = "loaded-in-gun"
      elif cluster_stage == int(AmmoClusterStage.FIRST_STAGE)
        cluster_stage_str = "first stage"
      elif cluster_stage == int(AmmoClusterStage.SECOND_STAGE)
        cluster_stage_str = "second stage"
      elif cluster_stage == int(AmmoClusterStage.NO_RELOAD)
        cluster_stage_str = "no reload"
      imgui::Text("cluster #{cluster_id} {cluster_stage_str}, {cluster_type_str}")
      imgui_text_flags_inline(AmmoClusterState.EMPTY, v.ammo_clusters__state[cluster_id])
      let slots_range = v.ammo_clusters__slotsRange[cluster_id]
      imgui::BeginGroup()
      imgui::Indent()
      var slots_str = ""
      for slot_id in slots_range.x..slots_range.y
        if show_types
          slots_str += v.ammo_slots__numAmmo[slot_id].x == 0 ? " " : "{int(v.ammo_slots__ammoMaskAndType[slot_id] & 0xff)}"
        else
          slots_str += v.ammo_slots__numAmmo[slot_id].x == 0 ? " " : "#"
      imgui::Text("slots [{slots_range.x}..{slots_range.y}): [{slots_str}]")
      imgui::EndGroup()

    imgui::TreePop()

  imgui::Text("Global Flags:")
  imgui_text_flags_inline(AmmoState.ENABLE_PER_AMMO_TYPES, v.ammo_stowage__ammoState)
  imgui::TreePop()
