require ecs
require app
require inventory
require WeapHelpers
require PropsManager
require human_net_speech.modules.human_net_speech_request_common
require strings


def get_ammo_holders_shells(gun_eid : EntityId;
                            item_container : EidList const?;
                            var holders : int&;
                            var shells : int&)
  holders = 0
  shells = 0

  if item_container != null
    query(gun_eid) <| $ [es] (gun__wishAmmoItemType : int;
                              gun__ammoHolderIds : IntList;
                              gun__shell_prop_ids : PropsIdList)

      for itemEid in *item_container
        query(itemEid) <| $ [es] (shell_props : PropsId const?;
                                  item__id : int = INVALID_ITEM_ID;
                                  ammo_holder__id : int const?;
                                  ammo_holder__ammoCount : int const?)

          if item__id == gun__wishAmmoItemType || INVALID_ITEM_ID == gun__wishAmmoItemType
            if ammo_holder__id != null && ammo_holder__ammoCount != null && is_ammo_for_gun(*ammo_holder__id, gun__ammoHolderIds)
              ++holders
            elif shell_props != null && is_shell_for_gun(*shell_props, gun__shell_prop_ids)
              ++shells


[es(tag=server, on_event=ParallelUpdateFrameDelayed)]
def low_ammo_human_net_speech(evt : Event;
                              eid : EntityId;

                              human_weap__reloadAtTime : float;
                              human_weap__isReloading : bool;

                              var low_ammo_human_net_speech__shouldSpeak : bool&;
                              var low_ammo_human_net_speech__holders : int&;
                              var low_ammo_human_net_speech__shells : int&;

                              low_ammo_human_net_speech__oneMagazineLeftPhrase : string;
                              low_ammo_human_net_speech__noShellsLeftPhrase : string;

                              human_weap__currentGunEid : EntityId;
                              itemContainer : EidList const?)

  if human_weap__isReloading || get_sync_time() < human_weap__reloadAtTime
    if !low_ammo_human_net_speech__shouldSpeak
      get_ammo_holders_shells(human_weap__currentGunEid, itemContainer, low_ammo_human_net_speech__holders, low_ammo_human_net_speech__shells)
    low_ammo_human_net_speech__shouldSpeak = true

  elif low_ammo_human_net_speech__shouldSpeak
    low_ammo_human_net_speech__shouldSpeak = false

    var holders = 0
    var shells = 0

    get_ammo_holders_shells(human_weap__currentGunEid, itemContainer, holders, shells)

    if holders == 1 && low_ammo_human_net_speech__holders > 1 && !empty(low_ammo_human_net_speech__oneMagazineLeftPhrase)
      request_net_speech(eid, low_ammo_human_net_speech__oneMagazineLeftPhrase)

    elif shells == 0 && low_ammo_human_net_speech__shells > 0 && !empty(low_ammo_human_net_speech__noShellsLeftPhrase)
      request_net_speech(eid, low_ammo_human_net_speech__noShellsLeftPhrase)

    low_ammo_human_net_speech__holders = holders
    low_ammo_human_net_speech__shells = shells


[es(tag=server, on_appear, track=human_weap__currentGunEid, REQUIRE=human_weap__currentGunEid)]
def low_ammo_human_net_speech_track_cur_gun(evt : Event;
                                            var low_ammo_human_net_speech__holders : int&;
                                            var low_ammo_human_net_speech__shells : int&;
                                            var low_ammo_human_net_speech__shouldSpeak : bool&)
  low_ammo_human_net_speech__holders = 0
  low_ammo_human_net_speech__shells = 0
  low_ammo_human_net_speech__shouldSpeak = false
