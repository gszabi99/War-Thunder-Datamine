from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { format } = require("string")
let { hangar_set_dm_viewer_mode } = require("hangar")
let { on_parse_replay, get_parsed_replay, get_replay_info, repeat_shot_from_blk,
  on_parse_temp_replay, get_temp_replay_info, get_replay_hits_dir, set_replay_hits_mode,
  on_update_loaded_model } = require("replays")
let { doesLocTextExist } = require("dagor.localize")
let { calculate_tank_bullet_parameters } = require("unitCalculcation")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isInMenu, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getUnitName, getUnitCountry, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { secondsToTimeSimpleString } = require("%scripts/time.nut")
let { setShowUnit, getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { image_for_air } = require("%scripts/options/optionsExt.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getBulletSetNameByBulletName, getBulletsSetData, getBulletsSearchName,
  getModificationBulletsEffect } = require("%scripts/weaponry/bulletsInfo.nut")
let { getUnitWeapons } = require("%scripts/weaponry/weaponryPresets.nut")

let bulletInfoCache = {}

function getBulletInfo(unit, hit) {
  let key = $"{hit.offenderObject}{hit.weapon}{hit.ammo}{hit.ammoNo}"
  if (key in bulletInfoCache)
    return bulletInfoCache[key]

  let bulletSet = DataBlock()

  let weaponBlk = DataBlock()
  weaponBlk.tryLoad(hit.weapon)

  if (weaponBlk?.rocketGun == true) {
    let rockets = weaponBlk % "rocket"
    bulletSet.setFrom(rockets[hit.ammoNo])

    bulletInfoCache[key] <- {
      bulletDesc = doesLocTextExist(bulletSet.bulletName) ? loc(bulletSet.bulletName) : loc($"weapons/{bulletSet.bulletName}/short", "")
      isRocket = true
    }
    return bulletInfoCache[key]
  }

  if (weaponBlk?.bombGun == true) {
    let bombs = weaponBlk % "bomb"
    bulletSet.setFrom(bombs[hit.ammoNo])

    bulletInfoCache[key] <- {
      bulletDesc = doesLocTextExist(bulletSet.bulletName) ? loc(bulletSet.bulletName) : loc($"weapons/{bulletSet.bulletName}/short", "")
      isBomb = true
    }
    return bulletInfoCache[key]
  }

  let ammoType = hit.ammo != "" ? hit.ammo : hit.ammoType
  let bulletSetName = getBulletSetNameByBulletName(unit, ammoType)
  let bulletsSet = getBulletsSetData(unit, bulletSetName ?? ammoType)

  let isBulletBelt = bulletsSet?.isBulletBelt ?? ((weaponBlk?.bullets ?? -1) > 1)

  if (!isBulletBelt) {
    bulletInfoCache[key] <- {
      bulletDesc = doesLocTextExist(hit.ammo) ? loc(hit.ammo) : loc($"weapons/{hit.ammo}/short", "")
      isBulletBelt
      bulletSetName = bulletSetName ?? ""
    }
    return bulletInfoCache[key]
  }

  let bullets = (hit.ammo == "" || weaponBlk.getBlockByName(hit.ammo) == null) ? weaponBlk % "bullet"
    : weaponBlk[hit.ammo] % "bullet"

  bulletSet.setFrom(bullets[hit.ammoNo])
  let { bulletType, caliber } = bulletSet
  bulletInfoCache[key] <- {
    bulletName = bulletType
    bulletDesc = $"{format(loc("caliber/mm"), caliber * 1000)} {loc($"{bulletType}/name/short")}"
    isBulletBelt
    bulletSet
    bulletsSet
  }
  return bulletInfoCache[key]
}

gui_handlers.HitsAnalysis <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/dmViewer/hitsAnalysis.blk"

  hitsData = null
  currentHitsData = []
  owners = []
  ediff = null
  selectedHit = null

  function initScreen() {
    this.setSceneTitle(loc("hitsAnalisys"))
    this.fillHitOwnerList()
  }

  function fillHitOwnerList() {
    this.owners.clear()
    let items = []
    let hitsOwner = this.scene.findObject("hits_owner")

    if (this.hitsData.findindex(@(v) v.damageRole == "offender") != null) {
      items.append({ text = loc("hitsAnalisys/myHits") })
      this.owners.append("offender")
    }
    if (this.hitsData.findindex(@(v) v.damageRole == "victim") != null) {
      items.append({ text = loc("hitsAnalisys/enemyHits") })
      this.owners.append("victim")
    }

    let data = ::create_option_combobox("hits_owner", items, 0, "onHitsOwnerChange", false)
    this.guiScene.replaceContentFromText(hitsOwner, data, data.len(), this)
    hitsOwner.setValue(0)
    set_replay_hits_mode(true)
  }

  function fillShotsList() {
    let diff = this.ediff
    let hitsData = this.currentHitsData
      .map(function(h, idx) {
        let time = secondsToTimeSimpleString(h.time)
        let unit = getAircraftByName(h.object)
        let br = unit?.getBattleRating(diff) ?? 0
        let { bulletDesc } = getBulletInfo(getAircraftByName(h.offenderObject), h)
        let unitAndWeapon = $"[{br}] {getUnitName(unit?.name)} - {bulletDesc}"
        return {
          time
          unitAndWeapon
          hasBulletDesc = bulletDesc != ""
          idx
        }
      })
      .filter(@(h) h.hasBulletDesc)
    let listObj = this.scene.findObject("shots_list")
    let data = handyman.renderCached("%gui/dmViewer/hitsAnalysisItems.tpl", { items = hitsData })
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    listObj.setValue(0)
  }

  function onHitsOwnerChange(obj) {
    let damageRole = this.owners[obj.getValue()]
    this.currentHitsData = this.hitsData.filter(@(v) v.damageRole == damageRole)
    this.fillShotsList()
  }

  function onItemSelect(obj) {
    let item = obj.getChild(obj.getValue())
    let idx = to_integer_safe(item["idx"])
    this.selectedHit = this.currentHitsData[idx]
    let unit = getAircraftByName(this.selectedHit.offenderObject)
    let unitType = $"{unit.unitType.fontIcon} {unit.unitType.getArmyLocName()}"
    let unitCountryFlag = getUnitCountryIcon(unit, true)
    let unitCountry = loc(getUnitCountry(unit))
    let unitRank = $"{get_roman_numeral(unit.rank)} {loc("shop/age")}"
    let unitIcon = image_for_air(unit)
    let unitName = $"[{unit.getBattleRating(this.ediff)}] {getUnitName(this.selectedHit.offenderObject, true)}"

    let { bulletDesc } = getBulletInfo(unit, this.selectedHit)

    this.scene.findObject("unitType").setValue(unitType)
    this.scene.findObject("unitCountryFlag")["background-image"] = unitCountryFlag
    this.scene.findObject("unitCountry").setValue(unitCountry)
    this.scene.findObject("unitRank").setValue(unitRank)
    this.scene.findObject("unitIcon")["background-image"] = unitIcon
    this.scene.findObject("unitName").setValue(unitName)

    this.scene.findObject("unitTooltip")["tooltipId"] = getTooltipType("UNIT").getTooltipId(unit.name, { showLocalState = false })
    this.scene.findObject("bulletName").setValue(bulletDesc)
    this.scene.findObject("shotDistance").setValue(this.selectedHit.distance)
    this.scene.findObject("shotDistanceText").setValue($"{this.selectedHit.distance} {loc("measureUnits/meters_dist")}")
    this.updateBulletTooltip(unit)

    if (getShowedUnit()?.name == this.selectedHit.object) {
      on_update_loaded_model(this.selectedHit)
      return
    }
    setShowUnit(getAircraftByName(this.selectedHit.object))
    return
  }

  function onEventHangarModelLoaded(_) {
    if (this.selectedHit == null)
      return
    on_update_loaded_model(this.selectedHit)
  }

  function updateBulletTooltip(unit) {
    let { bulletName = "", bulletSet = null, bulletsSet = null, bulletSetName = "",
      isBulletBelt = false, isRocket = false, isBomb = false } = getBulletInfo(unit, this.selectedHit)

    this.scene.findObject("bulletTooltip")["tooltipId"] = ""

    if (isRocket || isBomb) {
      let unitBlk = ::get_full_unit_blk(unit.name)
      let weapons = getUnitWeapons(unitBlk)

      local presetName = ""
      local tType = ""
      let hit = this.selectedHit

      for (local i = 0; i < weapons.len(); i++) {
        let weapon = weapons[i]
        if (weapon?.blk == hit.weapon) {
          tType = weapon.trigger
          presetName = weapon.presetId
          break
        }
        let wblk = DataBlock()
        wblk.tryLoad(weapon.blk)
        if (wblk?.blk == hit.weapon) {
          tType = weapon.trigger
          presetName = weapon.presetId
          break
        }
      }

      if (tType !="" && presetName != "")
        this.scene.findObject("bulletTooltip")["tooltipId"] = getTooltipType("SINGLE_WEAPON").getTooltipId(unit.name, {
          blkPath = this.selectedHit.weapon
          tType
          presetName
        })
      return
    }

    if (!isBulletBelt && bulletSetName != "") {
      this.scene.findObject("bulletTooltip")["tooltipId"] = getTooltipType("MODIFICATION").getTooltipId(unit.name, bulletSetName)
      return
    }

    if (bulletsSet == null)
      return

    let bSet = bulletsSet.__merge({
      bullets = [bulletName]
      bulletAnimations = [bulletSet?.shellAnimation]
    })

    let searchName = getBulletsSearchName(unit, this.selectedHit.ammo)
    let useDefaultBullet = searchName != this.selectedHit.ammo
    let bulletParameters = calculate_tank_bullet_parameters(unit.name,
      (useDefaultBullet && this.selectedHit.weapon) || getModificationBulletsEffect(searchName),
      useDefaultBullet, false)

    let bulletParams = bulletParameters.findvalue(@(p) p.bulletType == bulletSet?.bulletType)

    this.scene.findObject("bulletTooltip")["tooltipId"] = getTooltipType("SINGLE_BULLET").getTooltipId(unit.name, bulletName, {
      modName = this.selectedHit.ammo
      bSet
      bulletParams
    })
  }

  function onSimulateShot(_) {
    if (this.selectedHit == null)
      return

    repeat_shot_from_blk(this.selectedHit)
  }

  function onSaveShot(_) {
    if (this.selectedHit == null)
      return

    let fileName = $"{this.selectedHit.object}_{this.selectedHit.ammo}_{this.selectedHit.time}"
    let onSelectCallback = function(path) {
      let filePath = $"{get_replay_hits_dir()}\\{path}.blk"
      this.selectedHit.saveToTextFile(filePath)
    }

    handlersManager.loadHandler(gui_handlers.RenameReplayHandler, {
      baseName = fileName
      basePath = "/".concat(get_replay_hits_dir(), fileName)
      funcOwner = this
      afterRenameFunc = null
      afterFunc = onSelectCallback
      title = "filesystem/fileName"
    })
  }

  function goBack() {
    hangar_set_dm_viewer_mode(DM_VIEWER_NONE)
    set_replay_hits_mode(false)
    base.goBack()
  }
}

function canOpenHitsAnalysisWindow() {
  return hasFeature("HitsAnalysis")
    && isInMenu()
    && !::SessionLobby.hasSessionInLobby()
}

function openHitsAnalysisWindow(path = null) {
  if (!canOpenHitsAnalysisWindow())
    return

  if (path == null)
    on_parse_temp_replay()
  else
    on_parse_replay(path)

  let parsedReplay = get_parsed_replay()
  let hitsDataDb = (parsedReplay % "context")
  if (hitsDataDb.len() == 0) {
    scene_msg_box("shot_analysis", null, loc("hitsAnalisys/noHitsInReplay"), [["ok", @() null]], null)
    return
  }

  let hitsData = hitsDataDb.map(function(h) {
    let res = DataBlock()
    res.setFrom(h)
    return res
  })

  let ediff = (path == null) ? get_temp_replay_info().difficulty : get_replay_info(path).difficulty
  handlersManager.loadHandler(gui_handlers.HitsAnalysis, { hitsData, ediff })
}

return {
  canOpenHitsAnalysisWindow
  openHitsAnalysisWindow
}
