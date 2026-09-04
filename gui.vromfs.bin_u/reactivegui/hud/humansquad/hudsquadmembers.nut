import "%rGui/hints/hints.nut" as hints
import "%globalScripts/iconRender/icon3dByGameTemplate.nut" as icon3dByGameTemplate
import "%globalScripts/iconRender/forceRealTimeRenderIcon.nut" as forceRealTimeRenderIcon
import "%sqstd/ecs.nut" as ecs
from "%rGui/hud/humanSquad/humanSquadState.nut" import isPersonalContextCommandMode, watchedHeroSquadMembersGetWatched, watchedHeroSquadMembersOrderedSet
from "%appGlobals/hudSquadMembers.nut" import selectedBotForOrderEid, watchedHeroSquadMembers, hudSquadBlockCollapsed
from "%rGui/hud/state/controlledHeroEid.nut" import controlledHeroEid
from "%rGui/hudState.nut" import isSpectatorMode
from "%rGui/hud/humanSquad/hudSquadMemberIcons.nut" import mkMineIcon, mkStatusIcon
from "%rGui/hud/humanSquad/humanSquadFormation.nut" import squadFormation, SquadFormationSpreadEnum
from "%rGui/hud/humanSquad/humanSquadBehaviour.nut" import squadBehaviour, SquadBehaviourEnum
from "%rGui/hud/humanSquad/grenadeIcon.nut" import mkGrenadeIcon
from "%rGui/style/colors.nut" import white, hudSquadBgColor, attackWarningColor, transparent, attackWarningColor2, attackWarningColor3
from "%rGui/hud/humanSquad/humanEnums.nut" import ATTACK_RES
from "%rGui/style/const.nut" import humanSquadSingleItemWidth, squadMemberGap
from "console" import register_command
from "eventbus" import eventbus_subscribe
from "controls" import emulateShortcut
from "dagor.math" import Color4
from "%rGui/globals/ui_library.nut" import *

let { hud } = require("%rGui/style/colors.nut")
let { infantryShortcutCommonColor, infantryShortcutCommonTextColor } = hud
let { hudBlurPanel } = require("%rGui/components/blurPanel.nut")

const EWS_TERTIARY = 2

const ANIM_SQUAD_BLOCK_SHOW_ID = "anim_squad_block_show"
const ANIM_SQUAD_BLOCK_HIDE_ID = "anim_squad_block_hide"
let isAnimSquadBlockFinished = Watched(false)
let isSquadBlockHidden = Computed(@() hudSquadBlockCollapsed.get() && isAnimSquadBlockFinished.get())

let membersAnimations = [
  { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.2, trigger = ANIM_SQUAD_BLOCK_HIDE_ID,
    easing=Linear, onFinish = @() isAnimSquadBlockFinished.set(true),
    onEnter = @() isAnimSquadBlockFinished.set(false) }
  { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.2, trigger = ANIM_SQUAD_BLOCK_SHOW_ID,
    easing=Linear, onFinish = @() isAnimSquadBlockFinished.set(true),
    onEnter = @() isAnimSquadBlockFinished.set(false) }
]

let overrideItemIcon = {
  armor_box_item ="ui/gameuiskin#human_armor_box.svg:36:36:K"
  ammo_box_item ="ui/gameuiskin#human_ammo_box.svg:36:36:K"
  explosives_box_item ="ui/gameuiskin#human_explosives_box.svg:36:36:K"
  medic_box_item ="ui/gameuiskin#human_med_box.svg:36:36:K"
}


const collapseIconWidth = hdpx(8)
const collapseIconHeight = hdpx(14)

let collapseIcon = Picture(
  $"ui/gameuiskin#icon_collapse_action_bar.svg:{collapseIconWidth}:{collapseIconHeight}")

const miniPadding = hdpxi(2)
const smallPadding = hdpxi(4)
const sIconSize = evenPx(24)
const iconSize = evenPx(36)
const squadStatusIconSize = evenPx(26)
const personalOrderMarkerSize = evenPx(12)
const memberMarkerSize = evenPx(18)
const selectedMemberMarkerSize = evenPx(20)

const markerOffset = memberMarkerSize/2

const lineWidth = hdpxi(2)

const memberBlockHeight = evenPx(60) + memberMarkerSize
let memberBlockSize = [humanSquadSingleItemWidth, memberBlockHeight]
let tertiaryWeaponSize = [ humanSquadSingleItemWidth - 2*smallPadding, humanSquadSingleItemWidth - 2*smallPadding ]
const memberMarkerBlockSize = [memberMarkerSize, memberMarkerSize]
const selectedMemberMarkerBlockSize = [selectedMemberMarkerSize, selectedMemberMarkerSize]

const equipmentStatusRowDummy = { size = const [sIconSize, sIconSize] }

const memberIconLightColor = 0xFFd2d2d1

let whiteColor4 = Color4(255,255,255,255)

let personalOrderMarker = freeze({
  size = const [memberMarkerSize, memberMarkerSize]
  rendObj = ROBJ_VECTOR_CANVAS
  fillColor = hudSquadBgColor
  color = transparent
  commands = [[VECTOR_ELLIPSE, 50, 50, 50, 50]]
  children = {
    size = const [personalOrderMarkerSize, personalOrderMarkerSize]
    rendObj = ROBJ_IMAGE
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    image = Picture($"ui/gameuiskin#icon_order_set.svg:{personalOrderMarkerSize}:{personalOrderMarkerSize}:P")
    color = memberIconLightColor
  }
})

let memberSelfMarker = freeze({
  size = const [memberMarkerSize, memberMarkerSize]
  rendObj = ROBJ_IMAGE
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  image = Picture($"ui/gameuiskin#infantry_in_control.svg:{memberMarkerSize}:{memberMarkerSize}:P")
  color = memberIconLightColor
})

let memberMarker = @(memberIdx, isSelectedForOrder) isSelectedForOrder
  ? freeze({
    size = selectedMemberMarkerBlockSize
    rendObj = ROBJ_IMAGE
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    image = Picture($"ui/gameuiskin#infantry_{memberIdx}_selected.svg:{selectedMemberMarkerBlockSize[0]}:{selectedMemberMarkerBlockSize[1]}:P")
    color = memberIconLightColor
  })
  : freeze({
    size = memberMarkerBlockSize
    rendObj = ROBJ_IMAGE
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    image = Picture($"ui/gameuiskin#infantry_{memberIdx}.svg:{memberMarkerBlockSize[0]}:{memberMarkerBlockSize[1]}:P")
    color = memberIconLightColor
  })


let emptySlotIcon = freeze({
  rendObj = ROBJ_IMAGE
  size = const [sIconSize, sIconSize]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  color = memberIconLightColor
  image = Picture($"ui/gameuiskin#weapon_icon.svg:{sIconSize}:{sIconSize}:P")
})


let animByTrigger = @(color, time, trigger) trigger
  ? { prop=AnimProp.color, from=0, to=color, easing=CosineFull, duration=time, trigger=trigger }
  : null

function mkAiAction(member, blockSize) {
  if (member.eid == controlledHeroEid.get() || !member.isAlive || !member.hasAI)
    return null

  return {
    size = blockSize
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      {
        size = FLEX
        rendObj = ROBJ_FRAME
        borderWidth = lineWidth
        color = 0

        animations = [
          animByTrigger(attackWarningColor, 1.0, member.hitTriggers?[ATTACK_RES])
        ]
      }
      {
        size = [blockSize[0] + hdpxi(4), blockSize[1] + hdpxi(4)]
        rendObj = ROBJ_FRAME
        borderWidth = hdpxi(1)
        color = 0

        animations = [
          animByTrigger(attackWarningColor2, 1.0, member.hitTriggers?[ATTACK_RES])
        ]
      }
      {
        size = [blockSize[0] + hdpxi(8), blockSize[1] + hdpxi(8)]
        rendObj = ROBJ_FRAME
        borderWidth = hdpxi(1)
        color = 0
        animations = [
          animByTrigger(attackWarningColor3, 1.0, member.hitTriggers?[ATTACK_RES])
        ]
      }
    ]
  }
}

let mkTertiaryImg = @(imagePic, color) {
  size = tertiaryWeaponSize
  rendObj = ROBJ_IMAGE
  color
  keepAspect = KEEP_ASPECT_FIT
  image = Picture(imagePic)
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
}

let mkOverrideTertiaryImg = @(imagePic, color) {
  size = [evenPx(30), evenPx(30)]
  rendObj = ROBJ_IMAGE
  color
  keepAspect = KEEP_ASPECT_FIT
  image = Picture(imagePic)
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
}

let selfBorder = [
  [VECTOR_LINE, 0, 0, 0, 100],
  [VECTOR_LINE, 0, 100, 100, 100],
  [VECTOR_LINE, 100, 100, 100, 0],
  [VECTOR_LINE, 100, 0, 80, 0],
  [VECTOR_LINE, 20, 0, 0, 0]
]

let memberUi = memoize(function(eid) {
  let state = watchedHeroSquadMembersGetWatched(eid)

  return function() {
    let member = state.get()
    if (member == null)
      return { watch = state }

    let { isAlive, hasAI, grenadeType = null, isPersonalOrder = null,
      memberIdx = -1, weapTemplates = {}, gunEidsList = [] } = member

    let grenadeT = grenadeType == null || grenadeType == "wall_bomb" ? null : grenadeType
    let isSelf = eid == controlledHeroEid.get()
    let isAliveAI = !isSelf && isAlive && hasAI
    let isSelectedForOrder = isPersonalContextCommandMode.get()
      && (isAliveAI && eid == selectedBotForOrderEid.get())

    let iconColor = isSelectedForOrder ? white : memberIconLightColor
    let tertiaryGunEid = gunEidsList?[EWS_TERTIARY] ?? ecs.INVALID_ENTITY_ID
    let weapTemplate = weapTemplates?.tertiary ?? ""
    let tertImage = weapTemplate != "" && tertiaryGunEid != ecs.INVALID_ENTITY_ID
      ? overrideItemIcon?[weapTemplate]
        ? mkOverrideTertiaryImg(
            overrideItemIcon[weapTemplate],
            iconColor)
        : mkTertiaryImg(icon3dByGameTemplate(weapTemplate, {
            width = tertiaryWeaponSize[0]
            height = tertiaryWeaponSize[1]
            silhouetteColor = whiteColor4
            forceRealTimeRenderIcon = forceRealTimeRenderIcon.get()
            renderSettingsPlace = "hud_squad_manager"
          }), iconColor)
      : emptySlotIcon

    return {
      watch = [selectedBotForOrderEid, controlledHeroEid, isPersonalContextCommandMode,
        state, forceRealTimeRenderIcon]
      size = SIZE_TO_CONTENT
      vplace = ALIGN_BOTTOM
      children = [
        {
          size = memberBlockSize
          rendObj = ROBJ_SOLID
          behavior = isAlive && !isSelf ? Behaviors.Button : null
          color = transparent

          function onClick(_evt) {
            emulateShortcut($"ID_CREW_SWITCH_CONTROL_ON_SOLDIER_{memberIdx+1}")
          }

          children = [
            hudBlurPanel
            mkAiAction(member, memberBlockSize)
            isSelf ? {
              size = FLEX
              rendObj = ROBJ_VECTOR_CANVAS
              lineWidth
              color = memberIconLightColor
              fillColor = transparent
              commands = selfBorder
            } : null
            mkStatusIcon(member, iconSize)
            !isAlive ? null : {
              flow = FLOW_VERTICAL
              size = FLEX
              margin = smallPadding
              gap = miniPadding
              halign = ALIGN_CENTER
              children = [
                {
                  size = FLEX_V
                  children = tertImage
                }
                {
                  size = const [SIZE_TO_CONTENT, sIconSize]
                  children = isAliveAI || isSelf
                      ? (mkGrenadeIcon(grenadeT, sIconSize, iconColor)
                        ?? mkMineIcon(member, sIconSize, iconColor) )
                      : equipmentStatusRowDummy
                }
              ]
            }
          ]
        }
        isAlive ? {
          size = const [ FLEX, memberMarkerSize ]
          pos = const [ 0, -markerOffset ]
          valign = ALIGN_CENTER
          children = [
            {
              hplace = ALIGN_RIGHT
              children = isPersonalOrder ? personalOrderMarker : null
            }
            {
              hplace = ALIGN_CENTER
              children = isSelf ? memberSelfMarker : memberMarker(memberIdx+1, isSelectedForOrder)
            }
          ]
        } : null
      ]
    }
  }
})

let squadMembersList = @() {
  watch = [ watchedHeroSquadMembersOrderedSet, hudSquadBlockCollapsed, isSquadBlockHidden ]
  flow = FLOW_HORIZONTAL
  gap = squadMemberGap
  size = [ SIZE_TO_CONTENT, memberBlockSize[1] ]
  opacity = hudSquadBlockCollapsed.get() ? 0 : 1
  animations = membersAnimations
  children = isSquadBlockHidden.get() ? null
    : watchedHeroSquadMembersOrderedSet.get().map(memberUi)
}

let mkSquadStatusIcon = @(icon) {
  hplace = ALIGN_CENTER
  rendObj = ROBJ_IMAGE
  size = const [squadStatusIconSize, squadStatusIconSize]
  image = Picture($"{icon}:{squadStatusIconSize}:{squadStatusIconSize}:P")
}

let squadFormationIcons = {
  [SquadFormationSpreadEnum.ESFN_CLOSEST] = mkSquadStatusIcon("ui/gameuiskin#squad_formation_closest.svg"),
  [SquadFormationSpreadEnum.ESFN_WIDE] = mkSquadStatusIcon("ui/gameuiskin#squad_formation_wide.svg")
}

let squadBehaviourIcons = {
  [SquadBehaviourEnum.ESB_PASSIVE] = mkSquadStatusIcon("ui/gameuiskin#squad_behaviour_passive.svg")
}

let squadStatus = @() {
  watch = [squadFormation, squadBehaviour, hudSquadBlockCollapsed, isSquadBlockHidden]
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  gap = smallPadding
  opacity = hudSquadBlockCollapsed.get() ? 0 : 1
  animations = membersAnimations
  children = isSquadBlockHidden.get() ? null : [
    squadFormationIcons?[squadFormation.get()]
    squadBehaviourIcons?[squadBehaviour.get()]
  ]
}


let shadow = {
  fontFx = FFT_GLOW
  fontFxFactor = hdpx(64)
  fontFxColor = 0xFF000000
}

function getShortcutText(text, addChildren = []) {
  let config = hints(
    text,
    {
      font = Fonts.tiny_text_hud
      fontSize = getFontDefHt("tiny_text_hud")
      place = "actionItemInfantry"
      bgImageColor = infantryShortcutCommonColor
      shColor = infantryShortcutCommonTextColor
    }.__update(shadow),
    addChildren)
  return config
}


let doNotShowMembers = Computed(@()
  watchedHeroSquadMembersOrderedSet.get().len() <= 1 || isSpectatorMode.get())

function onCollapseHumanSquadBtnPressed() {
  hudSquadBlockCollapsed.set(!hudSquadBlockCollapsed.get())
  anim_start(hudSquadBlockCollapsed.get() ? ANIM_SQUAD_BLOCK_HIDE_ID : ANIM_SQUAD_BLOCK_SHOW_ID)
}

eventbus_subscribe("onCollapseHumanSquadBtn",
  @(v) v?.isKeyDown == false ? onCollapseHumanSquadBtnPressed() : null)

let collapseIconComp = @() {
  watch = hudSquadBlockCollapsed
  rendObj = ROBJ_IMAGE
  size = const [collapseIconWidth, collapseIconHeight]
  image = collapseIcon
  transform = {
    rotate = hudSquadBlockCollapsed.get() ? 90 : 270
  }
}

let collapseButton = @() {
  rendObj = ROBJ_BOX
  flow = FLOW_HORIZONTAL
  gap = smallPadding
  valign = ALIGN_CENTER
  behavior = Behaviors.Button
  onClick = onCollapseHumanSquadBtnPressed
  children = [
    getShortcutText("{{ID_CHANGE_HUMAN_SQUAD_VISIBILITY}} ")
    collapseIconComp
  ]
}

let mkUnitControlHelp = @() getShortcutText(
  "{{ID_HELP}} {0}".subst(loc("hotkeys/ID_HELP"))
)

let members = {
  size = const [ SIZE_TO_CONTENT, shHud(3) + memberBlockHeight]
  flow = FLOW_VERTICAL
  halign = ALIGN_LEFT
  gap = smallPadding
  children = [
    squadStatus
    squadMembersList
    @() {
      watch = [ hudSquadBlockCollapsed, isSquadBlockHidden ]
      opacity = hudSquadBlockCollapsed.get() ? 0 : 1
      animations = membersAnimations
      flow = FLOW_VERTICAL
      children = isSquadBlockHidden.get() ? null : [
        { size = const [SIZE_TO_CONTENT, markerOffset] }
        mkUnitControlHelp()
      ]
    }
  ]
}

let squadBlock = @() doNotShowMembers.get() ? { watch = doNotShowMembers} : {
  watch = doNotShowMembers
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  halign = ALIGN_LEFT
  gap = memberMarkerSize
  children = [
    collapseButton
    members
  ]
}

register_command(function(hitr) {
  let trigger = watchedHeroSquadMembers.get()?.top().hitTriggers[hitr]
  if (trigger != null)
    anim_start(trigger)
}, "hud.debugHitMember")

return squadBlock