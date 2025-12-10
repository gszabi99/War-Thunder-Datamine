require ecs
require ecs.safe
require ecs.extra_set
require %game.unit.unit_events
require DagorDataBlock
require Unit
require Mission
require DagorMath
require math
require math.base
require strings
require Weapon
require WTDamageModel
require WTHangar
require level
require %appGame.wt_events
require GuiOptions
require WTBallistics

struct ShellParam
  name : string
  bulletName : string
  bulletType : string
  prio : int
  mass : float
  caliber : float
  len : float
  blkName : string
  presetName : string
  customCart : string
  hideNodes : array<string>
  roll : float
  offset : float3
  scale : float = 1.
  vertical : bool = false
  animChar : string
  penetration : float = 0.

let maxCnt = 14
let maxBulletCnt = 8

let minimalCaliber = 0.03
let maxShotFreq = 3.

def get_prio_by_trigger(trigger_no : int)
  if trigger_no == int(WeaponTriggerType.AGM_TRIGGER)
    return 5
  if trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)
    return 4
  if trigger_no == int(WeaponTriggerType.BOMBS_TRIGGER)
    return 3
  if trigger_no == int(WeaponTriggerType.ROCKETS_TRIGGER)
    return 2
  if trigger_no == int(WeaponTriggerType.TORPEDOES_TRIGGER)
    return 1
  return 0

def get_aam_priotity(rocket_blk : DataBlock&)
  let guidanceType = rocket_blk |> datablock_getStr("guidanceType", "")
  if guidanceType == "radar"
    let guidanceBlk = rocket_blk |> datablock_get_block_by_name("guidance")
    if guidanceBlk != null
      let seekerBlk = *guidanceBlk |> datablock_get_block_by_name("radarSeeker")
      if seekerBlk != null
        let active = *seekerBlk |> datablock_getBool("active", false)
        return active ? 3 : 2
  return 1

def check_same_shell(var list : array<ShellParam>&; check_name : string; bullet_name : string = "")
  return find_index_if(list) <| $(p) : bool
    if bullet_name != "" && p.bulletName != ""
      return p.bulletName == bullet_name;
    return p.name == check_name;

def check_broken_cap(blk : DataBlock&; var hide_nodes : array<string>&)
  let brCapBlk = blk |> datablock_get_block_by_name("brokenCaps")
  if brCapBlk != null
    for bc_i in 0u..brCapBlk.paramCount
      hide_nodes.push(clone_string(*brCapBlk |> datablock_getStr(int(bc_i))))

def check_container(container_blk : DataBlock&; var weapon_blk_name : string&; var ground_weapon : array<ShellParam>&; trigger_no : int; preset_name : string)
  let childBlkName = container_blk |> datablock_getStr("blk", "")
  weapon_blk_name = clone_string(childBlkName)
  if trigger_no == int(WeaponTriggerType.ROCKETS_TRIGGER) || trigger_no == int(WeaponTriggerType.AGM_TRIGGER)
    var containerMesh = container_blk |> datablock_getStr("mesh", "")
    if childBlkName != ""
      var res = false
      using() <| $(var nextBlk : DataBlock)
        datablock_load(nextBlk, clone_string(childBlkName))
        if nextBlk |> datablock_getBool("container", false)
          res = check_container(nextBlk, weapon_blk_name, ground_weapon, trigger_no, preset_name)
        else
          if containerMesh != "" && container_blk |> datablock_param_exists("dragCx", -1) && !container_blk |> datablock_getBool("dontDemonstrate", false)
            if check_same_shell(ground_weapon, containerMesh, childBlkName) == -1
              let priority = get_prio_by_trigger(trigger_no)
              var hideNodes : array<string>
              check_broken_cap(container_blk, hideNodes)
              let customCart = container_blk |> datablock_getStr("bombCart", "")
              let roll = container_blk |> datablock_getReal("rollForDemonstration", 0.)
              let offset = container_blk |> datablock_getPoint3("offsetForDemonstration", float3(0.))
              ground_weapon.emplace(ShellParam(name = clone_string(containerMesh), bulletName = clone_string(childBlkName), prio = priority, blkName = clone_string(childBlkName),
              customCart = customCart, hideNodes <- hideNodes, roll = roll, offset = offset, presetName = clone_string(preset_name)))
            res = true
      return res
  return false

def read_weapon_preset(preset_blk : DataBlock&; var air_weapon : array<ShellParam>&; var ground_weapon : array<ShellParam>&; preset_name : string)
  let weaponBlockId = preset_blk |> datablock_getNameId("Weapon")
  for weapon_i in 0u..preset_blk.blockCount
    let weaponBlk = preset_blk |> datablock_get_block(weapon_i)
    if *weaponBlk |> datablock_getBlockNameId() != weaponBlockId
      continue
    if weaponBlk != null
      var blkName = *weaponBlk |> datablock_getStr("blk", "")
      if blkName == ""
        continue
      let trigger = *weaponBlk |> datablock_getStr("trigger", "")
      let triggerNo = get_trigger_no_by_name(trigger)
      using() <| $(var blk : DataBlock)
        if datablock_load(blk, blkName)
          if blk |> datablock_getBool("fuelTankGun", false) || blk |> datablock_getBool("boosterGun", false)
            return
          if blk |> datablock_getBool("container", false)
            var newBlkName = ""
            if check_container(blk, newBlkName, ground_weapon, triggerNo, preset_name)
              return 
            if newBlkName != ""
              blkName = newBlkName
              datablock_load(blk, blkName)
          elif blk |> datablock_getBool("dontDemonstrate", false)
            return
          let useDeployed = blk |> datablock_getBool("demonstrateDeployedMesh", false)
          let mesh = useDeployed ? blk |> datablock_getStr("mesh_deployed", blk |> datablock_getStr("mesh", "")) : blk |> datablock_getStr("mesh", "")
          if mesh != "" && mesh != "empty_mesh"
            let rocketBlk = blk |> datablock_get_block_by_name("rocket")
            var caliber = -1.
            var leng = -1.
            var mass = -1.
            var bulletName = ""
            if rocketBlk != null
              caliber = rocketBlk |> datablock_getReal("caliber", -1.0)
              leng = rocketBlk |> datablock_getReal("length", -1.0)
              mass = rocketBlk |> datablock_getReal("mass", -1.0)
              bulletName = rocketBlk |> datablock_getStr("bulletName", "")
            else
              let bombBlk = blk |> datablock_get_block_by_name("bomb")
              if bombBlk != null
                caliber = bombBlk |> datablock_getReal("caliber", -1.0)
                leng = bombBlk |> datablock_getReal("length", -1.0)
                mass = bombBlk |> datablock_getReal("mass", -1.0)
              else
                let torpedoBlk = blk |> datablock_get_block_by_name("torpedo")
                if torpedoBlk != null
                  caliber = torpedoBlk |> datablock_getReal("caliber", -1.0)
                  leng = torpedoBlk |> datablock_getReal("length", -1.0)
                  mass = torpedoBlk |> datablock_getReal("mass", -1.0)
            let customCart = blk |> datablock_getStr("bombCart", "")
            let roll = blk |> datablock_getReal("rollForDemonstration", 0.)
            let offset = blk |> datablock_getPoint3("offsetForDemonstration", float3(0.))
            if triggerNo == int(WeaponTriggerType.AAM_TRIGGER)
              var prio = 0
              if rocketBlk != null
                prio = get_aam_priotity(*rocketBlk)
              if check_same_shell(air_weapon, mesh, bulletName) == -1
                air_weapon.emplace(ShellParam(name = clone_string(mesh), bulletName = clone_string(bulletName), prio = prio, mass = mass, caliber = caliber,
                len = leng, blkName = clone_string(blkName), customCart = clone_string(customCart),
                roll = roll, offset = offset, presetName = clone_string(preset_name)))
            else
              if check_same_shell(ground_weapon, mesh, bulletName) == -1
                let priority = get_prio_by_trigger(triggerNo)
                var hideNodes : array<string>
                check_broken_cap(blk, hideNodes)
                ground_weapon.emplace(ShellParam(name = clone_string(mesh), bulletName = clone_string(bulletName), prio = priority, mass = mass, caliber = caliber,
                len = leng, blkName = clone_string(blkName), customCart = clone_string(customCart), hideNodes <- hideNodes, roll = roll,
                offset = offset, presetName = clone_string(preset_name)))

def create_list_of_demonstrated_shell(unit_blk : DataBlock&; var air_weapon : array<ShellParam>&; var ground_weapon : array<ShellParam>&)
  let weaponSlotsBlk = unit_blk |> datablock_get_block_by_name("WeaponSlots")
  if weaponSlotsBlk != null
    for blk_i in 0u..weaponSlotsBlk.blockCount
      let slot_blk = *weaponSlotsBlk |> datablock_get_block(blk_i)
      for wp_i in 0u..slot_blk.blockCount
        let wpBlk = *slot_blk |> datablock_get_block(wp_i)
        let presetName = wpBlk |> datablock_getStr("name", "")
        read_weapon_preset(*wpBlk, air_weapon, ground_weapon, presetName)
  else
    let weaponPresetBlk = unit_blk |> datablock_get_block_by_name("weapon_presets")
    if weaponPresetBlk != null
      for blk_i in 0u..weaponPresetBlk.blockCount
        let presetBlk = *weaponPresetBlk |> datablock_get_block(blk_i)
        let presetName = presetBlk |> datablock_getStr("name", "")
        let presetBlkName = presetBlk |> datablock_getStr("blk", "")
        if presetBlkName != ""
          using() <| $(var blk : DataBlock)
            if datablock_load(blk, presetBlkName)
              read_weapon_preset(blk, air_weapon, ground_weapon, presetName)

def spawn_shell(shell : ShellParam&; var tm : float3x4; for_tank : bool)
  drop_object_on_ground_normal(tm, true, 3.)
  tm[3].y += 0.5
  createEntity("demonstrated_shell") <| $(var init : ComponentsInitializer)
    set(init, "simpleObject__resName", shell.name)
    set(init, "transform", tm)
    set(init, "demonstrated_shell__caliber", shell.caliber)
    set(init, "demonstrated_shell__length", shell.len)
    set(init, "demonstrated_shell__blk", shell.blkName)
    set(init, "demonstrated_shell__presetName", shell.presetName)
    set(init, "simpleObject__hideNodes", shell.hideNodes)
    set(init, "demonstrated_shell__cart", shell.customCart)
    set(init, "demonstrated_shell__offset", shell.offset)
    set(init, "demonstrated_shell__roll", shell.roll)
    set(init, "simpleObject__scale", shell.scale)
    set(init, "demonstrated_shell__forTank", for_tank)
    set(init, "demonstrated_shell__isVertical", shell.vertical)
    set(init, "simpleObject__charName", shell.animChar)

def sort_shells(var shells : array<ShellParam>&)
  sort(shells) <| $(a, b)
    if a.prio == b.prio
      return a.mass > b.mass
    return a.prio > b.prio


def set_shell_on_pos(shell : ShellParam&; utm : float3x4&; pos : int; total : int; dist : float)
  let angStep = 0.05 * PI
  let startAng = 0.12 * PI
  let isPairDemonstration = true

  let offset = total % 2 == 0 ? 0.5 : 0.
  var rotTm = IDENT_TM
  if isPairDemonstration
    for j in 0..2
      var tm = utm
      tm[1] = float3(0., 1., 0.)
      tm[0] = cross(tm[1], tm[2])
      tm[2] = cross(tm[0], tm[1])
      let mult = j == 0 ? 1. : -1.
      rotyTM(((float(pos) + 0.5) * angStep + startAng) * mult, rotTm)
      tm = tm * rotTm
      let shellPos = utm[3] + tm[0] * dist
      tm[3] = shellPos
      spawn_shell(shell, tm, false)
  else
    var tm = utm
    tm[1] = float3(0., 1., 0.)
    tm[0] = cross(tm[2], tm[1])
    tm[2] = cross(tm[0], tm[1])
    let posI = (pos + 1) / 2 * (pos % 2 == 1 ? -1 : 1)
    rotyTM((float(posI) + offset) * angStep, rotTm)
    tm = tm * rotTm
    let shellPos = utm[3] + tm[0] * dist
    tm[3] = shellPos
    spawn_shell(shell, tm, false)

[es(tag=hangar, REQUIRE=unit_tag__aircraft)]
def init_demonstrated_shells(evt : CmdInitComponent;
                             unit__ref : UnitRef;
                             unit__playerId : int)
  if !is_shell_demonstration_enabled()
    return
  if unit__playerId < 0
    return
  if !guioptions_getBool("OPTIONS_MODE_GAMEPLAY", "USEROPT_SHOW_DEMONSTRATED_SHELL", true)
    return
  assume unitBlk = *evt.modelBlk
  init_demonstrated_shells_impl(unitBlk, unit__ref)

def init_demonstrated_shells_impl(blk : DataBlock&;
                                  unit__ref : UnitRef)
  let unit = unit__ref.unit
  let unitPos = unit.pos
  if get_is_water(unitPos)
    return
  var airWeapon : array<ShellParam>
  var groundWeapon : array<ShellParam>
  let isPairDemonstration = true
  create_list_of_demonstrated_shell(blk, airWeapon, groundWeapon)
  sort_shells(airWeapon)
  sort_shells(groundWeapon)
  if airWeapon |> length() <= 0 && groundWeapon |> length() <= 0
    return

  let awCnt = min(length(airWeapon), maxCnt)
  let groundWeaponDist = max(7., unit.boundingBox.boxMax.x * 1.1) 
  let airWeaponDist = length(groundWeapon) > 0 ? max(12., unit.boundingBox.boxMax.x * 1.1 + 5.) : groundWeaponDist
  for shell, i in airWeapon, range(0, length(airWeapon))
    set_shell_on_pos(shell, unit.unitTm, i, awCnt, airWeaponDist)
  let gwCnt = min(length(groundWeapon), maxCnt)
  for shell, i in groundWeapon, range(0, gwCnt)
    set_shell_on_pos(shell, unit.unitTm, i, gwCnt, groundWeaponDist)

[es(on_disappear, REQUIRE=controlledHero)]
def destroy_demonstrated_shells(evt : Event)
  query() <| $ [es(REQUIRE=demonstrated_shell)] (eid : EntityId)
    destroyEntity(eid)

def create_cart(cart_templ : string; transform : float3x4; shell_eid : EntityId)
  var ctm = transform
  ctm[1] = float3(0., 1., 0.)
  ctm[2] = cross(ctm[0], ctm[1])
  drop_object_on_ground_normal(ctm, true, 1.)
  createEntity(cart_templ) <| $(var init : ComponentsInitializer)
    set(init, "transform", ctm)
    set(init, "bomb_cart__shellEid", shell_eid)

[es(on_appear)]
def on_demonstrated_shell_appear(evt : Event;
                                 transform : float3x4;
                                 eid : EntityId;
                                 var demonstrated_shell__caliber : float&;
                                 var demonstrated_shell__length : float&;
                                 demonstrated_shell__forTank : bool;
                                 demonstrated_shell__isVertical : bool;
                                 simpleObject__bboxMax : float3;
                                 simpleObject__bboxMin : float3;
                                 simpleObject__scale : float;
                                 demonstrated_shell__cart : string)
  if demonstrated_shell__cart == "not"
    return
  if demonstrated_shell__cart |> length() > 0
    create_cart(demonstrated_shell__cart, transform, eid)
    return
  if demonstrated_shell__caliber <= 0.
    demonstrated_shell__caliber = abs(simpleObject__bboxMax.y - simpleObject__bboxMin.y) * simpleObject__scale
  if demonstrated_shell__length <= 0.
    demonstrated_shell__length = abs(simpleObject__bboxMax.x - simpleObject__bboxMin.x) * simpleObject__scale
  query() <| $ [es] (shell_carts_params : Array; plane_demonstrated_shells : Tag const?; tank_demonstrated_shells : Tag const?)
    if demonstrated_shell__forTank && tank_demonstrated_shells == null
      return
    if !demonstrated_shell__forTank && plane_demonstrated_shells == null
      return
    for i in range(length(shell_carts_params))
      let obj = shell_carts_params[i] as Object
      if obj != null
        let vertical = obj?.isVertical ?? false
        if vertical != demonstrated_shell__isVertical
          continue
        let caliberRange = obj?.calibers ?? float2(-1.)
        let lenRange = obj?.length ?? float2(-1.)
        if (demonstrated_shell__caliber >= caliberRange.x && demonstrated_shell__caliber <= caliberRange.y &&
        demonstrated_shell__length >= lenRange.x && demonstrated_shell__length <= lenRange.y)
          let cartTempl = obj?.cartTemplate ?? ""
          if cartTempl != ""
            create_cart(cartTempl, transform, eid)
            break

[es(on_appear)]
def on_shell_cart_appear(evt : Event;
                         bomb_cart__shellEid : EntityId;
                         transform aka cart_transform : float3x4;
                         bomb_cart__linkPoint1 : float3;
                         bomb_cart__linkPoint2 : float3)
  if bomb_cart__shellEid == INVALID_ENTITY_ID
    return
  query(bomb_cart__shellEid) <| $ [es] (var transform aka shell_transform : float3x4&;
                                        simpleObject__bboxMax : float3;
                                        simpleObject__bboxMin : float3;
                                        demonstrated_shell__caliber : float;
                                        demonstrated_shell__offset : float3;
                                        demonstrated_shell__roll : float;
                                        demonstrated_shell__isVertical : bool;
                                        simpleObject__scale : float)
    if demonstrated_shell__isVertical
      shell_transform[0] = cart_transform[1]
      shell_transform[1] = cart_transform[0]
      shell_transform[2] = cross(shell_transform[0], shell_transform[1])
      let newPosition = cart_transform * bomb_cart__linkPoint1
      shell_transform[3] = newPosition - shell_transform[0] * simpleObject__bboxMin.x
      shell_transform[3] = shell_transform * demonstrated_shell__offset
    else
      let topPivot = abs(simpleObject__bboxMax.y) < abs(simpleObject__bboxMin.y) * 0.3
      let offset = (simpleObject__bboxMax.x + simpleObject__bboxMin.x) * 0.5 * simpleObject__scale
      let newPosition = cart_transform * ((bomb_cart__linkPoint1 + bomb_cart__linkPoint2) * 0.5)
      assert(length_sq(bomb_cart__linkPoint1 - bomb_cart__linkPoint2) > 0.)
      let newDir = quat_mul_vec(math::quat(cart_transform), normalize(bomb_cart__linkPoint1 - bomb_cart__linkPoint2))
      shell_transform[0] = newDir
      shell_transform[1] = normalize(cross(shell_transform[2], newDir))
      shell_transform[2] = cross(shell_transform[0], shell_transform[1])
      var rotTm = IDENT_TM
      rotxTM(demonstrated_shell__roll * PI / 180., rotTm)
      shell_transform = shell_transform * rotTm
      let verticalOffset = 0.5 + (topPivot ? 0.5 : 0.) * cos(demonstrated_shell__roll * PI / 180.)
      shell_transform[3] = newPosition + demonstrated_shell__caliber * cart_transform[1] * verticalOffset - offset * cart_transform[0]
      shell_transform[3] = shell_transform * demonstrated_shell__offset

[es(REQUIRE=demonstrated_shell)]
def on_weaponry_wnd_toggle(evt : EventToggleWeaponryWnd;
                           var simpleObject__visible : bool&)
  simpleObject__visible = !evt.isOpen

[es(tag=hangar)]
def on_demonstarted_shell_option_toggle(evt : EventToggleDemonstratedShellOpt;
                                        unit__ref : UnitRef;
                                        unit__playerId : int)
  if unit__playerId < 0
    return
  var found = false
  query() <| $ [es(REQUIRE=demonstrated_shell)] (var simpleObject__visible : bool&)
    simpleObject__visible = evt.enable
    found = true
  if !found && evt.enable
    if !is_shell_demonstration_enabled()
      return
    using() <| $(var blk : DataBlock)
      if unit__ref.unit.isFlightModelWrap
        if datablock_load(blk, "gameData/flightModels/{unit__ref.unit.props.fileName}.blk")
          init_demonstrated_shells_impl(blk, unit__ref)
      elif unit__ref.unit.isTank && datablock_load(blk, "gameData/units/{unit__ref.unit.props.fileName}.blk")
        init_demonstrated_tank_bullets_impl(blk, unit__ref)

def check_same_bullet(var list : array<ShellParam>&; check_name : string)
  return find_index_if(list) <| $(p) : bool
    return p.blkName == check_name;

def read_rocket_prop(rocket_blk : DataBlock&; var bullets : array<ShellParam>&; mesh : string; bullet_name : string)
  if check_same_bullet(bullets, bullet_name) > -1
    return
  let mass = rocket_blk |> datablock_getReal("mass", -1.)
  let caliber = rocket_blk |> datablock_getReal("caliber", -1.)
  let customCart = rocket_blk |> datablock_getStr("bombCart", "")
  let offset = rocket_blk |> datablock_getPoint3("offsetForDemonstration", float3(0.))
  let charName = rocket_blk |> datablock_getStr("shellAnimChar", "")
  let penetration = calc_max_penetration(rocket_blk)
  bullets.emplace(ShellParam(name = clone_string(mesh), mass = mass, caliber = caliber,
    blkName = clone_string(bullet_name), customCart = clone_string(customCart), vertical = true, offset = offset,
    animChar = clone_string(charName), penetration = penetration))

def read_bullet_prop(bullet_blk : DataBlock&; var bullets : array<ShellParam>&)
  let rocketBlk = bullet_blk |> datablock_get_block_by_name("rocket")
  let bulletName = bullet_blk |> datablock_getStr("bulletName", "")
  if rocketBlk != null
    let mesh = *rocketBlk |> datablock_getStr("mesh_deployed", *rocketBlk |> datablock_getStr("mesh", ""))
    if mesh == ""
      return
    read_rocket_prop(*rocketBlk, bullets, mesh, bulletName)
    return
  let calib = bullet_blk |> datablock_getReal("caliber", -1.)
  if calib <= minimalCaliber
    return
  var mesh = ""
  let bulletType = bullet_blk |> datablock_getStr("bulletType", "")
  if bullet_blk |> datablock_param_exists("gbufferModelName", -1)
    mesh = bullet_blk |> datablock_getStr("gbufferModelName", "")
  else
    if bulletType == ""
      return
    mesh = get_bullet_mesh_by_type(bulletType)
  if mesh == ""
    return
  if check_same_bullet(bullets, bulletName) > -1
    return
  let mass = bullet_blk |> datablock_getReal("mass", -1.)
  let caliber = bullet_blk |> datablock_getReal("ballisticCaliber", calib)
  let customCart = bullet_blk |> datablock_getStr("bombCart", "")
  let offset = bullet_blk |> datablock_getPoint3("offsetForDemonstration", float3(0.))
  let penetration = calc_max_penetration(bullet_blk)
  bullets.emplace(ShellParam(name = clone_string(mesh), mass = mass, caliber = caliber, bulletType = clone_string(bulletType),
    blkName = clone_string(bulletName), scale = 10. * caliber, customCart = clone_string(customCart), offset = offset,
    penetration = penetration))

def get_modification_list(unit_blk : DataBlock&; var mods : array<string>&)
  let modsBlk = unit_blk |> datablock_get_block_by_name("modifications")
  if modsBlk == null
    return
  datablock_for_each_block(*modsBlk) <| $(modBlk)
    let blkName = modBlk |> datablock_getBlockName()
    if blkName != ""
      mods.push(blkName)

def create_list_of_demonstrated_bullets(unit_blk : DataBlock&; var bullets : array<ShellParam>&)
  let presetBlk = unit_blk |> datablock_get_block_by_name("commonWeapons")
  if presetBlk == null
    return
  var modList : array<string>
  get_modification_list(unit_blk, modList)
  datablock_for_each_block(*presetBlk, "Weapon") <| $(weaponBlk)
    var blkName = weaponBlk |> datablock_getStr("blk", "")
    if blkName == ""
      return
    let triggerGr = weaponBlk |> datablock_getStr("triggerGroup", "primary")
    if triggerGr != "primary" && triggerGr != "special" && triggerGr != "secondary"
      return
    using() <| $(var blk : DataBlock)
      if datablock_load(blk, blkName)
        let isRocketGun = blk |> datablock_getBool("rocketGun", false)
        if isRocketGun
          let rocketBlk = blk |> datablock_get_block_by_name("rocket")
          if rocketBlk != null
            let mesh = blk |> datablock_getStr("mesh_deployed", blk |> datablock_getStr("mesh", ""))
            let bulletName = *rocketBlk |> datablock_getStr("bulletName", "")
            if mesh != ""
              read_rocket_prop(*rocketBlk, bullets, mesh, bulletName)
        else
          let shotFreq = blk |> datablock_getReal("shotFreq", 1.)
          let dontUseStock = blk |> datablock_getBool("notUseDefaultBulletInGui", false)
          if shotFreq > maxShotFreq
            return
          let stockBlockId = blk |> datablock_getNameId("bullet")
          datablock_for_each_block(blk) <| $(bulletBlk)
            if bulletBlk |> datablock_getBlockNameId() == stockBlockId
              if !dontUseStock
                read_bullet_prop(bulletBlk, bullets)
            else
              let modName = bulletBlk |> datablock_getBlockName()
              if modList |> find_index(modName) >= 0
                datablock_for_each_block(bulletBlk, "bullet") <| $(modBulletBlk)
                  read_bullet_prop(modBulletBlk, bullets)

[es(tag=hangar, REQUIRE=unit_tag__tank)]
def init_demonstrated_tank_bullets(evt : CmdInitComponent;
                                   unit__ref : UnitRef;
                                   unit__playerId : int)
  if !is_shell_demonstration_enabled()
    return
  if unit__playerId < 0
    return
  if !guioptions_getBool("OPTIONS_MODE_GAMEPLAY", "USEROPT_SHOW_DEMONSTRATED_SHELL_TANK", true)
    return
  assume unitBlk = *evt.modelBlk
  init_demonstrated_tank_bullets_impl(unitBlk, unit__ref)

def init_demonstrated_tank_bullets_impl(blk : DataBlock&;
                                        unit__ref : UnitRef)
  var bulletList : array<ShellParam>
  create_list_of_demonstrated_bullets(blk, bulletList)
  if bulletList |> length() <= 0
    return
  let unit = unit__ref.unit
  let unitPos = unit.pos
  let cnt = min(length(bulletList), maxBulletCnt)
  let offset = 0.5
  for bullet, i in bulletList, range(0, cnt)
    var tm = unit.unitTm
    tm[3] = tm[3] + tm[2] * unit.boundingBox.boxMax.z * 2. + float(i - cnt / 2) * offset * cross(tm[2], float3(0., 1., 0.))
    tm[0] = tm[2]
    tm[2] = cross(tm[0], tm[1])
    spawn_shell(bullet, tm, true)



































