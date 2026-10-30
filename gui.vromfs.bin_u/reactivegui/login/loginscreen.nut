from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px, constText, roundPx
from "%rGui/components/commonBg.nut" import commonBg
from "%rGui/components/text.nut" import mkText
from "%rGui/components/checkbox.nut" import mkFormCheckbox
from "%rGui/components/wndFrame.nut" import closeButton
import "%rGui/components/comboBox.nut" as comboBox
import "%rGui/components/editBox.nut" as editBox
import "%rGui/components/navButtons.nut" as mkNavButtons
from "%rGui/ctrlsState.nut" import showConsoleButtons
from "%rGui/components/gamepadImgByKey.nut" import mkImageCompByDargKey
import "%appGlobals/style/cssColorToInt.nut" as cssColorToInt
from "%appGlobals/login/loginScreenState.nut" import loginScreen, loginItemW, setLoginItem, isShownItem,
  HIDDEN_BY_DEFAULT
from "eventbus" import eventbus_send
from "sound_wt" import playSound
from "math" import floor
from "%sqstd/platform.nut" import is_steam_deck
from "guiScriptUtils" import is_steam_big_picture
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors



const SHADE_COLOR = 0x91020509
const RED_LIGHT_COLOR = 0x00550000
const BATTLE_BTN_COLOR = 0xFFFFB867
const BATTLE_BTN_DISABLED_COLOR = 0xFFFF1414
const BATTLE_WINK_COLOR = 0x00FF1414
const BATTLE_GLANCE_COLOR = 0x000F0D08
const BATTLE_GLANCE_DISABLED_COLOR = 0x2B220E0E
const COMPANY_LOGO_SHADE_COLOR = 0x80000000
const HELP_LINE_COLOR = 0xFFFFFFFF
const PATTERN_TILE = 32

let fontNormal = fontsState.get("normal")
let fontSmall = fontsState.get("small")
let fontNormalBold = fontsState.get("normalBold")

let pct = @(size, percent) roundPx(size * percent / 100.0)
let centerPos = @(outer, inner) roundPx((outer - inner) / 2.0)

let screenW = px("sw")
let screenH = px("sh")
let bwPx = cssConst("bw")
let bhPx = cssConst("bh")
let topBarH = cssConst("topBarHeight")
let bottomBarH = cssConst("bottomBarHeight")
let bottomPanelH = cssConst("bottomMenuPanelHeight")
let blockInterval = cssConst("blockInterval")
let framePadding = cssConst("framePadding")
let btnH = cssConst("navBarBattleButtonHeight")
let btnImgPadding = cssConst("buttonImgPadding")
let btnTextPadding = cssConst("buttonTextPadding")
let hintSize = cssConst("cIco")
let lineW = px("(@sf/@pf) $max 1")
let editH = px("@cIco + 2@buttonImgPadding")

let colX = px("@bw + 10%@rw")
let colW = px("0.35*@sf")
let plateW = pct(colW, 90)
let plateX = centerPos(colW, plateW)
let logoPlateH = pct(screenH, 20)
let mainH = pct(screenH, 65)
let mainPadX = px("4@dp")
let mainInnerW = plateW - 2 * mainPadX - 2 * blockInterval
let formW = mainInnerW - px("0.03@scrn_tgt")
let innerX = colX + plateX + mainPadX + blockInterval
let formX = innerX + centerPos(mainInnerW, formW)
let helpX = colX + colW + px("70@sf/@pf")
let helpW = px("400@sf/@pf")
let logoScale = cssConst("loginLogoScale")
let shadePadW = cssConst("titleLogoShadePaddingW")
let shadePadH = cssConst("titleLogoShadePaddingH")
let normalTextH = calc_str_box("A", { font = fontNormal })[1]

let styleW = Computed(@() loginScreen.get().style)
let isOpenedW = Computed(@() loginScreen.get().isExistingAccountOpened)
let isHelpShownW = Computed(@() loginScreen.get().isHelpShown)
let shardItemsW = Computed(@() loginScreen.get().shardItems)
let langsW = Computed(@() loginScreen.get().langs)
let versionTextW = Computed(@() loginScreen.get().versionText)
let copyrightTextW = Computed(@() loginScreen.get().copyrightText)
let titleLogoW = Computed(@() loginScreen.get().titleLogo)
let focusSeqW = keepref(Computed(@() loginScreen.get().focusSeq))

let sendAction = @(action, params = {}) eventbus_send("loginScreen.action", params.__merge({ action }))

function changeValue(id, value) {
  setLoginItem(id, "value", value)
  sendAction("changed", { id })
}

let withBg = @(bg, content, ovr = {}) { children = [].extend(commonBg(bg), [content]) }.__update(ovr)

let mkPattern = @(image, size, ovr = {}) {
  size
  children = commonBg({ image, repeat = "repeat", position = "1,2", tile = PATTERN_TILE, size })
}.__update(ovr)

function mkPlate(w, h, content) {
  let redW = w - 2 * shadePadW
  let redH = h - 2 * shadePadH
  let patternSize = [redW - 2 * shadePadW, redH - 2 * shadePadH]
  let pattern = mkPattern("#ui/gameuiskin#pattern_dark_diag_lines", patternSize, { pos = [shadePadW, shadePadH] })
  pattern.children.append(content(patternSize))
  return {
    size = [w, h]
    children = [].extend(commonBg({ image = "#ui/gameuiskin#window_body_shadow", repeat = "expand", position = "6" }), [{
      pos = [shadePadW, shadePadH]
      size = [redW, redH]
      children = [].extend(commonBg({ image = "#ui/gameuiskin#red_plate", repeat = "expand", position = "6" }), [pattern])
    }])
  }
}

let mkUnderline = @(color) { size = [flex(), lineW], vplace = ALIGN_BOTTOM, rendObj = ROBJ_SOLID, color }

function mkLink(id, text, action) {
  let sf = Watched(0)
  let item = loginItemW(id)
  return @() {
    watch = [sf, item]
    children = !isShownItem(id, item.get()) ? null : {
      behavior = Behaviors.Button
      onElemState = @(s) sf.set(s)
      onClick = function() {
        playSound("click")
        sendAction(action)
      }
      children = [
        mkText(text, fontSmall, (sf.get() & S_ACTIVE) ? cssColors.pushedMenuButtonColor
          : (sf.get() & S_HOVER) ? cssColors.hoverMenuButtonColor
          : cssColors.commonMenuButtonColor)
        mkUnderline((sf.get() & S_HOVER) ? cssColors.hoverMenuButtonColor : cssColors.commonMenuButtonColor)
      ]
    }
  }
}

function battleButtonView(text, isEnabled, sf, size) {
  let [w, h] = size
  let isHover = isEnabled && (sf & S_HOVER) != 0
  let isPushed = isEnabled && (sf & S_ACTIVE) != 0
  let image = !isEnabled ? "#ui/gameuiskin#button_bright_normal"
    : isPushed ? "#ui/gameuiskin#button_bright_active"
    : isHover ? "#ui/gameuiskin#button_bright_hover"
    : "#ui/gameuiskin#button_bright_"
  return [].extend(
    commonBg({ image, repeat = "expand", position = "3, 7, 3, 7",
      bgcolor = isEnabled ? BATTLE_BTN_COLOR : BATTLE_BTN_DISABLED_COLOR }),
    [
      mkPattern("#ui/gameuiskin#pattern_bright_texture", size, { pos = [2, 2] })
      !isEnabled ? null : {
        size = flex()
        children = commonBg({ image = "#ui/gameuiskin#button_bright_glow", repeat = "expand",
          position = "3, 7, 3, 7", bgcolor = BATTLE_WINK_COLOR })
        animations = [{ prop = AnimProp.opacity, from = 1.0, to = 170 / 255.0, duration = 3.0,
          easing = CosineFull, loop = true, play = true }]
      }
      isEnabled
        ? { size = [w, pct(h, 60)], children = commonBg({ image = "#ui/gameuiskin#button_glance",
            repeat = "expand", position = "1", bgcolor = BATTLE_GLANCE_COLOR }) }
        : { pos = [2, 2], size = [w - 4, pct(h, 65) - 4], rendObj = ROBJ_SOLID, color = BATTLE_GLANCE_DISABLED_COLOR }
      mkText(text, fontNormalBold,
        !isEnabled ? cssColors.inactiveButtonTextColor
          : isPushed ? cssColors.pushedBattleButtonColor
          : isHover ? cssColors.hoverBattleButtonColor
          : cssColors.battleButtonColor,
        { hplace = ALIGN_CENTER, vplace = ALIGN_CENTER, fontFx = FFT_GLOW, fontFxColor = 0x55000000, fontFxFactor = 48 })
    ])
}

function plainButtonView(text, isEnabled, sf, size) {
  let [w, h] = size
  let isHover = isEnabled && (sf & S_HOVER) != 0
  let isPushed = isEnabled && (sf & S_ACTIVE) != 0
  let state = !isEnabled ? "Disabled" : isPushed ? "Pushed" : isHover ? "Hover" : ""
  return [].extend(
    commonBg({ bgcolor = cssColors[$"buttonColor{state}"], border = true, borderColor = cssColors[$"buttonBorderColor{state}"] }),
    [
      mkPattern("#ui/gameuiskin#pattern_bright_texture", [w - 2 * btnTextPadding, h - 2 * btnImgPadding],
        { pos = [btnTextPadding, btnImgPadding] })
      mkText(text, fontNormal, cssColors[$"buttonFontColor{state}"], { hplace = ALIGN_CENTER, vplace = ALIGN_CENTER })
    ])
}

let btnSize = [mainInnerW, btnH]

function mkStyledButton(id, text, action, isBattleFn, hotkey, ovr = {}) {
  let sf = Watched(0)
  let item = loginItemW(id)
  let hotkeys = [[$"^{hotkey}"]]
  let hintParams = { height = hintSize, vplace = ALIGN_CENTER, pos = [btnImgPadding, 0] }
  return @() {
    watch = [sf, item, styleW, isHelpShownW, showConsoleButtons]
    size = FLEX_H
    children = !isShownItem(id, item.get()) ? null : {
      key = id
      size = btnSize
      behavior = Behaviors.Button
      hotkeys
      onElemState = @(s) sf.set(s)
      onClick = function() {
        if (!(item.get()?.enabled ?? true))
          return
        playSound("click")
        sendAction(action)
      }
      children = (isBattleFn() ? battleButtonView : plainButtonView)(text, item.get()?.enabled ?? true, sf.get(), btnSize)
        .append(showConsoleButtons.get() ? mkImageCompByDargKey(hotkey, null, hintParams) : null)
    }.__update(ovr)
  }
}

let signInBtn = mkStyledButton("login_action_button", loc("msgbox/btn_signIn"), "ok",
  @() styleW.get() != "guestFirst" || isHelpShownW.get(), "J:X")

let guestBtn = mkStyledButton("guest_login_action_button", loc("mainmenu/loginWithGuest"), "guest",
  @() styleW.get() != "usual" && !isHelpShownW.get(), "J:LT", { margin = [0, 0, blockInterval, 0] })

const NAV_ACTIONS = {
  steam_login_action_button = "steam"
  sso_login_action_button = "sso"
  usual_login_btn = "existingAccount"
}
let { textButton, linkButton } = mkNavButtons(loginItemW, @(id) sendAction(NAV_ACTIONS[id]), HIDDEN_BY_DEFAULT)

let ssoBtn = linkButton("sso_login_action_button", loc("mainmenu/loginWithSso"),
  { size = btnSize, margin = [blockInterval, 0, blockInterval, 0], hotkey = "J:RB" })

let steamBtn = textButton("steam_login_action_button", loc("mainmenu/loginWithSteam"), "J:LB",
  { size = btnSize, margin = [0, 0, blockInterval, 0] })

let tabOrder = ["loginbox_username", "loginbox_password"]
let focusedEditId = Watched(null)

function applyFocus() {
  let { focusId } = loginScreen.get()
  if (tabOrder.contains(focusId))
    set_kb_focus(focusId)
}

focusSeqW.subscribe(@(_) gui_scene.resetTimeout(0.01, applyFocus))

function focusNextEdit() {
  let idx = tabOrder.indexof(focusedEditId.get()) ?? -1
  set_kb_focus(tabOrder[(idx + 1) % tabOrder.len()])
}

let editSize = [flex(), editH]

function mkEditBox(id, isPassword, returnAction) {
  let item = loginItemW(id)
  return editBox({
      id
      password = isPassword
      imeOnFocus = isPassword && (is_steam_deck || is_steam_big_picture())
      inputType = isPassword ? null : "mail"
      title = loc(isPassword ? "mainmenu/password" : "mainmenu/login")
      warning = Computed(@() item.get()?.warning ?? false)
      tooltip = @() item.get()?.warning ? loc("tooltip/invalidEmail/possibly") : null
      onFocus = @() focusedEditId.set(id)
      onBlur = @() focusedEditId.set(null)
      onCancel = @(_) sendAction("exit")
      onReturn = @(_) sendAction(returnAction)
    },
    Computed(@() item.get()?.value ?? ""), changeValue, editSize)
}

let editLabel = @(text) mkText(text, fontNormal, cssColors.commonTextColor, { padding = [0, 0, 0, 5] })

let usernameBox = mkEditBox("loginbox_username", false, "usernameEnter")
let passwordBox = mkEditBox("loginbox_password", true, "passwordEnter")

let capsItem = loginItemW("loginbox_password_caps_indicator")
let layoutItem = loginItemW("loginbox_password_layout_indicator")
let capsText = mkText(loc("mainmenu/password/capslock"), fontSmall, cssColors.warningTextColor)
let layoutTextPadding = [0, 0, 0, blockInterval]
let keyboardIndicator = @() {
  watch = [capsItem, layoutItem]
  hplace = ALIGN_RIGHT
  flow = FLOW_HORIZONTAL
  children = [
    !isShownItem("loginbox_password_caps_indicator", capsItem.get()) ? null : capsText
    mkText(layoutItem.get()?.value ?? "", fontSmall, cssColors.commonTextColor, { padding = layoutTextPadding })
  ]
}

function mkCheckbox(id, textId, locId, topMargin = 0) {
  let item = loginItemW(id)
  let textItem = textId == null ? null : loginItemW(textId)
  let box = mkFormCheckbox({
      id
      text = textItem == null ? loc(locId) : Computed(@() textItem.get()?.value ?? loc(locId))
      isEnabled = Computed(@() item.get()?.enabled ?? true)
    },
    Computed(@() item.get()?.value ?? false), changeValue)
  let margin = [topMargin, 0, 0, 0]
  return @() !isShownItem(id, item.get()) ? { watch = item }
    : { watch = item, size = FLEX_H, margin, children = box }
}

let shardItem = loginItemW("sharding_block")
let shardListItem = loginItemW("sharding_list")
let shardIdx = Computed(@() shardListItem.get()?.value ?? 0)
let shardLabel = editLabel(loc("mainmenu/server"))
let shardComboSize = [pct(formW, 60), cssConst("baseTrHeight") - px("4@dp")]
let shardRow = {
  size = [pct(formW, 90), SIZE_TO_CONTENT]
  margin = [px("0.02@scrn_tgt"), 0, 0, 0]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = px("0.032@scrn_tgt")
}

let shardSelector = @() {
  watch = [shardItem, shardItemsW]
  children = !isShownItem("sharding_block", shardItem.get()) ? null
    : shardRow.__merge({
        children = [shardLabel,
          comboBox({ id = "sharding_list", options = shardItemsW.get() }, shardIdx, changeValue, shardComboSize)]
      })
}

let checkTopMargin = px("0.015@scrn_tgt")
let checkboxesBlock = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    mkCheckbox("loginbox_remote_comp", null, "options/remote_device")
    mkCheckbox("loginbox_code_remember_this_device", null, "options/remember_cur_device")
    mkCheckbox("loginbox_autosave_login", null, "mainmenu/saveLogin", px("0.02@scrn_tgt"))
    mkCheckbox("loginbox_autosave_password", "loginbox_autosave_password_text", "mainmenu/savePassword",
      checkTopMargin)
    mkCheckbox("loginbox_disable_ssl_cert", null, "mainmenu/disableSSLCert", checkTopMargin)
    mkCheckbox("loginbox_autologin", null, "options/auto_login", checkTopMargin)
    { margin = [px("0.01@scrn_tgt"), 0, 0, 0], children = mkLink("btn_recovery_link", loc("msgbox/btn_recovery"), "forgetPassword") }
    shardSelector
  ]
}

let mkHelpBox = @(text, width, ovr) withBg({ bgcolor = cssColors.frameBackgroundColor, border = true, borderColor = cssColors.frameBorderColor },
  {
    size = [width == null ? SIZE_TO_CONTENT : flex(), SIZE_TO_CONTENT]
    padding = blockInterval + px("10@sf/@pf")
    children = {
      size = [width == null ? SIZE_TO_CONTENT : flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      font = fontNormal
      color = cssColors.commonTextColor
      text = text
    }
  },
  { size = [width ?? SIZE_TO_CONTENT, SIZE_TO_CONTENT], vplace = ALIGN_CENTER }.__update(ovr))

let helpLineW = px("@helpLineWidth")
let helpDotSize = px("5@dp")
let helpShadowOffs = px("1@helpLineShadowOffset")
let helpShadowColor = cssColorToInt(constText("helpLineShadowColor"))


function mkHelpLink(startX, endX, anchorTop, anchorH) {
  let lineY = anchorTop + floor(anchorH / 2.0 - helpLineW / 2.0).tointeger()
  let dotX = roundPx(endX - helpDotSize / 2.0)
  let dotY = roundPx(lineY + helpLineW / 2.0 - helpDotSize / 2.0)
  let line = @(offs, color) { pos = [startX + offs, lineY + offs], size = [dotX + helpDotSize - startX, helpLineW],
    rendObj = ROBJ_SOLID, color }
  
  return [
    line(helpShadowOffs, helpShadowColor)
    line(0, HELP_LINE_COLOR)
    { pos = [dotX, dotY], size = helpDotSize, rendObj = ROBJ_SOLID, color = HELP_LINE_COLOR }
  ]
}

let credentialsH = 2 * editH + normalTextH

let credentialsHelpView = [
  mkHelpBox(loc("login/seems_registered_help"), helpW, { key = "loginbox_help", pos = [helpX - formX, 0], minHeight = credentialsH })
].extend(
  mkHelpLink(formW, helpX - formX, 0, editH),
  mkHelpLink(formW, helpX - formX, editH + normalTextH, editH))

let mkHelpShown = @(view) @() { watch = isHelpShownW, size = flex(), children = isHelpShownW.get() ? view : null }
let credentialsHelp = mkHelpShown(credentialsHelpView)

let credentialsBlock = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  children = [
    editLabel(loc("mainmenu/login"))
    {
      size = FLEX_H
      children = [
        {
          size = FLEX_H
          flow = FLOW_VERTICAL
          children = [usernameBox, editLabel(loc("mainmenu/password")), passwordBox]
        }
        credentialsHelp
      ]
    }
    { size = FLEX_H, margin = [px("8@sf/@pf"), 0, 0, 0], children = keyboardIndicator }
  ]
}

let signInHelpView = [mkHelpBox(loc("login/signin_help"), null, { pos = [helpX - innerX, 0] })]
  .extend(mkHelpLink(mainInnerW, helpX - innerX, 0, btnH))

let signInHelp = mkHelpShown(signInHelpView)

let openAnimation = [{ prop = AnimProp.scale, from = [1, 0], to = [1, 1], duration = 0.2, easing = OutCubic,
  play = true, onFinish = @() sendAction("existingAccountOpened") }]

let existingAccountContent = {
  key = "existing_account_block"
  size = FLEX_H
  flow = FLOW_VERTICAL
  padding = [0, 0, 2 * framePadding, 0]
  transform = { pivot = [0.5, 0] }
  onAttach = @() gui_scene.resetTimeout(0.01, applyFocus)
  children = [
    {
      size = [formW, SIZE_TO_CONTENT]
      hplace = ALIGN_CENTER
      flow = FLOW_VERTICAL
      children = [credentialsBlock, checkboxesBlock]
    }
    steamBtn
    { size = FLEX_H, margin = [blockInterval, 0, 0, 0], children = [signInBtn, signInHelp] }
    ssoBtn
  ]
}
let existingAccountOpening = existingAccountContent.__merge({ animations = openAnimation })

let existingAccountBlock = @() {
  watch = [isOpenedW, styleW]
  size = FLEX_H
  children = !isOpenedW.get() ? null
    : styleW.get() == "compact" ? existingAccountOpening
    : existingAccountContent
}

let existingAccountLabel = mkText(loc("mainmenu/existingAccount"), fontNormal, cssColors.commonTextColor,
  { hplace = ALIGN_CENTER, vplace = ALIGN_CENTER })
let existingAccountBtnFading = {
  key = "usual_login_btn_fading"
  size = flex()
  animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = 0.2, easing = InCubic, playFadeOut = true }]
  children = textButton("usual_login_btn", loc("mainmenu/existingAccount"), "J:LB", { size = btnSize })
}

let compactHeader = @() {
  watch = [styleW, isOpenedW]
  size = FLEX_H
  children = styleW.get() != "compact" ? null : {
    size = [flex(), btnH]
    margin = [0, 0, blockInterval, 0]
    children = [existingAccountLabel, isOpenedW.get() ? null : existingAccountBtnFading]
  }
}

let frameBg = { bgcolor = cssColors.frameBackgroundColor, border = true, borderColor = cssColors.frameBorderColor }

let mainFrame = withBg(frameBg, {
  size = FLEX_H
  padding = blockInterval
  flow = FLOW_VERTICAL
  children = [compactHeader, existingAccountBlock, guestBtn]
}, { key = "main_panel_frame", size = FLEX_H })

let linksItem = loginItemW("links_block")
let linksList = {
  pos = [px("0.015@scrn_tgt"), 0]
  flow = FLOW_VERTICAL
  children = [
    { margin = [px("0.015@scrn_tgt"), 0, 0, 0], children = mkLink("btn_signUp_link", loc("mainmenu/signUp"), "signUp") }
    mkLink("btn_faq_link", loc("mainmenu/faq"), "faq")
    mkLink("btn_support_link", loc("mainmenu/support"), "support")
  ]
}
let linksFrame = withBg(frameBg, @() {
  watch = linksItem
  size = flex()
  padding = blockInterval
  children = isShownItem("links_block", linksItem.get()) ? linksList : null
}, { size = flex(), margin = [blockInterval, 0, 0, 0] })

let titleLogoSize = [256 * logoScale, 128 * logoScale]
function titleLogo(size) {
  let pos = [centerPos(size[0], titleLogoSize[0]), centerPos(size[1], titleLogoSize[1])]
  return @() {
    watch = titleLogoW
    size
    children = titleLogoW.get() == "" ? null
      : { pos, size = titleLogoSize, rendObj = ROBJ_IMAGE, image = Picture(titleLogoW.get()) }
  }
}

let companyLogoSize = [cssConst("companyLogoW"), cssConst("companyLogoH")]
let companyLogo = @(size) {
  pos = [centerPos(size[0], companyLogoSize[0]), centerPos(size[1], companyLogoSize[1])]
  size = companyLogoSize
  children = [
    { size = flex(), rendObj = ROBJ_IMAGE, image = Picture("ui/gaijin_logo_shadow"),
      keepAspect = KEEP_ASPECT_FIT, color = COMPANY_LOGO_SHADE_COLOR }
    { size = flex(), rendObj = ROBJ_IMAGE, keepAspect = KEEP_ASPECT_FIT, color = 0xFFFFFFFF,
      image = Picture($"!ui/gaijin_logo.svg:{companyLogoSize[0]}:{companyLogoSize[1]}:K") }
  ]
}

let versionTextH = px("0.03@scrn_tgt")
let versionText = {
  pos = [px("0.02@scrn_tgt"), logoPlateH - versionTextH]
  size = [SIZE_TO_CONTENT, versionTextH]
  valign = ALIGN_CENTER
  children = @() { watch = versionTextW, rendObj = ROBJ_TEXT, font = fontSmall, color = cssColors.commonTextColor,
    text = versionTextW.get() }
}

let redLight = @(y, h, isFlipped) {
  pos = [centerPos(colW, 3 * colW), y]
  size = [3 * colW, h]
  rendObj = ROBJ_IMAGE
  image = Picture("ui/gameuiskin#top_bar_light")
  color = RED_LIGHT_COLOR
  flipY = isFlipped
}

let shade = @(y, h) { pos = [0, y], size = [colW, h], rendObj = ROBJ_SOLID, color = SHADE_COLOR }

let bottomPlateH = pct(screenH, 15)
let leftColumn = @() {
  pos = [colX, 0]
  size = [colW, screenH]
  children = [
    shade(topBarH, screenH - topBarH - bottomBarH)
    redLight(0, topBarH, true)
    shade(0, topBarH)
    { pos = [plateX, -4], children = [mkPlate(plateW, logoPlateH, titleLogo), versionText] }
    {
      pos = [plateX, logoPlateH]
      size = [plateW, mainH]
      padding = [0, mainPadX]
      flow = FLOW_VERTICAL
      children = [mainFrame, linksFrame]
    }
    redLight(screenH - bottomBarH, bottomBarH, false)
    shade(screenH - bottomBarH, bottomBarH)
    { pos = [plateX, pct(screenH, 85) + 4], children = mkPlate(plateW, bottomPlateH, companyLogo) }
  ]
}

let langSelectorItem = loginItemW("language_selector")
let langLabelItem = loginItemW("label_language")
let langLabelOvr = { margin = [0, px("@sIco/4"), 0, px("@sIco/8")] }
let onLanguage = @(_, idx) sendAction("language", { langId = langsW.get()[idx].id })
let langSelector = @() {
  watch = [langSelectorItem, langLabelItem, langsW]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  children = !isShownItem("language_selector", langSelectorItem.get()) ? null : [
    mkText(langLabelItem.get()?.value ?? "", fontNormal, cssColors.commonTextColor, langLabelOvr)
    comboBox({ id = "language", options = langsW.get(), hotkey = "J:Y" }, null, onLanguage)
  ]
}

let topPanel = @() {
  size = [flex(), topBarH]
  children = [
    { size = [flex(), bhPx], rendObj = ROBJ_SOLID, color = cssColors.gameModeColor }
    { size = flex(), children = commonBg({ image = "#ui/gameuiskin#top_bar", repeat = "expand", position = "1, 6, 1, 2" }) }
    {
      pos = [-bwPx, bhPx]
      hplace = ALIGN_RIGHT
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      children = [langSelector, closeButton(@() sendAction("exit"))]
    }
  ]
}

let copyrightOvr = { pos = [-bwPx, 0], hplace = ALIGN_RIGHT, vplace = ALIGN_CENTER, padding = [0, px("0.04@sf"), 0, 0] }
let copyrightText = @() {
  watch = copyrightTextW
  size = flex()
  children = mkText(copyrightTextW.get(), fontNormal, cssColors.commonTextColor, copyrightOvr)
}

let bottomPanel = {
  pos = [0, screenH - bottomPanelH - bhPx]
  size = [flex(), bottomPanelH]
  rendObj = ROBJ_SOLID
  color = cssColors.bottomBarBackgroundColor
  children = [
    { size = [flex(), px("1@dp")], rendObj = ROBJ_SOLID, color = cssColors.bottomBarForegroundColor }
    copyrightText
    { pos = [0, bottomPanelH], size = [flex(), bhPx], rendObj = ROBJ_SOLID, color = cssColors.gameModeColor }
  ]
}

let bugDisclaimerItem = loginItemW("browser_bug_disclaimer")
let bugDisclaimerW = px("0.8sw - 0.8*@sf")
let bugDisclaimerPanel = {
  size = FLEX_H
  vplace = ALIGN_CENTER
  padding = [px("0.01sh"), px("0.005sw"), px("0.02sh"), px("0.005sw")]
  rendObj = ROBJ_SOLID
  color = cssColors.shadeBackgroundColor4
  children = {
    size = FLEX_H
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    halign = ALIGN_CENTER
    font = fontNormal
    color = cssColors.warningTextColor
    text = loc("browser_bug_disclaimer")
  }
}
let bugDisclaimerPos = [centerPos(screenW, bugDisclaimerW), pct(screenH, 83) - bhPx]
let bugDisclaimerSize = [bugDisclaimerW, 0]
let bugDisclaimer = @() {
  watch = bugDisclaimerItem
  pos = bugDisclaimerPos
  size = bugDisclaimerSize
  children = isShownItem("browser_bug_disclaimer", bugDisclaimerItem.get()) ? bugDisclaimerPanel : null
}

return {
  size = [screenW, screenH]
  hotkeys = [["Tab", focusNextEdit]]
  children = [topPanel, bottomPanel, leftColumn, bugDisclaimer]
}
