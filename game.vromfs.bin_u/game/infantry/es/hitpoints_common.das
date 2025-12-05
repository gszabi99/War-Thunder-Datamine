module hitpoints_common shared public

require ecs

enum DamageType
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

def DamageType(i : int)
  if i < int(DamageType.DM_COUNT)
    return unsafe(reinterpret<DamageType>(i))
  return DamageType.DM_UNKNOWN

def add_damage_over_time_entry(damage : float;
                               hitpoints__dotBaseSpeed : float;
                               hitpoints__dotSpeedThreshold : float;
                               var hitpoints__dotDamage : FloatList&;
                               var hitpoints__totalDotAmount : float&)
  let maxLength = int(ceil(hitpoints__dotSpeedThreshold / hitpoints__dotBaseSpeed))

  if maxLength <= 0
    return
  elif maxLength == 1
    if empty(hitpoints__dotDamage)
      push(hitpoints__dotDamage, damage)
    else
      hitpoints__dotDamage[0] += damage
  elif length(hitpoints__dotDamage) >= maxLength
    
    
    
    hitpoints__dotDamage[0] += hitpoints__dotDamage[1]
    erase(hitpoints__dotDamage, 1)
    push(hitpoints__dotDamage, damage)
  else
    push(hitpoints__dotDamage, damage)

  hitpoints__totalDotAmount += damage


def decrease_damage_over_time_amount(var amount : float&;
                                     var hitpoints__dotDamage : FloatList&;
                                     var hitpoints__totalDotAmount : float&)
  var dmg = amount

  while !empty(hitpoints__dotDamage)
    hitpoints__dotDamage[0] -= dmg
    if hitpoints__dotDamage[0] > 0.0
      dmg = 0.0
      break
    dmg = -hitpoints__dotDamage[0]
    erase(hitpoints__dotDamage, 0)

  amount -= dmg
  hitpoints__totalDotAmount -= amount
  if empty(hitpoints__dotDamage)
    hitpoints__totalDotAmount = 0.0