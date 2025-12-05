enum HitResult {  
  HIT_RES_NONE = 0
  HIT_RES_NORMAL = 1
  HIT_RES_DOWNED = 2
  HIT_RES_KILLED = 3
}

const HEAL_RES_COMMON = "actHealCommon"
const HEAL_RES_REVIVE = "actHealRevive"
const ATTACK_RES = "actAttack"

enum SquadBehaviourEnum {  
  ESB_AGGRESSIVE = 0
  ESB_PASSIVE = 1
}

enum SquadFormationSpreadEnum {  
  ESFN_CLOSEST = 0
  ESFN_STANDARD = 1
  ESFN_WIDE = 2
}

enum AiActionEnum { 
  AI_ACTION_UNKNOWN = 0,
  AI_ACTION_STAND = 1,
  AI_ACTION_HEAL = 2,
  AI_ACTION_HIDE = 3,
  
  AI_ACTION_MOVE = 8,
  
  AI_ACTION_ATTACK = 12,
  AI_ACTION_IN_COVER = 13,
  AI_ACTION_RELOADING = 14,
  AI_ACTION_DOWNED = 15
}

enum DamageType { 
  DM_UNKNOWN
  DM_PROJECTILE
  DM_MELEE
  DM_EXPLOSION
  DM_ZONE
  DM_COLLISION
  DM_HOLD_BREATH
  DM_FIRE
  DM_DISCONNECTED
  DM_BACKSTAB
  DM_BARBWIRE
  DM_GAS
  DM_BLEEDING
  DM_COUNT
}

return {
  HitResult
  SquadBehaviourEnum
  SquadFormationSpreadEnum
  HEAL_RES_COMMON
  HEAL_RES_REVIVE
  ATTACK_RES
  AiActionEnum
  DamageType
}