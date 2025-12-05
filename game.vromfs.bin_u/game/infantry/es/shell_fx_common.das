module shell_fx_common shared

require ecs
require ecs.safe
require DagorSystem
require PhysMat
require Dacoll


def get_surface_material_name(pos : float3; dir : float3; fx_trace_length : float; var riex_handle : riex_handle_t&)
  var matId = 0
  var t = fx_trace_length
  var riDesc = RendInstDesc()
  var norm = float3()
  traceray_normalized(pos, dir, t, matId, norm, ETF_ALL, riDesc, -1)
  riex_handle = riDesc.riExtraHandle
  return get_material_name(get_material(matId))

def get_floor_material_name(pos : float3; fx_trace_length : float; var riex_handle : riex_handle_t&)
  return get_surface_material_name(pos, float3(0, -1, 0), fx_trace_length, riex_handle)

def private get_fx_name(mat_name : string;
                        fx_default : string;
                        fx_info : Object const?)
  let obj = fx_info?[mat_name] ?as Object
  return obj?.fx ?? fx_default

def get_adjusted_pos_for_effect(pos : float3; var is_under_water : bool&)
  var waterLevel = 0.0
  is_under_water = traceht_water(pos, waterLevel) && pos.y < waterLevel

  return float3(pos.x, is_under_water ? waterLevel : pos.y, pos.z)
