from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs

let { hudBlurPanel } = require("%rGui/components/blurPanel.nut")
let { heroStateWidth, actionBarItemHeight } = require("%rGui/hud/humanSquad/humanConst.nut")
let { humanCurGunStaticInfo, humanCurGunInfo, humanCurGunModeInfo, getLauncherNextUseAtTime
} = require("%rGui/hud/state/human_gun_info_es.nut")
let icon3dByGameTemplate = require("%globalScripts/iconRender/icon3dByGameTemplate.nut")
let forceRealTimeRenderIcon = require("%globalScripts/iconRender/forceRealTimeRenderIcon.nut")
let { white, hud } = require("%rGui/style/colors.nut")
let { inactiveHudColor } = hud
let { Color4 } = require("dagor.math")
let { ceil } = require("math")
let { get_mission_time } = require("mission")
let { setInterval, clearTimer } = require("dagor.workcycle")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")


let coolDownTime = Watched("")
let launcherEid = Computed(@() humanCurGunInfo.get()?.launcherEid ?? 0)
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


let weaponImageSize = const [shHud(10), shHud(5)]
let activeAmmoIconSize = const [ shHud(2), shHud(2) ]
let inactiveAmmoIconSize = const [ shHud(1), shHud(1) ]
let weaponBlockPadding = evenPx(14)

let whiteColor4 = Color4(255,255,255,255)
let enableColor = 0xFFFFFFFF
let disableColor = 0xFF555555

let mkWeaponImage = @() humanCurGunStaticInfo.get() == null
  ? { watch = humanCurGunStaticInfo }
  : {
      watch = [ humanCurGunStaticInfo, forceRealTimeRenderIcon, humanCurGunModeInfo, isWeaponEnabled ]
      size = weaponImageSize
      rendObj = ROBJ_IMAGE
      color = isWeaponEnabled.get() ? enableColor : disableColor
      image = Picture(icon3dByGameTemplate(humanCurGunStaticInfo.get()?.iconTemplate, {
        width = weaponImageSize[0]
        height = weaponImageSize[1]
        silhouetteColor = whiteColor4
        forceRealTimeRenderIcon = forceRealTimeRenderIcon.get()
        renderSettingsPlace = "hud_action_bar"
        
      }))
    }


function mkAmmoTypeImage(isActive) {
  let size = isActive ? activeAmmoIconSize : inactiveAmmoIconSize
  return {
    rendObj = ROBJ_IMAGE
    color = isActive ? white : inactiveHudColor
    size
    vplace = ALIGN_CENTER
    margin = const [0, 0, 0, hdpxi(4)]
    image = Picture($"ui/gameuiskin#icon_rifle_grenade.svg:{size[0]}:{size[1]}:P")
  }
}

let bigText = @(textWatch) @() {
  watch = textWatch
  rendObj = ROBJ_TEXT
  text = textWatch.get()
  color = white
  font = Fonts.small_accented_text_hud
}

let smallText = @(textWatch) @() {
  watch = textWatch
  rendObj = ROBJ_TEXT
  text = textWatch.get()
  color = inactiveHudColor
  font = Fonts.very_tiny_text_hud
}

let smallTextFixed = @(text) {
  rendObj = ROBJ_TEXT
  text
  color = inactiveHudColor
  font = Fonts.very_tiny_text_hud
}

function fireModeChildren() {
  let fireModesList = Computed(@() humanCurGunInfo.get()?.firingModesList ?? [])
  let fireMode = Computed(@() humanCurGunInfo.get()?.firingMode)
  return @() fireModesList.get().len() <= 1 ? { watch = fireModesList } : {
    watch = [ fireModesList, fireMode ]
    vplace = ALIGN_BOTTOM
    margin = const [0, 0, hdpxi(2), hdpxi(4)]
    children = smallTextFixed(loc($"weapon_menu/fire_mods/{fireMode.get()}"))
  }
}

function mkWeaponAmmo(ammoWatch, ammoTotalWatch, addChildrenFunc) {
  return @() {
    watch = [ammoWatch, ammoTotalWatch]
    flow = FLOW_HORIZONTAL
    vplace = ALIGN_CENTER
    hplace = ALIGN_RIGHT
    margin = [ 0, weaponBlockPadding, 0, 0 ]
    children = [
      bigText(ammoWatch)
      bigText(Watched("/"))
      bigText(ammoTotalWatch)
      addChildrenFunc
    ]
  }
}

function mkWeaponSecondaryAmmo(ammoWatch, ammoTotalWatch, addChildrenFunc) {
  return @() {
    watch = [ammoWatch, ammoTotalWatch]
    flow = FLOW_HORIZONTAL
    vplace = ALIGN_CENTER
    hplace = ALIGN_RIGHT
    margin = [ 0, weaponBlockPadding, 0, 0 ]
    children = [
      smallText(ammoWatch)
      smallTextFixed("/")
      smallText(ammoTotalWatch)
      addChildrenFunc
    ]
  }
}


return function() {
  let curGunMod = Computed(@() humanCurGunModeInfo.get()?.modWeapon)
  let isModActive = Computed(@() curGunMod.get()?.isModActive ?? false)
  let haveAmmo = Computed(@() humanCurGunStaticInfo.get()?.haveAmmo ?? false)
  let curWeaponAmmo = Computed(@() humanCurGunInfo.get()?.curAmmo ?? 0)
  let curWeaponTotalAmmo = Computed(@() humanCurGunInfo.get()?.totalAmmo ?? 0)
  let curWeaponAltAmmo = Computed(@() curGunMod.get()?.modCurAmmo ?? 0)
  let curWeaponAltTotalAmmo = Computed(@() curGunMod.get()?.modTotalAmmo ?? 0)

  return {
    size = [ heroStateWidth, actionBarItemHeight ]
    children = [
      hudBlurPanel
      @() {
        watch = [ isModActive, curGunMod, haveAmmo ]
        size = flex()
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = [
          {
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            children = [
              mkWeaponImage
              bigText(coolDownTime)
            ]
          }
          !haveAmmo.get() ? null : isModActive.get()
            ? mkWeaponAmmo(curWeaponAltAmmo, curWeaponAltTotalAmmo, mkAmmoTypeImage(true))
            : mkWeaponAmmo(curWeaponAmmo, curWeaponTotalAmmo, fireModeChildren())
          curGunMod.get() == null ? null : isModActive.get()
            ? mkWeaponSecondaryAmmo(curWeaponAmmo, curWeaponTotalAmmo, fireModeChildren())
            : mkWeaponSecondaryAmmo(curWeaponAltAmmo, curWeaponAltTotalAmmo, mkAmmoTypeImage(false))
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
}
