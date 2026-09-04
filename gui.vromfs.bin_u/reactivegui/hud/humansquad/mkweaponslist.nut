import "%globalScripts/iconRender/icon3dByGameTemplate.nut" as icon3dByGameTemplate
import "%globalScripts/iconRender/forceRealTimeRenderIcon.nut" as forceRealTimeRenderIcon
import "%rGui/hints/hints.nut" as hints
import "%sqstd/ecs.nut" as ecs
from "%rGui/hud/humanSquad/humanConst.nut" import heroStateWidth, hpBarHeight, weaponBlockGap
from "%rGui/hud/state/human_gun_info_es.nut" import humanCurGunSlotIdx, WEAPON_SLOTS, heroModsByWeaponSlot, isWeaponsListVisible, humanCurGunModeInfo
from "%rGui/style/colors.nut" import white
from "%rGui/hud/state/watched_hero.nut" import watchedHeroEid
from "dagor.math" import Color4
from "dasevents" import CmdUIShowWeaponsBlock
from "%rGui/globals/ui_library.nut" import *

let { hudBlurPanel } = require("%rGui/components/blurPanel.nut")
let { weaponSlotsStatic, weaponSlots } = require("%rGui/hud/state/human_gun_info_es.nut")
let { hud } = require("%rGui/style/colors.nut")
let { infantryHudInactiveColor, infantryShortcutCommonColor,
  infantryShortcutDisableColor, infantryShortcutCommonTextColor, infantryShortcutDisableTextColor
} = hud

let overrideImageSize = [shHud(2), shHud(2)]
let weaponBlockSize = [ heroStateWidth, shHud(3) ]
let weaponRenderImageSize = [shHud(12) - evenPx(4), shHud(3.5)]
let weaponImageSize = [shHud(3), shHud(1)]

let weaponBorderWidth = evenPx(2)
let weaponBlockPadding = const [0, evenPx(4), 0, evenPx(6)]
let weaponSlotGap = evenPx(2)
let weaponsBlockExternalBottomPadding = [0, 0, weaponBlockGap + hpBarHeight, 0]

let whiteColor4 = Color4(255,255,255,255)


let overrideItemIcon = {
  armor_box_item = $"ui/gameuiskin#human_armor_box.svg:{overrideImageSize[1]}:{overrideImageSize[1]}:P"
  ammo_box_item = $"ui/gameuiskin#human_ammo_box.svg:{overrideImageSize[1]}:{overrideImageSize[1]}:P"
  explosives_box_item = $"ui/gameuiskin#human_explosives_box.svg:{overrideImageSize[1]}:{overrideImageSize[1]}:P"
  medic_box_item = $"ui/gameuiskin#human_med_box.svg:{overrideImageSize[1]}:{overrideImageSize[1]}:P"
  grenade_launcher = $"ui/gameuiskin#icon_rifle_grenade.svg:{overrideImageSize[1]}:{overrideImageSize[1]}:P"
}


const WEAPONS_LIST_ANIM_START_APPEAR = "weapons_list_anim_start_appear"
const WEAPONS_LIST_ANIM_EXTEND = "weapons_list_anim_extend"
const WEAPONS_LIST_ANIM_HIDE = "weapons_list_anim_hide"
const changeOpacityAnimTime = 0.2
const delayAnimTime = 3.0
let mkAnimations = [
  { prop=AnimProp.opacity, to=1, duration=changeOpacityAnimTime, playFadeOut = true,
    trigger = WEAPONS_LIST_ANIM_START_APPEAR, onStart = @() isWeaponsListVisible.set(true),
    onFinish = @() anim_start(WEAPONS_LIST_ANIM_EXTEND)
  },
  { prop=AnimProp.opacity, from=1, to=1, duration=delayAnimTime, playFadeOut = true,
    trigger = WEAPONS_LIST_ANIM_EXTEND, onFinish = @() anim_start(WEAPONS_LIST_ANIM_HIDE)
  },
  { prop=AnimProp.opacity, from=1, to=0, duration=changeOpacityAnimTime, playFadeOut = true,
    trigger = WEAPONS_LIST_ANIM_HIDE, onFinish = @() isWeaponsListVisible.set(false)
  }
]

let startWeaponsListAnim = function() {
  if (isWeaponsListVisible.get())
    anim_start(WEAPONS_LIST_ANIM_EXTEND)
  else
    anim_start(WEAPONS_LIST_ANIM_START_APPEAR)
}

humanCurGunSlotIdx.subscribe(@(v) v < 0 ? null : startWeaponsListAnim())
watchedHeroEid.subscribe(@(v) v == ecs.INVALID_ENTITY_ID
  ? null
  : startWeaponsListAnim()
)

ecs.register_es("ui_show_weapons_block", {
  [CmdUIShowWeaponsBlock] = @(_evt, _eid) startWeaponsListAnim()
},{})

let weaponModState = keepref(Computed(@() humanCurGunModeInfo.get()?.modWeapon.isModActive))
weaponModState.subscribe(@(v) v == null ? null : startWeaponsListAnim())

let weaponShortcut = {
  [0] = "{{ID_HUMAN_MAIN_WEAPON}}",
  [1] = "{{ID_HUMAN_PISTOL}}",
  [2] = "{{ID_HUMAN_SPECIAL_1}}",
  [3] = "{{ID_HUMAN_MELEE}}",
  [5] = "{{ID_HUMAN_SPECIAL_1}}"
}

let getShortcutText = @(text, isEnabled, fallback = null) text != null ? hints(text, {
  place = "actionItemInfantry"
  bgImageColor = isEnabled ? infantryShortcutCommonColor : infantryShortcutDisableColor
  shColor = isEnabled ? infantryShortcutCommonTextColor : infantryShortcutDisableTextColor
  fallback
}) : fallback

let mkWeaponImage = @(iconTemplateWatch, isSelectedWatch) function() {
  if (iconTemplateWatch.get() == null)
    return { watch = iconTemplateWatch }

  if (iconTemplateWatch.get() in overrideItemIcon)
    return {
      watch = [ isSelectedWatch, iconTemplateWatch ]
      size = [ overrideImageSize[1], overrideImageSize[1] ]
      rendObj = ROBJ_IMAGE
      image = Picture(overrideItemIcon[iconTemplateWatch.get()])
      color = isSelectedWatch.get() ? white : infantryHudInactiveColor
    }

  return {
    watch = [ forceRealTimeRenderIcon, isSelectedWatch, iconTemplateWatch ]
    size = weaponImageSize
    rendObj = ROBJ_IMAGE
    color = isSelectedWatch.get() ? white : infantryHudInactiveColor
    image = Picture(icon3dByGameTemplate(iconTemplateWatch.get(), {
      width = weaponRenderImageSize[0]
      height = weaponRenderImageSize[1]
      silhouetteColor = whiteColor4
      forceRealTimeRenderIcon = forceRealTimeRenderIcon.get()
      renderSettingsPlace = "hud_action_bar"
      
    }))
  }
}

let bigText = @(text, color = white) {
  rendObj = ROBJ_TEXT
  text
  color
  font = Fonts.very_tiny_text_hud
}

let mkWeaponAmmo = @(ammoWatch, totalAmmoWatch, weaponStaticInfoWatch, isSelected) function() {
  if (!(weaponStaticInfoWatch.get()?.haveAmmo ?? false))
    return { watch = [weaponStaticInfoWatch] }

  return {
    watch = [ammoWatch, totalAmmoWatch, weaponStaticInfoWatch]
    flow = FLOW_HORIZONTAL
    vplace = ALIGN_CENTER
    hplace = ALIGN_RIGHT
    children = [
      bigText(ammoWatch.get(), isSelected ? white : infantryHudInactiveColor)
      bigText("/", infantryHudInactiveColor)
      bigText(totalAmmoWatch.get(), infantryHudInactiveColor)
    ]
  }
}

function mkSlotRow(slotIdx, weaponImage, weapInfo, weaponStaticInfoWatch, isSelected, isMod = false) {
  let ammo = isMod ? Computed(@() weapInfo.get()?.modCurAmmo ?? 0)
    : Computed(@() weapInfo.get()?.curAmmo ?? 0)
  let ammoTotal = isMod ? Computed(@() weapInfo.get()?.modTotalAmmo ?? 0)
    : Computed(@() weapInfo.get()?.totalAmmo ?? 0)
  return {
    size = FLEX
    children = [
      isSelected
      ? {
        rendObj = ROBJ_SOLID
        size = [weaponBorderWidth, FLEX]
        pos = [-weaponBorderWidth, 0]
        color = white
      }
      : null
      {
        size = FLEX
        padding = weaponBlockPadding
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        gap = weaponSlotGap
        children = [
          isMod
            
            
            ? getShortcutText("{{ID_HUMAN_WEAP_MOD_TOGGLE}}", isSelected,
                @() { children = getShortcutText(weaponShortcut?[slotIdx], isSelected) })
            : getShortcutText(weaponShortcut?[slotIdx], isSelected)
          {
            size = FLEX
            children = {
              size = [weaponImageSize[0] + weaponBlockPadding[3], FLEX]
              valign = ALIGN_CENTER
              halign = ALIGN_CENTER
              children = weaponImage
            }
          }
          mkWeaponAmmo(ammo, ammoTotal, weaponStaticInfoWatch, isSelected)
        ]
      }
    ]
  }
}

let mkSlot = function(weaponStaticInfoWatch, slotIdx) {
  if (slotIdx == WEAPON_SLOTS.EWS_GRENADE || slotIdx == WEAPON_SLOTS.EWS_SPECIAL)
    return null

  let slotGunMod = Computed(@() heroModsByWeaponSlot.get()?[slotIdx].modWeapon)
  let isModWeapon = Computed(@() slotGunMod.get()?.isWeapon ?? false)
  let isModActive = Computed(@() slotGunMod.get()?.isModActive ?? false)
  let isSelectedMod = Computed(@() humanCurGunSlotIdx.get() == slotIdx && isModActive.get())
  let specialSlot = weaponSlots[WEAPON_SLOTS.EWS_SPECIAL]
  let launcherEidWatch = Computed(@() specialSlot.get()?.launcherEid ?? ecs.INVALID_ENTITY_ID)

  let isSelected = Computed(function() {
    if (isModActive.get())
      return false
    let curSlot = humanCurGunSlotIdx.get()
    let isDroneRow = slotIdx == WEAPON_SLOTS.EWS_TERTIARY && launcherEidWatch.get() != ecs.INVALID_ENTITY_ID
    if (isDroneRow)
      return curSlot == WEAPON_SLOTS.EWS_TERTIARY || curSlot == WEAPON_SLOTS.EWS_SPECIAL
    return curSlot == slotIdx
  })

  let mainWeaponInfo = weaponSlots[slotIdx]
  let iconTemplateWatch = Computed(@() weaponStaticInfoWatch.get()?.iconTemplate)
  let weaponModTemplateWatch = Computed(@() slotGunMod.get()?.attachedItemModSlotName)

  return function() {
    let weaponImage = mkWeaponImage(iconTemplateWatch, isSelected)

    let children = [@() {
      watch = [ isSelected ]
      size = weaponBlockSize
      children = [
        hudBlurPanel
        mkSlotRow(slotIdx, weaponImage, mainWeaponInfo, weaponStaticInfoWatch, isSelected.get())
      ]
    }]

    if (isModWeapon.get()) {
      let modImage = mkWeaponImage(weaponModTemplateWatch, isSelectedMod)
      children.append(@() {
        watch = [ isSelectedMod, slotGunMod ]
        size = weaponBlockSize
        children = [
          hudBlurPanel
          mkSlotRow(slotIdx, modImage, slotGunMod, weaponStaticInfoWatch, isSelectedMod.get(), true)
        ]
      })
    }

    return {
      watch = isModWeapon
      flow = FLOW_VERTICAL
      gap = weaponSlotGap
      children
    }
  }
}

return {
  vplace = ALIGN_BOTTOM
  flow = FLOW_VERTICAL
  opacity = 0
  animations = mkAnimations
  padding = weaponsBlockExternalBottomPadding
  gap = weaponSlotGap
  children = weaponSlotsStatic.map(mkSlot)
}