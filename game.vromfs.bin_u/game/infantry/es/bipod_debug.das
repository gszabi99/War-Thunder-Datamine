options no_aot
require ecs
require DngHuman
require DagorDebug3D
require DagorConsole
require math.base
require DagorMathUtils
require %appGame.infantry.es.hero_common
require %appGame.infantry.es.bipod_common

require strings
require EcsUtils
require DagorDataBlock



[console_cmd(name="bipod.debug")]
def bipod_debug()
  let hero = get_controlled_hero_eid()
  if has(hero, "bipodDebug")
    removeSubTemplate(hero, "bipod_debug")
  else
    addSubTemplate(hero, "bipod_debug")

def draw_point(pos : float3; color : E3DCOLOR; txt : string; radius : float = 0.05)
  draw_cached_debug_sphere(pos, radius, color, 24)
  add_debug_text_mark(pos, txt, -1, -0.5, color)

def draw_line(from, to, color)
  draw_cached_debug_line(from, to, color)

[es(tag=(dev, render), REQUIRE=(hero, bipodDebug), after=bipod_human_post_phys_act_es)]
def bipod_debug_es(info : UpdateStageInfoRenderDebug;
                   human_net_phys : HumanActor;
                   human_weap__currentGunEid : EntityId;
                   human_input__aimAngle : float2;
                   human__aimTm : float3x4;
                   bipod__enabled : bool;
                   bipod__anchorPos : float3;
                   bipod__anchorDir : float3;
                   bipod__anchorHeight : float;
                   bipod__anchorNormal : float3;
                   bipod__placeable : bool;
                   bipod__placePos : float3;
                   bipod__placeHeight : float;
                   bipod__placeNormal : float3;
                   bipod__solveBestType : int;
                   bipod__solveBestPos : float3;
                   bipod__solveBestHeight : float;
                   bipod__solveBestNormal : float3;
                   human_cam__calculatedOffset : DPoint3 const?;
                   human_cam__offsetMult : float = 1.0)
  begin_draw_cached_debug_lines(true, true, false)

  var tm : float3x4
  location_toTM(human_net_phys.phys.currentState.location, tm)

  let walkDir  = normalize(cross(cross(human_net_phys.phys.currentState.walkNormal, human__aimTm[0]), human_net_phys.phys.currentState.walkNormal))
  draw_line(tm[3], tm[3] + walkDir, E3DCOLOR(0xFFFF00FF))

  var prevTm : float3x4
  location_toTM(human_net_phys.phys.previousState.location, prevTm)

  let aimAngle = dir_to_angles(human_net_phys.phys.appliedCT.wishShootDir)

  var animGunTm : float3x4
  var calcGunTm : float3x4
  let hasAnimGunTm = get_gun_tm(human_weap__currentGunEid, animGunTm)
  calc_gun_tm(calcGunTm, human_net_phys, prevTm, aimAngle.y)
  if human_cam__calculatedOffset != null
    calcGunTm[3] += float3(*human_cam__calculatedOffset * human_cam__offsetMult)

  draw_point(calcGunTm[3], E3DCOLOR(0xFFFFFFFF), "gunTm")
  if hasAnimGunTm
    draw_point(animGunTm[3], E3DCOLOR(0xFF00FF00), "animGunTm")

  query(human_weap__currentGunEid) <| $ [es] (gun__bipodOffset : float3;
                                              @shared_comp gun__mountPoints : Array;
                                              gun__barrelTipOffset : float3;
                                              gun__barrelRadius : float)

    draw_point(calcGunTm * gun__barrelTipOffset, E3DCOLOR(0xFFFFFFFF), "gunTm barrelTip", gun__barrelRadius)
    if hasAnimGunTm
      draw_point(animGunTm * gun__barrelTipOffset, E3DCOLOR(0xFF00FF00), "animGunTm barrelTip", gun__barrelRadius)

    let aimDirX = angles_to_dir(human_input__aimAngle)
    let aimDirY = angles_to_dir(float2(human_input__aimAngle.x, human_input__aimAngle.y + HALF_PI))
    let aimDirZ = angles_to_dir(float2(human_input__aimAngle.x + HALF_PI, 0.0))
    draw_point(calcGunTm[3] + aimDirX * gun__barrelTipOffset.x + aimDirY * gun__barrelTipOffset.y + aimDirZ * gun__barrelTipOffset.z, E3DCOLOR(0xFFFF0000), "aim", gun__barrelRadius)

    for i in iter_range(gun__mountPoints)
      let obj = get_ecs_object(gun__mountPoints[i])
      var pttype = get_ecs_string(obj, "type")
      if pttype != null
        var offset = get_Point3(obj, "offset") ?? float3(0.0, 0.0, 0.0)
        var color = E3DCOLOR(0xFF00FFFF)
        var radius = BIPOD_TRACE_REST_RADIUS
        if string(*pttype) == "bipod"
          if i == 0 && gun__bipodOffset.x != 0.0
            if !(get_bool(obj, "forceOffset") ?? false)
              offset = gun__bipodOffset
          let ang = deg_to_rad(get_float(obj, "angle") ?? 0.0)
          let len = get_float(obj, "length") ?? 0.0
          let dy = cos(ang) * len
          let dz = sin(ang) * len
          let legL = offset + float3(0.0, -dy,  dz)
          let legR = offset + float3(0.0, -dy, -dz)

          let center1 = calcGunTm * offset
          draw_line(center1, calcGunTm * legL, E3DCOLOR(0xFFFF0000))
          draw_line(center1, calcGunTm * legR, E3DCOLOR(0xFF0000FF))
          draw_point(calcGunTm * legL, E3DCOLOR(0xFFFF0000), "gun legL", BIPOD_TRACE_LEG_RADIUS)
          draw_point(calcGunTm * legR, E3DCOLOR(0xFF0000FF), "gun legR", BIPOD_TRACE_LEG_RADIUS)
          if hasAnimGunTm
            let center2 = animGunTm * offset
            draw_line(center2, animGunTm * legL, E3DCOLOR(0xFFFF0000))
            draw_line(center2, animGunTm * legR, E3DCOLOR(0xFF0000FF))
            draw_point(animGunTm * legL, E3DCOLOR(0xFFFF0000), "anim legL", BIPOD_TRACE_LEG_RADIUS)
            draw_point(animGunTm * legR, E3DCOLOR(0xFF0000FF), "anim legR", BIPOD_TRACE_LEG_RADIUS)
          color = E3DCOLOR(0xFFFF0000)
          radius = BIPOD_TRACE_BASE_RADIUS

        draw_point(calcGunTm * offset, color, "gun offset", radius)
        if hasAnimGunTm
          draw_point(animGunTm * offset, E3DCOLOR(0xFF007700), "anim offset", radius)

  if bipod__enabled
    draw_point(bipod__anchorPos, E3DCOLOR(0xFFFF00FF), "anchorP")
    draw_point(bipod__anchorPos + float3(0.0, bipod__anchorHeight, 0.0), E3DCOLOR(0xFFFFFF00), "anchorP + h")
    draw_line(bipod__anchorPos, bipod__anchorPos + bipod__anchorDir, E3DCOLOR(0xFFFF00FF))
    draw_line(bipod__anchorPos, bipod__anchorPos + bipod__anchorNormal, E3DCOLOR(0xFF0000FF))
  elif bipod__placeable
    draw_point(bipod__placePos, E3DCOLOR(0xFF770077), "placeP")
    draw_point(bipod__placePos + float3(0.0, bipod__placeHeight, 0.0), E3DCOLOR(0xFF777700), "placeP + h")
    draw_line(bipod__placePos, bipod__placePos + bipod__placeNormal, E3DCOLOR(0xFF000077))
  elif bipod__solveBestType > 0
    draw_point(bipod__solveBestPos, E3DCOLOR(0xFFFF0000), "bestP")
    draw_point(bipod__solveBestPos + float3(0.0, bipod__solveBestHeight, 0.0), E3DCOLOR(0xFFFF0000), "bestP + h")
    draw_line(bipod__solveBestPos, bipod__solveBestPos + bipod__solveBestNormal, E3DCOLOR(0xFFFF0000))

  end_draw_cached_debug_lines()



[console_cmd(name="bipod.catalog")]
def bipod_catalog(detailed : bool = false)

  var profListGuns : array<string>
  using() <| $(var blk : DataBlock)
    if !datablock_load(blk, "../prog/gameBase/guns_list.blk")
      return
    let count = int(blk.paramCount)
    for i in range(count)
      let tmpl = datablock_get_param_name(blk, uint(i))
      push(profListGuns, slice(tmpl, 0, length(tmpl)))

  var inSceneNames : array<string>
  using() <| $(var blk : DataBlock)
    if !datablock_load(blk, "../prog/gameBase/gamedata/scenes/test_loc_weapons.blk")
      return
    let count = int(blk.blockCount)
    for i in range(count)
      datablock_get_block(blk, uint(i)) <| $(subblk)
        let listblk = subblk |> datablock_get_block_by_name("spawnItemList:array")
        if listblk != null
          let listCount = int(listblk.blockCount)
          for j in range(listCount)
            datablock_get_block(*listblk, uint(j)) <| $(itemblk)
              let tname = datablock_getStr(itemblk, "templ", "")
              let pos = find(tname, "gun_item+")
              if pos > 0
                let name = slice(tname, 0, pos + 3)
                var found = false
                for q in iter_range(inSceneNames)
                  if inSceneNames[q] == name
                    found = true
                    break
                if !found
                  push(inSceneNames, name)

  console_print("------------------------------------------------------------\n")

  var total = 0
  var pts0 = 0
  var pts1 = 0
  var pts2 = 0
  var pts3 = 0
  var ptsM = 0
  var ptsX = 0
  var ptsB = 0
  var ptsR = 0
  var ptsO = 0
  var nots = 0
  var gots = 0
  var notInScene : array<string>
  var nots2 = 0
  var gots2 = 0
  var notInList : array<string>

  getTemplateDB() |> find_templateDB() <| $(name; tmpl)
    if ends_with(name, "_gun")
      let gunblk = get_ecs_string(getTemplateComponent(tmpl, "gun__blk"))
      let itemtp = get_ecs_string(getTemplateComponent(tmpl, "item__template"))
      let turret = get_ecs_string(getTemplateComponent(tmpl, "turret__name"))
      let mortar = get_ecs_string(getTemplateComponent(tmpl, "mortar__targetTemplate"))
      let pistol = get_float(getTemplateComponent(tmpl, "gun__mass"))
      let flamet = get_float(getTemplateComponent(tmpl, "flamethrower__maxFlameLength"))
      if gunblk == null || turret != null || mortar != null || pistol != null || flamet != null || ends_with(name, "_radio_gun") || find(name, "building_tool") >= 0
        
        return false
      if name == "scr_300_gun"
        return false
      if itemtp == null
        
        return false

      ++total

      var found = false
      for i in iter_range(inSceneNames)
        if inSceneNames[i] == name
          found = true
          break
      if !found
        ++nots
        push(notInScene, string(name))
      else
        ++gots

      found = false
      for i in iter_range(profListGuns)
        if profListGuns[i] == name
          profListGuns |> erase(i)
          found = true
          break
      if !found
        ++nots2
        push(notInList, string(name))
      else
        ++gots2

      var got = false
      let eid = createEntitySync("{name}")
      query(eid) <| $ [es] (@shared_comp gun__mountPoints : Array)
        got = true

        let pts = length(gun__mountPoints)
        if pts == 0
          console_print("  Non-configured bipod gun template: {name}\n")
          ++pts0
        elif pts == 1
          ++pts1
        elif pts == 2
          ++pts2
        elif pts == 3
          ++pts3
        elif pts > 3
          ++ptsM

        var hasBipod = false
        var hasRests = false
        var hasOther = false
        for i in iter_range(gun__mountPoints)
          let obj = get_ecs_object(gun__mountPoints[i])
          let pttype = get_ecs_string(obj, "type")
          if pttype != null
            if string(*pttype) == "bipod"
              hasBipod = true
            elif string(*pttype) == "rest"
              hasRests = true
            else
              hasOther = true
        if hasBipod
          ++ptsB
        if hasRests
          ++ptsR
        if hasOther
          ++ptsO

        if hasBipod
          console_print("  Weapon #{total}: /\\ {name}\n")
        else
          console_print("  Weapon #{total}:    {name}\n")

        
        
        
        

      destroyEntity(eid)
      if !got
        ++ptsX
        console_print("  ------------    {name}\n")
    return false

  console_print("------------------------------------------------------------\n")
  console_print("  Total bipodable  {total}\n")
  console_print("  With no points   {pts0}\n")
  console_print("  With 1 point     {pts1}\n")
  console_print("  With 2 points    {pts2}\n")
  console_print("  With 3 points    {pts3}\n")
  console_print("  With points > 3  {ptsM}\n")
  console_print("  Got bipods       {ptsB}\n")
  console_print("  Got rest points  {ptsR}\n")
  console_print("  Got other points {ptsO}\n")
  console_print("  No component     {ptsX}\n")

  console_print("------------------------------------------------------------\n")
  console_print("Also for gameBase/guns_list.blk (from profileServer das files):\n")
  console_print("  More there: {length(profListGuns)}\n")
  if detailed
    for i in iter_range(profListGuns)
      let tmpl = getTemplateByName(profListGuns[i])
      if tmpl == null
        console_print("    INVALID! {profListGuns[i]}\n")
        continue
      let gunblk = get_ecs_string(getTemplateComponent(*tmpl, "gun__blk"))
      let itemtp = get_ecs_string(getTemplateComponent(*tmpl, "item__template"))
      let turret = get_ecs_string(getTemplateComponent(*tmpl, "turret__name"))
      let mortar = get_ecs_string(getTemplateComponent(*tmpl, "mortar__targetTemplate"))
      let pistol = get_float(getTemplateComponent(*tmpl, "gun__mass"))
      let flamet = get_float(getTemplateComponent(*tmpl, "flamethrower__maxFlameLength"))
      if gunblk == null
        console_print("    (gunblk) {profListGuns[i]}\n")
      elif itemtp == null
        console_print("    (noitem) {profListGuns[i]}\n")
      elif turret != null
        console_print("    (turret) {profListGuns[i]}\n")
      elif mortar != null
        console_print("    (mortar) {profListGuns[i]}\n")
      elif pistol != null
        console_print("    (pistol) {profListGuns[i]}\n")
      elif flamet != null
        console_print("    (flamet) {profListGuns[i]}\n")
      else
        console_print("    MISSING! {profListGuns[i]}\n")
  console_print("  Bipodable:  {gots2}/{total}\n")
  console_print("  Not there:  {nots2}/{total}\n")
  if detailed
    for i in iter_range(notInList)
      console_print("    {notInList[i]}\n")
  elif nots > 0
    console_print("  (add 'true' in console command for lists)\n")

  console_print("------------------------------------------------------------\n")
  console_print("Also for modern_conflict/scenes/test_loc_weapons.blk:\n")
  console_print("  Gun items: {length(inSceneNames)}\n")
  console_print("  Bipodable: {gots}/{total}\n")
  console_print("  Missing:   {nots}/{total}\n")
  if detailed
    for i in iter_range(notInScene)
      console_print("    {notInScene[i]}\n")
  elif nots > 0
    console_print("  (add 'true' in console command for list of missing templates)\n")
