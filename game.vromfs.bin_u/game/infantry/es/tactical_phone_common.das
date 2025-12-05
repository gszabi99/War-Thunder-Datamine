module tactical_phone_common shared
require ecs.enum_macro
require ecs
require DngHuman
require %appGame.infantry.es.multiple_guns_slot_common

[export_enum]
enum TacticalPhoneMode
  TPM_NONE
  TPM_MAP
  TPM_DRONE
  TPM_VIDEO_SHARING

def take_tactical_phone(tactical_phone__eid : EntityId;
                        human__eid : EntityId)
  
  
  
  
  
  
  try_request_multiple_guns_slot_equip_gun(human__eid, tactical_phone__eid, int(HUWeaponSlots.EWS_SPECIAL))
