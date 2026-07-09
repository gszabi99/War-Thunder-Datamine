options no_aot
require ecs
require ecs.safe
require ecs.ecs_template
require DagorMath
require DagorDebug3D
require DagorConsole
require Grid
require RendInst
require DagorDataBlock
require math.base
require app
require %appGame.infantry.es.net_console_macro


def console_print_debug(msg : string)
  console_print(msg)
  print(msg)


[console_cmd(name="doors.list_no_destr")]
def list_no_destr_doors_cmd(with_positions : bool = false)
  var infantryDmgRIs : table<string>
  datablock_load_cached("config/_rendinst_infantry_dmg.blk") <| $(dmgBlk : DataBlock)
    for i in 0u..dmgBlk.blockCount
      let child = dmgBlk |> datablock_get_block(i)
      if child != null
        insert(infantryDmgRIs, child.blockName)

  if empty(infantryDmgRIs)
    console_print_debug("Failed to load config/_rendinst_infantry_dmg.blk or it is empty")
    return

  var doorRiNames : table<string>
  var doorRiInstances : array<string>

  query() <| $ [es(REQUIRE=isDoor)] (ri_extra : RiExtraComponent; transform : float3x4)
    if !ri_extra.valid
      return
    let riType = handle_to_ri_type(ri_extra.handle)
    let riName = riex_getRIGenExtraName(riType)
    if riName == ""
      return
    if !key_exists(infantryDmgRIs, riName)
      insert(doorRiNames, riName)
      if with_positions
        let pos = transform[3]
        push(doorRiInstances, "{riName}  ({pos.x:.1f}, {pos.y:.1f}, {pos.z:.1f})")

  var sortedNames : array<string>
  for name in keys(doorRiNames)
    push(sortedNames, name)
  sort(sortedNames)
  sort(doorRiInstances)

  console_print_debug("Doors WITHOUT destruction ({length(sortedNames)} unique):")
  if with_positions
    for entry in doorRiInstances
      console_print_debug("  - {entry}")
  else
    for name in sortedNames
      console_print_debug("  - {name}")
  shrink_heap_memory()


def private kick_doors_at(center : float3; radius : float; impulse : float; is_server : bool)
  var doorEids : array<EntityId>
  for_each_entity_in_grid(ecs_hash("doors"), BSphere3(center, radius), GridEntCheck.POS) <| $(door_eid : EntityId)
    doorEids |> push(door_eid)

  var kicked = 0
  var newlyActivated = 0
  for door_eid in doorEids
    query(door_eid) <| $ [es] (door_operations__openedAngle : float;
                               door_operations__closedAngle : float;
                               var rendinst_axis_rotation__curAngle : float&;
                               rotating_rendinst_simple_phys__processingTemplate : string;
                               var rotating_rendinst_simple_phys__angularVelocity : float?)
      let openDir = door_operations__openedAngle > door_operations__closedAngle ? 1.0 : -1.0
      let signedImpulse = openDir * abs(impulse)
      if rotating_rendinst_simple_phys__angularVelocity != null
        *rotating_rendinst_simple_phys__angularVelocity += signedImpulse
      else
        
        
        
        
        if abs(rendinst_axis_rotation__curAngle - door_operations__closedAngle) < 0.5
          rendinst_axis_rotation__curAngle = door_operations__closedAngle + openDir * 0.5
        addSubTemplate(door_eid, rotating_rendinst_simple_phys__processingTemplate) <| $(var init : ComponentsInitializer)
          init |> set("rotating_rendinst_simple_phys__angularVelocity", signedImpulse)
        newlyActivated++
      kicked++

  let side = is_server ? "server" : "client"
  console_print_debug("doors.kick[{side}]: kicked {kicked} (newly_active={newlyActivated}) at ({center.x}, {center.y}, {center.z}) r={radius} imp={impulse}")


[console_cmd(name="doors.kick", hint="<radius> <impulse> Open closed doors in radius and apply angular impulse on both client and server (testing door replication traffic)")]
def door_kick_debug_cmd(radius : float = 10.0; impulse : float = 100.0)
  let hero_eid = get_controlled_hero_eid()
  var center : float3
  var heroFound = false
  query(hero_eid) <| $ [es] (transform : float3x4)
    center = transform[3]
    heroFound = true
  if !heroFound
    console_print("doors.kick: hero {hero_eid} has no transform")
    return

  kick_doors_at(center, radius, impulse, is_server())

  if !is_server()
    exec_server_cmd("doors.kick_at {center.x} {center.y} {center.z} {radius} {impulse}")


[net_console_cmd(name="doors.kick_at", hint="<cx> <cy> <cz> <radius> <impulse> Kick doors at world pos (server-side helper for doors.kick)")]
def door_kick_at_debug_cmd(cx, cy, cz, radius : float; impulse : float = 100.0)
  kick_doors_at(float3(cx, cy, cz), radius, impulse, is_server())


[ecs_template]
struct door_draw_server_angle_debug
  door_draw_server_angle_debug__lineLength : float = 1.0


[console_cmd(name="doors.draw_server_angle", hint="<enable 0|1> [length=1.0] Toggle drawing of door server angle (magenta) vs current angle (cyan)")]
def door_draw_server_angle_cmd(enable : bool = true; line_length : float = 1.0)
  let tmpl = "door_draw_server_angle_debug"
  let exists = find_query() <| $ [es] (eid : EntityId; var door_draw_server_angle_debug__lineLength : float&)
    if !enable
      destroyEntity(eid)
    else
      door_draw_server_angle_debug__lineLength = line_length
    return true

  if !exists && enable
    createEntity(tmpl) <| $(init)
      init |> set("door_draw_server_angle_debug__lineLength", line_length)


[es(tag=(render, dev), no_order, REQUIRE=door_draw_server_angle_debug__lineLength)]
def door_draw_server_angle_debug_es(evt : UpdateStageInfoRenderDebug;
                                    door_draw_server_angle_debug__lineLength : float)
  let lineLen = door_draw_server_angle_debug__lineLength
  let serverCol = E3DCOLOR(0xFFFF00FF)
  let curCol = E3DCOLOR(0xFF00FFFF)
  query() <| $ [es] (door_operations__serverTargetAngle : float;
                     rendinst_axis_rotation__curAngle : float;
                     initialTransform : float3x4;
                     rendinst_axis_rotation__axis : float3)
    let hingePos = initialTransform[3]

    var serverRotTm : float3x4
    make_tm(rendinst_axis_rotation__axis, deg_to_rad(door_operations__serverTargetAngle), serverRotTm)
    let serverTm = initialTransform * serverRotTm
    let serverDir = normalize(serverTm[0])
    draw_debug_line_buffered(hingePos, hingePos + serverDir * lineLen, serverCol, 1)

    var curRotTm : float3x4
    make_tm(rendinst_axis_rotation__axis, deg_to_rad(rendinst_axis_rotation__curAngle), curRotTm)
    let curTm = initialTransform * curRotTm
    let curDir = normalize(curTm[0])
    draw_debug_line_buffered(hingePos, hingePos + curDir * lineLen, curCol, 1)
