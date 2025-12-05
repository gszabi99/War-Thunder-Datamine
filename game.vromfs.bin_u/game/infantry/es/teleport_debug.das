options no_aot
require ecs
require DagorMath
require DngHuman
require DagorConsole
require DagorSystem
require %appGame.infantry.es.hero_common
require %appGame.infantry.es.net_console_macro


def private teleport_eid_to(eid : EntityId; pos : float3; use_camera_pos : bool = false)
  var targetTm : float3x4
  let heroTm = get_TMatrix(eid, "transform")
  let hasCamera = find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      identity(targetTm)
      targetTm[0] = normalize(cross(float3(0.f, -1.f, 0.f), transform[0]))
      targetTm[2] = normalize(cross(transform[2], float3(0.f, 1.f, 0.f)))
      targetTm[3] = use_camera_pos ? transform[3] : pos
    return camera__active
  if !hasCamera && heroTm != null
    targetTm = *heroTm
    if !use_camera_pos
      targetTm[3] = pos
  elif !hasCamera
    logerr("Failed to get any transform")
    return
  query(eid) <| $ [es] (var human_net_phys : HumanActor&)
    human_net_phys.phys.currentState.location.P = DPoint3(targetTm[3])
  

[net_console_cmd(name="phys.teleport", hint="[x,y,z] [hero eid] Uses camera if no coords are provided")]
def console_phys_teleport(x, y, z, w : float = 0.0; @net_hero hero_eid : EntityId)
  if y == 0.0 && z == 0.0 && w == 0.0
    let eid = x == 0.0 ? hero_eid : EntityId(uint(x))
    teleport_eid_to(eid, float3(0, 0, 0), true)
  else
    let eid = w == 0.0 ? hero_eid : EntityId(uint(w))
    teleport_eid_to(eid, float3(x, y, z), false)

[console_cmd(name="phys.teleport_to_camera")]
def console_phys_teleport_to_camera()
  let targetEid = get_controlled_hero_eid()
  if targetEid == INVALID_ENTITY_ID
    return
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      if is_server()
        teleport_eid_to(targetEid, transform[3], false)
      else
        exec_server_cmd("phys.teleport {transform[3].x} {transform[3].y} {transform[3].z} {targetEid}")
    return camera__active

[console_cmd(name="phys.position")]
def console_phys_position()
  let targetEid = get_controlled_hero_eid()
  query(targetEid) <| $ [es] (transform : float3x4)
    let s = "{transform[3]}"
    console_print("Phys pos: {s}")


[console_cmd(name="squad.teleport_to_camera")]
def console_squad_teleport_to_camera()
  let targetEid = get_controlled_hero_eid()
  query(targetEid) <| $ [es] (squad_member__squad : EntityId)
    find_query() <| $ [es] (camera__active : bool; transform : float3x4)
      if camera__active
        query(squad_member__squad) <| $ [es] (squad__allMembers : EidList)
          for memberEid in squad__allMembers
            teleport_eid_to(memberEid, transform[3])
      return camera__active

[net_console_cmd(name="squad.teleport")]
def console_squad_teleport(x, y, z : float; @net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (squad_member__squad : EntityId)
    query(squad_member__squad) <| $ [es] (squad__allMembers : EidList)
      for memberEid in squad__allMembers
        teleport_eid_to(memberEid, float3(x, y, z))
