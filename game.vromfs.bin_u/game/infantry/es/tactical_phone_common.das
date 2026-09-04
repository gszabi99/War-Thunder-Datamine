module tactical_phone_common shared
require ecs.enum_macro
require ecs
require DngHuman
require app
require %appGame.infantry.es.human_weap_common

[export_enum]
enum TacticalPhoneMode
  TPM_NONE
  TPM_MAP
  TPM_DRONE
  TPM_VIDEO_SHARING

def take_tactical_phone(tactical_phone__eid : EntityId;
                        human__eid : EntityId)
  query(human__eid) <| $ [es] (var human_net_phys : HumanActor&;
                               var human_input__lastWeaponChangeInput : float&)
    assume ct = human_net_phys.phys.producedCT
    set_weapon_slot(get_sync_time(), tactical_phone__eid, HUWeaponSlots.EWS_SPECIAL, ct, human_input__lastWeaponChangeInput)
