options no_aot
require ecs
require ecs.ecs_template
require math
require strings
require DaWeapons
require DagorDebug3D
require DagorConsole
require DagorMath
require GeomNodeTree
require AnimV20
require BallisticsProps
require Ballistics
require DaWeaponProps
require PropsManager
require %appGame.infantry.es.net_console_macro


[ecs_template]
struct gun_sight_angle_debug_draw
  gunSightAngleDebug : Tag


def calc_sight_shoot_angle(animchar : AnimcharBaseComponent;
                           weapon_frontsight_node__nodeIdx : int;
                           weapon_rearsight_node__nodeIdx : int;
                           shoot_dir : float3) : float
  if weapon_frontsight_node__nodeIdx < 0 || weapon_rearsight_node__nodeIdx < 0
    return 0.0
  let frontPos = geomtree_getNodeWpos(*animchar.nodeTree, weapon_frontsight_node__nodeIdx)
  let rearPos = geomtree_getNodeWpos(*animchar.nodeTree, weapon_rearsight_node__nodeIdx)
  let sightDir = normalize(frontPos - rearPos)
  let cosA = clamp(dot(sightDir, shoot_dir), -1.0, 1.0)
  let angle = acos(cosA)
  let crossY = cross(shoot_dir, sightDir).y
  return crossY <= 0.0 ? angle : -angle


[console_cmd(name="gun.debug_sight_angle", hint="Toggle drawing sight line vs shoot direction")]
def gun_debug_sight_angle()
  var exists = false
  query() <| $ [es(REQUIRE=gunSightAngleDebug)] (eid : EntityId)
    destroyEntity(eid)
    exists = true
  if !exists
    createEntity("gun_sight_angle_debug_draw")
  console_print("gun.debug_sight_angle {exists ? "disabled" : "enabled"}")


[es(tag=(render, dev), no_order, REQUIRE=gunSightAngleDebug)]
def draw_gun_sight_angle(evt : UpdateStageInfoRenderDebug)
  query() <| $ [es(REQUIRE=hero)] (human_weap__currentGunEid : EntityId)
    query(human_weap__currentGunEid) <| $ [es] (weap__sightEid : EntityId;
                                                gun__shootNodeName : string)
      query(weap__sightEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                       weapon_frontsight_node__nodeIdx : int;
                                       weapon_rearsight_node__nodeIdx : int)
        if weapon_frontsight_node__nodeIdx < 0 || weapon_rearsight_node__nodeIdx < 0
          return

        let frontPos = geomtree_getNodeWpos(*animchar.nodeTree, weapon_frontsight_node__nodeIdx)
        let rearPos = geomtree_getNodeWpos(*animchar.nodeTree, weapon_rearsight_node__nodeIdx)
        let sightDir = normalize(frontPos - rearPos)

        
        let shootNodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, gun__shootNodeName)
        if shootNodeIdx < 0
          return
        var shootNodeTm : float3x4
        geomtree_getNodeWtmScalar(*animchar.nodeTree, shootNodeIdx, shootNodeTm)

        let lineLen = 4.0
        let barrelDir = -normalize(shootNodeTm[1])
        
        draw_debug_line_buffered(rearPos, rearPos + -normalize(shootNodeTm[0]) * lineLen, E3DCOLOR(0xFFFF0000), 1) 
        draw_debug_line_buffered(rearPos, rearPos + -normalize(shootNodeTm[1]) * lineLen, E3DCOLOR(0xFF00FF00), 1) 
        draw_debug_line_buffered(rearPos, rearPos + -normalize(shootNodeTm[2]) * lineLen, E3DCOLOR(0xFF0000FF), 1) 
        
        draw_debug_line_buffered(rearPos, rearPos + sightDir * lineLen, E3DCOLOR(0xFFFFFFFF), 1)

        let angleDeg = calc_sight_shoot_angle(animchar, weapon_frontsight_node__nodeIdx,
          weapon_rearsight_node__nodeIdx, barrelDir) * (180.0 / PI)
        let textPos = rearPos + sightDir * lineLen
        add_debug_text_mark(textPos, "sight angle: {format("%.3f", double(angleDeg))} deg", -1, 0.0, E3DCOLOR(0xFFFFFFFF))


[console_cmd(name="gun.calc_zeroing_correction", hint="<distance> Calculate zeroing angle correction for sight-shoot misalignment")]
def gun_calc_zeroing_correction(distance : float)
  if distance <= 0.0
    console_print("Distance must be positive")
    return
  query() <| $ [es(REQUIRE=hero)] (human_weap__currentGunEid : EntityId)
    query(human_weap__currentGunEid) <| $ [es] (gun__shell_prop_ids : PropsIdList;
                                                gun__shootNodeName : string;
                                                weap__sightEid : EntityId)
      if empty(gun__shell_prop_ids)
        console_print("No shell prop ids")
        return
      let shellId = gun__shell_prop_ids[0]

      
      var speed = 0.0
      shell_start_get_props(shellId) <| $(shellStartProps : ShellStartProps)
        speed = shellStartProps.speed
      if speed <= 0.0
        get_props_RocketProperties(shellId) <| $(rocketProps : RocketProperties)
          if rocketProps.rocketMotor.useStartSpeed
            speed = rocketProps.rocketMotor.startSpeed
      if speed <= 0.0
        console_print("Could not determine shell speed")
        return

      
      var zeroingAngle = 0.0
      var hasShellBallistics = false
      get_props_ShellBallisticsProperties(shellId) <| $(shellBallistics : ShellBallisticsProperties)
        hasShellBallistics = true
        var hasRocket = false
        get_props_RocketProperties(shellId) <| $(rocketProps : RocketProperties)
          hasRocket = true
          zeroingAngle = calc_zeroing_angle_rocket(distance, float(speed), shellBallistics, rocketProps)
        if !hasRocket
          zeroingAngle = calc_zeroing_angle(distance, float(speed), shellBallistics)
      if !hasShellBallistics
        console_print("No shell ballistics properties found")
        return

      
      var sightAngle = 0.0
      query(weap__sightEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                       weapon_frontsight_node__nodeIdx : int;
                                       weapon_rearsight_node__nodeIdx : int)
        let shootNodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, gun__shootNodeName)
        if shootNodeIdx >= 0
          var shootNodeTm : float3x4
          geomtree_getNodeWtmScalar(*animchar.nodeTree, shootNodeIdx, shootNodeTm)
          let barrelDir = -normalize(shootNodeTm[1])
          sightAngle = calc_sight_shoot_angle(animchar, weapon_frontsight_node__nodeIdx,
            weapon_rearsight_node__nodeIdx, barrelDir)

      let correction = zeroingAngle - sightAngle
      let toDeg = 180.0 / PI
      console_print("Distance: {format("%.1f", double(distance))}m, shell speed: {format("%.1f", double(speed))}m/s")
      console_print("Zeroing angle:     {format("%.3f", double(zeroingAngle * toDeg))} deg ({format("%.5f", double(zeroingAngle))} rad)")
      console_print("Sight-shoot angle: {format("%.3f", double(sightAngle * toDeg))} deg ({format("%.5f", double(sightAngle))} rad)")
      console_print("Correction needed: {format("%.3f", double(correction * toDeg))} deg ({format("%.5f", double(correction))} rad)")
