options no_aot
require ecs
require ecs.safe
require daslib/strings_boost
require danetlibs.console_commands.main.console_common
require %appGame.infantry.es.human_weap_common
require %appGame.infantry.es.console_debug_common
require strings
require %appGame.infantry.es.net_console_macro


[console_processor]
def inventory_creation_weap_mod_debug_processor(args : array<string>;
                                                collect : bool;
                                                var hints : ConsoleProcessorHints)
  let cmd = "inventory.create_weap_mod"
  if collect
    let inputs <- args[0] |> split(" ")
    if length(inputs) >= 2 && inputs[0] == cmd
      let weaponHolderEid = try_get_hero_cmd_param(inputs, 3)
      query(weaponHolderEid) <| $ [es] (human_weap__currentGunSlot : int;
                                        human_weap__gunEids : EidList)
        var wishGunSlot = human_weap__currentGunSlot
        if length(inputs) > 2 && inputs[2] != ""
          
          var res : ConversionResult
          var ofs : int
          let input = int(inputs[2], res, ofs)
          if res == ConversionResult.ok && ofs == length(inputs[2])
            
            if input >= 0
              wishGunSlot = input
          else
            console_print("Failed to parse wish gun slot, using human_weap__currentGunSlot = {human_weap__currentGunSlot}")
        if wishGunSlot < 0 || wishGunSlot > length(human_weap__gunEids) - 1
          return
        query(human_weap__gunEids[wishGunSlot]) <| $ [es] (gun_mods__slots : Object)
          for slot in gun_mods__slots
            let slotName = slot.key
            let modObj = slot.value as Object
            if modObj == null
              continue
            for mod in *modObj
              let templateName = mod.value ?? ""
              hints |> add_hint("{cmd} {templateName}", 0, 2, "(slot: {slotName})")
  return false

[net_console_cmd(name="inventory.create_weap_mod", hint="Create and attach weapon mod with template to the weapon (selected weapon by default)")]
def inventory_creation_weap_mod_debug_cmd(mod_template : string;
                                          gun_slot_id : int = -1;
                                          @net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (human_weap__currentGunSlot : int;
                             var human_weap__gunEids : EidList)
    let wishGunSlot = gun_slot_id >= 0 ? gun_slot_id : human_weap__currentGunSlot
    if wishGunSlot < 0 || wishGunSlot > length(human_weap__gunEids) - 1
      console_print("Invalid gun slot id {wishGunSlot}")
      return
    query(human_weap__gunEids[wishGunSlot]) <| $ [es] (var gun_mods__slots : Object)
      let tpl = getTemplateByName(mod_template)
      if tpl == null
        console_print("Couldn't find template {mod_template}")
        return
      let tag = getTemplateComponent(*tpl, "gunAttachable__slotTag") ?? ""
      if tag == ""
        console_print("Mod {mod_template} missing 'gunAttachable__slotTag'")
        return
      let node = getTemplateComponent(*tpl, "gunAttachable__gunSlotName") ?? ""
      if node == ""
        console_print("Mod {mod_template} missing 'gunAttachable__gunSlotName'")
        return
      var nodeSlot = gun_mods__slots[node] |> getRW_ecs_object()
      if nodeSlot != null
        *nodeSlot |> set(tag, mod_template)
      else
        using() <| $(var newSlot : Object)
          newSlot |> set(tag, mod_template)
          gun_mods__slots |> set(node, newSlot)
          server_init_gun(hero_eid, human_weap__gunEids[wishGunSlot], wishGunSlot, human_weap__gunEids)
      var nullCustomProps : Object? = null
      human_weap_attach_item_to_gun(hero_eid, wishGunSlot, tag, node, true, nullCustomProps)


[net_console_cmd(name="inventory.create_weap_slot_item", hint="Create entity, set hero as owner and put to weapon slot")]
def inventory_create_weap_slot_item_debug_cmd(item_template : string;
                                              gun_slot_id : int;
                                              ammo_index : int = 0;
                                              ammo_count : int = 5;
                                              @net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (var human_weap__gunEids : EidList)
    destroyEntity(human_weap__gunEids[gun_slot_id])
    human_weap__gunEids[gun_slot_id] = createEntity(item_template) <| $(var init : ComponentsInitializer)
      set(init, "item__lastOwner", hero_eid)
      set(init, "item__ownerEid", hero_eid)
      set(init, "gun__owner", hero_eid)

    var gunTemplate = getTemplateByName(item_template)
    if gunTemplate == null
      gunTemplate = buildTemplateByName(item_template)
      if gunTemplate == null
        return

    let gunAmmoHolders = get_ecs_array(getTemplateComponent(*gunTemplate, "gun__ammoHolders"))

    let ammoTemplate = gunAmmoHolders?[ammo_index] ?? ""
    if ammoTemplate == ""
      return

    for _i in range(0, ammo_count)
      createEntity(ammoTemplate) <| $(var init : ComponentsInitializer)
        set(init, "item__ownerEid", hero_eid)

[console_processor]
def inventory_create_weap_slot_item_debug_processor(args : array<string>;
                                                    collect : bool;
                                                    var hints : ConsoleProcessorHints)
  let cmd = "inventory.create_weap_slot_item"
  if collect
    let inputs <- args[0] |> split(" ")
    if length(inputs) >= 2
      add_hints(fixed_array(CommandArgDesc(name = "template_name", hintType = CommandArgHintType.TemplateName),
                         CommandArgDesc(name = "slot", hintType = CommandArgHintType.Default),
                         CommandArgDesc(name = "eid", hintType = CommandArgHintType.EntityId, defaultValue = "0")),
                cmd, inputs,  20,  2500.0, hints)
  return false


[net_console_cmd(name="inventory.create_owned_item", hint="Create entity and set hero as owner")]
def inventory_create_owned_item_debug_cmd(item_template : string;
                                          items_count : int = 1;
                                          @net_hero hero_eid : EntityId)
  for _i in range(0, items_count)
    createEntity(item_template) <| $(var init : ComponentsInitializer)
      set(init, "item__lastOwner", hero_eid)
      set(init, "item__ownerEid", hero_eid)

[console_processor]
def inventory_create_owned_item_debug_cmd_processor(args : array<string>;
                                                    collect : bool;
                                                    var hints : ConsoleProcessorHints)
  let cmd = "inventory.create_owned_item"
  if collect
    let inputs <- args[0] |> split(" ")
    if length(inputs) >= 2
      add_hints(fixed_array(CommandArgDesc(name = "template_name", hintType = CommandArgHintType.TemplateName),
                         CommandArgDesc(name = "items_count", hintType = CommandArgHintType.Default),
                         CommandArgDesc(name = "eid", hintType = CommandArgHintType.EntityId, defaultValue = "0")),
                cmd, inputs,  20,  2500.0, hints)
  return false


[console_processor]
def inventory_remove_weap_mod_debug_processor(args : array<string>;
                                              collect : bool;
                                              var hints : ConsoleProcessorHints)
  let cmd = "inventory.remove_weap_mod"
  if collect
    let inputs <- args[0] |> split(" ")
    if length(inputs) >= 2 && inputs[0] == cmd
      let weaponHolderEid = try_get_hero_cmd_param(inputs, 3)
      query(weaponHolderEid) <| $ [es] (human_weap__currentGunSlot : int;
                                        human_weap__gunEids : EidList;
                                        human_weap__gunMods : Array)
        var wishGunSlot = human_weap__currentGunSlot
        if length(inputs) > 2 && inputs[2] != ""
          var res : ConversionResult
          var ofs : int
          let input = int(inputs[2], res, ofs)
          if res == ConversionResult.ok && ofs == length(inputs[2])
            
            if input >= 0
              wishGunSlot = input
          else
            console_print("Failed to parse wish gun slot, using human_weap__currentGunSlot = {human_weap__currentGunSlot}")
        if wishGunSlot < 0 || wishGunSlot > length(human_weap__gunEids) - 1
          return
        let gunMods = get_ecs_EidList(human_weap__gunMods[wishGunSlot])
        if gunMods == null
          return
        for eid in *gunMods
          query(eid) <| $ [es] (gunAttachable__slotName : string)
            hints |> add_hint("{cmd} {gunAttachable__slotName}", 0, 2, "(mod: {getEntityTemplateName(eid)})")
  return false

[net_console_cmd(name="inventory.remove_weap_mod", hint="Remove a mod from weapon's slot")]
def inventory_remove_weap_mod_debug_cmd(slot : string;
                                        gun_slot_id : int = -1;
                                        @net_hero hero_eid : EntityId)

  query(hero_eid) <| $ [es] (human_weap__currentGunSlot : int;
                             human_weap__gunEids : EidList)
    let wishGunSlot = gun_slot_id >= 0 ? gun_slot_id : human_weap__currentGunSlot
    if wishGunSlot < 0 || wishGunSlot > length(human_weap__gunEids) - 1
      console_print("Invalid gun slot id {wishGunSlot}")
      return

    remove_item_from_weap_impl(hero_eid, wishGunSlot, slot, false )
