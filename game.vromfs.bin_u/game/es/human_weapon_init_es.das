require ecs
require HumanPhys

[es(tag=server, on_appear, on_event=CmdReinitWeapons, before=(human_weap_reinit_guns_es, server_init_gun_es, human_weap_created_server_es), REQUIRE=human_weap)]
def human_weapon_init_es(evt : Event;
                         human_weap__weapInfo : Array;
                         var human_weap__gunModsBySlot : Array&)
  let gunsCount = min(int(HUWeaponSlots EWS_NUM), length(human_weap__weapInfo))
  for i in range(gunsCount)
    let gunMods = get_ecs_object(human_weap__weapInfo[i]) |> get_ecs_object("gunMods")
    if gunMods != null
      set(human_weap__gunModsBySlot[i], *gunMods)

