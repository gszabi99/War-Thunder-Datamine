module anim_phys_update_common shared
require ecs

def is_anim_phys_demand_update(visible : bool; skip_visibility_check : Tag const?) : bool
  return visible || skip_visibility_check != null

def is_anim_phys_update_frame(dt : float; updatable : bool; visible : bool; accum_dt : float; dt_threshold : float; skip_visibility_check : Tag const?) : bool
  return updatable && (is_anim_phys_demand_update(visible, skip_visibility_check) || (accum_dt + dt) > dt_threshold)
