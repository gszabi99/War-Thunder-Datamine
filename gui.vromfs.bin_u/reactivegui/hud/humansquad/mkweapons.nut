from "%rGui/globals/ui_library.nut" import *
let { hudBlurPanel } = require("%rGui/components/blurPanel.nut")
let { heroStateWidth, actionBarItemHeight } = require("%rGui/hud/humanSquad/humanConst.nut")
let { humanCurGunStaticInfo, humanCurGunInfo, humanCurGunModeInfo, getLauncherNextUseAtTime
} = require("%rGui/hud/state/human_gun_info_es.nut")
let icon3dByGameTemplate = require("%globalScripts/iconRender/icon3dByGameTemplate.nut")
let forceRealTimeRenderIcon = require("%globalScripts/iconRender/forceRealTimeRenderIcon.nut")
let { white, hud } = require("%rGui/style/colors.nut")
let { infantryHudInactiveColor, infantryHudCommonColor, infantryHudDisabledColor } = hud
let { Color4 } = require("dagor.math")
let { ceil } = require("math")
let { get_mission_time } = require("mission")
let { setInterval, clearTimer } = require("dagor.workcycle")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")
let { grenades } = require("%rGui/hud/state/grenades_es.nut")
let { selfHealMedkits } = require("%rGui/hud/state/medkits_es.nut")
let { grenadeIcon, getGrenadeType } = require("%rGui/hud/humanSquad/grenadeIcon.nut")


let coolDownTime = Watched("")
let launcherEid = Computed(@() humanCurGunInfo.get()?.launcherEid ?? 0)

let weaponBlockPadding = [hdpxi(5), hdpxi(3), hdpxi(5), hdpxi(5)]
let weaponImageSize = [shHud(12) - (weaponBlockPadding[1] + weaponBlockPadding[3]), shHud(3.5)]
let itemGap = hdpxi(4)
let rifleGrenadeSize = const [ hdpxi(24), hdpxi(24) ]
let iconSize = const [ hdpxi(20), hdpxi(20) ]


let overrideItemIcon = {
  armor_box_item = $"ui/gameuiskin#human_armor_box.svg:{weaponImageSize[1]}:{weaponImageSize[1]}:P"
  ammo_box_item = $"ui/gameuiskin#human_ammo_box.svg:{weaponImageSize[1]}:{weaponImageSize[1]}:P"
  explosives_box_item = $"ui/gameuiskin#human_explosives_box.svg:{weaponImageSize[1]}:{weaponImageSize[1]}:P"
  medic_box_item = $"ui/gameuiskin#human_med_box.svg:{weaponImageSize[1]}:{weaponImageSize[1]}:P"
}


let whiteColor4 = Color4(255,255,255,255)


let isWeaponEnabled = Computed(function() {
  let { curAmmo = 0, totalAmmo = 0 } = humanCurGunInfo.get()
  let { haveAmmo = false } = humanCurGunStaticInfo.get()
  return haveAmmo ? curAmmo + totalAmmo > 0
    : launcherEid.get() > 0 ? coolDownTime.get() == ""
    : true
})


function updateCooldownTime() {
  let eid = launcherEid.get()
  let nextUseAtTime = eid <= 0 ? 0 : getLauncherNextUseAtTime(eid)
  let sec = max(0, ceil(nextUseAtTime - get_mission_time()).tointeger())
  coolDownTime.set(sec > 0 ? secondsToTimeSimpleString(sec) : "")
}

function launcherEidCheck(eid) {
  updateCooldownTime()
  clearTimer(updateCooldownTime)
  if (eid > 0)
    setInterval(1, updateCooldownTime)
}

function mkWeaponImage() {
  if (humanCurGunStaticInfo.get()?.iconTemplate == null)
    return { watch = humanCurGunStaticInfo }

  if (humanCurGunStaticInfo.get().iconTemplate in overrideItemIcon)
    return {
      watch = [humanCurGunStaticInfo, isWeaponEnabled]
      rendObj = ROBJ_IMAGE
      image = Picture(overrideItemIcon[humanCurGunStaticInfo.get().iconTemplate])
      color = isWeaponEnabled.get() ? infantryHudCommonColor : infantryHudDisabledColor
      size = [ weaponImageSize[1], weaponImageSize[1] ]
    }

  return {
    watch = [ humanCurGunStaticInfo, forceRealTimeRenderIcon, isWeaponEnabled ]
    size = weaponImageSize
    rendObj = ROBJ_IMAGE
    color = isWeaponEnabled.get() ? white : infantryHudDisabledColor
    image = Picture(icon3dByGameTemplate(humanCurGunStaticInfo.get().iconTemplate, {
      width = weaponImageSize[0]
      height = weaponImageSize[1]
      silhouetteColor = whiteColor4
      forceRealTimeRenderIcon = forceRealTimeRenderIcon.get()
      renderSettingsPlace = "hud_action_bar"
      
    }))
  }
}


let mkAmmoTypeImage = {
  rendObj = ROBJ_IMAGE
  color = infantryHudCommonColor
  size = rifleGrenadeSize
  vplace = ALIGN_CENTER
  image = Picture($"ui/gameuiskin#icon_rifle_grenade.svg:{rifleGrenadeSize[0]}:{rifleGrenadeSize[1]}:P")
}

let bigText = @(textWatch, color = white) @() {
  watch = textWatch
  rendObj = ROBJ_TEXT
  text = textWatch.get()
  color
  font = Fonts.very_tiny_text_hud
}

let bigTextFixed = @(text, color = white) {
  rendObj = ROBJ_TEXT
  text
  color
  font = Fonts.very_tiny_text_hud
}

let mkIcon = @(image, color) {
  size = iconSize
  rendObj = ROBJ_IMAGE
  color
  image
}

function fireModeChildren() {
  let fireModesList = Computed(@() humanCurGunInfo.get()?.firingModesList ?? [])
  let fireMode = Computed(@() humanCurGunInfo.get()?.firingMode)
  return @() fireModesList.get().len() <= 1 ? { watch = fireModesList } : {
    watch = [ fireModesList, fireMode ]
    children = bigTextFixed(loc($"weapon_menu/fire_mods/{fireMode.get()}"))
  }
}

function mkWeaponAmmo(ammoWatch, ammoTotalWatch, addChildren) {
  return {
    flow = FLOW_HORIZONTAL
    size = FLEX_H
    children = [
      addChildren
      { size = [flex(), 0] }
      bigText(ammoWatch)
      bigText(Watched("/"), infantryHudInactiveColor)
      bigText(ammoTotalWatch, infantryHudInactiveColor)
    ]
  }
}

function mkAmmoBlock() {
  let haveAmmo = Computed(@() humanCurGunStaticInfo.get()?.haveAmmo ?? false)
  let curGunMod = Computed(@() humanCurGunModeInfo.get()?.modWeapon)
  let isModActive = Computed(@() curGunMod.get()?.isModActive ?? false)
  let curWeaponAmmo = Computed(@() humanCurGunInfo.get()?.curAmmo ?? 0)
  let curWeaponTotalAmmo = Computed(@() humanCurGunInfo.get()?.totalAmmo ?? 0)
  let curWeaponAltAmmo = Computed(@() curGunMod.get()?.modCurAmmo ?? 0)
  let curWeaponAltTotalAmmo = Computed(@() curGunMod.get()?.modTotalAmmo ?? 0)

  return @() {
    watch = [haveAmmo, isModActive]
    size = FLEX_H
    vplace = ALIGN_TOP
    children = [
      !haveAmmo.get() ? null : isModActive.get()
        ? mkWeaponAmmo(curWeaponAltAmmo, curWeaponAltTotalAmmo, mkAmmoTypeImage)
        : mkWeaponAmmo(curWeaponAmmo, curWeaponTotalAmmo, fireModeChildren())
    ]
  }
}

function medkitsBlock() {
  let icon = Picture($"ui/gameuiskin#first_aid_kit.svg:{iconSize[0]}:{iconSize[1]}:P")

  return {
    watch = selfHealMedkits
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = itemGap
    children = [
      mkIcon(icon, selfHealMedkits.get() > 0 ? white : infantryHudInactiveColor)
      bigTextFixed(selfHealMedkits.get(),
        selfHealMedkits.get() > 0 ? white : infantryHudInactiveColor)
    ]
  }
}

function grenadesBlock() {
  let grenadeType = Computed(function() {
    let t = getGrenadeType(grenades.get().keys())
    return t == null || t == "wall_bomb" ? null : t
  })
  let grenadesCount = Computed(@() grenades.get()?[grenadeType.get()] ?? 0)

  return @() {
    watch = [ grenadeType, grenadesCount ]
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = itemGap
    children = [
      mkIcon(
        grenadeIcon(grenadeType.get(), iconSize[0]),
        grenadesCount.get() > 0 ? white : infantryHudInactiveColor
      )
      bigTextFixed(grenadesCount.get(),
        grenadesCount.get() > 0 ? white : infantryHudInactiveColor)
    ]
  }
}

return {
  size = [ heroStateWidth, actionBarItemHeight ]
  children = [
    hudBlurPanel
    {
      size = flex()
      padding = weaponBlockPadding
      children = [
        mkAmmoBlock()
        {
          size = flex()
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = [
            mkWeaponImage
            bigText(coolDownTime)
          ]
        }
        {
          flow = FLOW_HORIZONTAL
          valign = ALIGN_CENTER
          vplace = ALIGN_BOTTOM
          size = FLEX_H
          children = [
            grenadesBlock()
            { size = [flex(), 0] }
            medkitsBlock
          ]
        }
      ]
    }
  ]
  function onAttach() {
    launcherEidCheck(launcherEid.get())
    launcherEid.subscribe(launcherEidCheck)
  }
  function onDetach() {
    launcherEid.unsubscribe(launcherEidCheck)
    clearTimer(updateCooldownTime)
  }
}