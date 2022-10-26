module extinguish_system_common shared
require dm
require DmFire
require WTDamageModel
require IGroundModel


def has_extinguisher_mod(gm : IGroundModel?; count : int; count_max : int)
  return (gm != null && gm.extinguisher.isAvailable && count > 0) || count_max < 0


def is_extinguisher_available(gm : IGroundModel?; count : int; count_max : int; penalty_without_mod : bool)
  return penalty_without_mod || has_extinguisher_mod(gm, count, count_max)


def is_extinguisher_active(is_burning : bool; is_assisting : bool; extinguish_end_time : float) : bool
  return (is_burning || is_assisting) && extinguish_end_time > 0.0


def is_crew_busy(is_burning : bool; is_assisting : bool; crew_busy_time : float) : bool
  return (is_burning || is_assisting) && crew_busy_time > 0.0


def can_be_extinguished_with_extinguisher(fire_damage : FireDamageComponent&)
  for fire_data in fire_damage.data
    if fire_data.startTime > 0.0lf
      let fire_params = get_fire_params(fire_data.fireParamsId)
      if fire_params.extinguisherEffective
        return true
  return false

