options no_aot
require ecs
require ecs.ecs_template
require math.base
require strings
require DagorConsole
require DagorDebug3D
require DagorStdGuiRender
require Dacoll
require RendInst
require PhysMat
require PropsManager
require DaWeaponProps
require Weapon
require WTDamageModel


[ecs_template]
struct penetration_debug_draw
  penetration_debug__maxDist : float = 50.0


[console_cmd(name="infantry.penetration_debug", hint="<dist 0=disable, default 50m>")]
def penetration_debug_cmd(dist = 50.0)
  let tmpl = "penetration_debug_draw"
  let exists = find_query() <| $ [es] (eid : EntityId; var penetration_debug__maxDist : float&)
    if dist <= 0.0 || penetration_debug__maxDist == dist
      destroyEntity(eid)
    else
      penetration_debug__maxDist = dist
    return true

  if !exists && dist > 0.0
    createEntity(tmpl) <| $(init)
      init |> set("penetration_debug__maxDist", dist)


[es(tag=(render, dev), no_order)]
def penetration_debug_draw_es(evt : UpdateStageInfoRenderDebug;
                              penetration_debug__maxDist : float)
  var camPos : float3
  var camDir : float3
  var camValid = false

  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false
    camDir = transform[2]
    camPos = transform[3]
    camValid = true
    return true
  if !camValid
    return

  var len = penetration_debug__maxDist
  var norm : float3
  var matId = PHYSMAT_INVALID
  var riDesc = RendInstDesc()
  let hit = traceray_normalized(camPos, camDir, len, matId, norm, ETF_ALL, riDesc, -1)
  if !hit
    return

  let hitPos = camPos + camDir * len
  let scrSize = StdGuiRender_screen_size()
  let scrX = scrSize.x * 0.20
  let scrY = scrSize.y * 0.30
  draw_debug_line_buffered(camPos, hitPos, E3DCOLOR(0xFF00FF00), 10)

  begin_draw_cached_debug_lines(false, false, false)

  if !riDesc.isValid
    draw_debug_line_buffered(camPos, hitPos, E3DCOLOR(0xFFFFFFFF), 1)
    add_debug_text_mark_screen(scrX, scrY, "{fmt(":.2f", len)}m  not a rendinst", -1, 0.0, E3DCOLOR(0xFFFFFFFF))
    end_draw_cached_debug_lines()
    return

  
  
  
  let resName = "{getRIGenResName(riDesc)}"
  var ciHp = 0.0
  var ciInitialHp = 0.0
  var hasGun = false
  var damageId = -1
  var pred = RiHitPrediction()
  using() <| $(var ci : CollisionInfo)
    getRiGenDestrInfo(riDesc, ci)
    ciHp = ci.hp
    ciInitialHp = ci.initialHp

    find_query() <| $ [es(REQUIRE=hero)] (human_weap__currentGunEid : EntityId)
      if human_weap__currentGunEid == INVALID_ENTITY_ID
        return false
      query(human_weap__currentGunEid) <| $ [es(REQUIRE=gun)] (gun__curShellId : PropsId)
        if !gun__curShellId.valid
          return
        damageId = gun__curShellId.spacked
        shell_start_get_props(gun__curShellId) <| $(shellStartProps : ShellStartProps)
          pred = predict_ri_hit(gun__curShellId, ci, matId, camPos, camDir, len, shellStartProps.speed)
          hasGun = true
      return true

  var color = E3DCOLOR(0xFFAAAAAA)
  var verdictText = "(no gun)"
  if hasGun
    if pred.impactResult == int(ImpactResult.NONE)
      verdictText = "no data"
      color = E3DCOLOR(0xFFAAAAAA)
    elif pred.impactResult == int(ImpactResult.STOP)
      if pred.destroys
        verdictText = "STOPPED + DESTROYS"
        color = E3DCOLOR(0xFF00FF00)
      elif pred.damage <= 0.0 && pred.damageThreshold > 0.0
        verdictText = "STOPPED, NO DAMAGE"
        color = E3DCOLOR(0xFFFF4040)
      else
        verdictText = "STOPPED"
        color = E3DCOLOR(0xFFFF4040)
    else 
      if pred.destroys
        verdictText = "PENETRATE + DESTROYS"
        color = E3DCOLOR(0xFF00FF00)
      elif pred.damage <= 0.0 && pred.damageThreshold > 0.0
        verdictText = "PENETRATE, no RI damage"
        color = E3DCOLOR(0xFFFFFF00)
      else
        verdictText = "PENETRATE"
        color = E3DCOLOR(0xFFFFFF00)

  let lineDelta = 2.0
  var curLine = 0.0
  var wallsInfo = ""
  if pred.wallCount > 1
    if pred.wallStoppedAt > 0
      wallsInfo = "  walls={pred.wallCount} (stop #{pred.wallStoppedAt})"
    else
      wallsInfo = "  walls={pred.wallCount}"
  add_debug_text_mark_screen(scrX, scrY,
    "{verdictText}  pen={fmt(":.3f", pred.penetration)}mm  armor={fmt(":.3f", pred.armorComplex)}mm{wallsInfo}",
    -1, curLine, color)
  curLine += lineDelta
  var hpInfo = "hp=n/a"
  if ciInitialHp > 0.0
    let dmgDetail = pred.explosionDamage > 0.0 ? "dmg={fmt(":.3f", pred.damage)} (kin={fmt(":.3f", pred.kineticDamage)}+expl={fmt(":.3f", pred.explosionDamage)})" : "dmg={fmt(":.3f", pred.damage)}"
    hpInfo = "hp={fmt(":.3f", ciHp)}/{fmt(":.3f", ciInitialHp)}  {dmgDetail}"
  elif pred.hp > 0.0
    let dmgDetail2 = pred.explosionDamage > 0.0 ? "dmg={fmt(":.3f", pred.damage)} (kin={fmt(":.3f", pred.kineticDamage)}+expl={fmt(":.3f", pred.explosionDamage)})" : "dmg={fmt(":.3f", pred.damage)}"
    hpInfo = "dm hp={fmt(":.3f", pred.hp)}  {dmgDetail2}"
  add_debug_text_mark_screen(scrX, scrY, hpInfo, -1, curLine, E3DCOLOR(0xFFFFFFFF))
  curLine += lineDelta
  let belowThreshold = pred.damageThreshold > 0.0 && pred.kineticDamage + pred.explosionDamage < pred.damageThreshold
  let thresholdColor = belowThreshold ? E3DCOLOR(0xFFFF4040) : E3DCOLOR(0xFFCCCCCC)
  let thresholdNote = belowThreshold ? "  (damage ignored)" : ""
  add_debug_text_mark_screen(scrX, scrY,
    "damageThreshold={fmt(":.3f", pred.damageThreshold)}{thresholdNote}",
    -1, curLine, thresholdColor)
  curLine += lineDelta
  add_debug_text_mark_screen(scrX, scrY,
    "{resName}  d={fmt(":.3f", len)}m  shell #{damageId}",
    -1, curLine, E3DCOLOR(0xFFCCCCCC))
  curLine += lineDelta
  if !pred.stopsBullets
    add_debug_text_mark_screen(scrX, scrY, "(does not stop bullets)", -1, curLine, E3DCOLOR(0xFFAAAAFF))

  end_draw_cached_debug_lines()
