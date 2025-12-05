require ecs
require sound_utils.modules.sound_player_common
require DngHuman
require soundSystem


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es, REQUIRE=watchedByPlr, REQUIRE_NOT=deadEntity)]
def human_weapon_change_sound__update(evt : Event;
                                      @shared_comp human_weapon_change_sound__paths : Object;
                                      var human_weapon_change_sound__weapEquipCurState : int&;
                                      sound_tags : Object;
                                      human_net_phys : HumanActor&;
                                      transform : float3x4;
                                      human_sound__prefix : string = "infantry/")
  assume sndState = human_weapon_change_sound__weapEquipCurState
  assume curState = human_net_phys.phys.currentState.weapEquipState.curState

  if sndState != int(curState)
    if curState == HUWeaponEquipState.EES_HOLSTERING && sound_banks_is_master_preset_loaded()
      sound_player_common::play_path("holstering", human_weapon_change_sound__paths, sound_tags, true, transform[3], true, human_sound__prefix)
    elif curState == HUWeaponEquipState.EES_EQUIPING && sound_banks_is_master_preset_loaded()
      sound_player_common::play_path("equiping", human_weapon_change_sound__paths, sound_tags, true, transform[3], true, human_sound__prefix)
    sndState = int(curState)
