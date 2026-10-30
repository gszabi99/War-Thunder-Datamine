return const {
  dp = "(((sh $min sw)/@pf + 0.5) \\ 1) $max 1"

  rw = "(@_safearea_menu_w)*sw $min (sw -2*@debugRowHeight)"
  rh = "(@_safearea_menu_h)*sh $min (sh -2*@debugRowHeight)"
  bw = "0.5(sw-1@rw)"
  bh = "0.5(sh-1@rh)"
  bwInVr = "1@bw*@isInVr"
  bhInVr = "1@bh*@isInVr"
  swOrRwInVr = "sw-2@bwInVr"
  shOrRhInVr = "sh-2@bhInVr"

  srw = "16/9*1@sf $min 1@rw"
  srh = "1@sf $min 1@rh"
  sbw = "0.5(sw-1@srw)"

  debugRowHeight = "14"

  cursorSizeMul = "@dp"

  shopAirHeight = "44*@sf/@pf_outdated"
  shopAirWidth = "120*@sf/@pf_outdated"
  vtIco = "(12*@sf/@pf) \\ 1"
  tIco = "(18*@sf/@pf) \\ 1"
  sIco = "(22*@sf/@pf) \\ 1"
  cIco = "(30*@sf/@pf) \\ 1"
  dIco = "(40*@sf/@pf) \\ 1"
  mIco = "(32*@sf/@pf_outdated) \\ 1"
  lIco = "(64*@sf/@pf_outdated) \\ 1"
  slotBtnIco = "23*@sf/@pf_outdated"
  profileMedalSize = "(128@sf/@pf) \\ 1"
  profileMedalSizeBig = "(256@sf/@pf $max 256) \\ 1"
  profileUnlockIconSize = "(150*@sf/@pf) \\ 1"
  profileIconFullSize = "(200@sf/@pf) \\ 1"
  avatarButtonSize = "(1@profileUnlockIconSize + 2@blockInterval) \\ 1"
  debriefingUnlockIconSize = "75@sf/@pf"
  unlockStageIconSize = "32*@sf/@pf_outdated"
  lockIconInnerRightOffset = "6@sf/@pf"

  decalItemMargin = "4@dp"
  decalIconHeight = "100*@sf/@pf \\ 1"
  mainMenuButtonWidth = "0.26@sf"
  mainMenuButtonWideWidth = "0.34@sf"

  modIcoSize = "(76@sf/@pf)\\1"
  modArrowWidth = "19@dp"
  modLineWidth = "19@dp"
  modAngleWidth = "19@dp"
  modStatusHeight = "(30@sf/@pf)\\1"
  modStatusCheckboxHeight = "(18@sf/@pf)\\1"
  modArrowLen = "2@modPadSize"
  modPadSize = "(8@sf/@pf)\\1"

  modBundlePopupBgPadH = "4@dp +1@modPadSize"
  modBundlePopupAdditionalBtnsHeight = "2@additionalButtonHeight - 1@modPadSize"

  chestRewardHeight = "227*@sf/@pf_outdated"
  chestRewardWidth = "227*@sf/@pf_outdated"
  chestRewardFrameWidth = "@rw $min 1200@sf/@pf"
  itemIconHeight = "((120*@sf/@pf_outdated)\\2)*2"
  awardIconHeight = "50*@sf/@pf_outdated"

  tableIcoSize = "1@cIco"
  tablePad = "(0.005@sf)\\1"

  titlePos = "@bw+1*@scrn_tgt/100.0"

  listboxPad = "3@dp"
  optPad = "2.5*@scrn_tgt/100.0"
  tblPad = "2.5*@scrn_tgt/100.0"
  mainMenuButtonHeight = "(0.059*@scrn_tgt)\\1"
  baseTrHeight = "(0.038*@sf)\\1"
  baseTrHeaderHeight = "(0.076*@sf)\\1"
  leaderboardTrHeight = "(0.03*@sf)\\1"
  leaderboardHeaderHeight = "(0.06@sf)\\1"
  leaderboardHeaderIcoSize = "(0.05@sf)\\1"
  rows16height = "(0.030*@scrn_tgt)\\1"
  sliderRowHeight = "(1@sliderHeight + 2@sliderIncHeight)\\1"
  crewTrHeight = "(0.035*@sf)\\1 + 6*@sf/@pf_outdated"
  smallRowHeight = "(0.02*@sf)\\1"
  optionsHeaderRowHeight = "(0.02@sf)\\1 + 4@dp"
  optContainerHeight = "(45@sf/@pf)\\1"
  optContainerCompactHeight = "(34@sf/@pf)\\1"
  expSkillBonusCommentMaxWidth = "750@sf/@pf"

  gamercardHeight = "(1@bigButtonHeight)\\1"
  gamercardDrawerPosY = "1@gameModeSelectPaddingTop + 1@bh + 1@buttonHeight + 2@buttonMargin"
  gameModeSelectPaddingTop = "1@topMenuBattleButtonHeight + 0.5@buttonIconHeight"
  topBarHeight = "1@gamercardHeight + 1@topGamercardButtonsPos + 1@dp"
  topGamercardButtonsPos = "1@bh + 1@topGamercardRedLineHeight"
  topGamercardRedLineHeight = "2@dp"
  topGamercardDarkLineHeight = "2@dp"
  bottomBarHeight = "59@sf/@pf + 1@bh"
  gcSeparatorSize = "1@dp"
  gcButtonsInterval = "((((1@topGcPanelWidth - 0.6@sf) / 10 - 1@gcSeparatorSize) \\ 2 * 2) $max 0) + 1@gcSeparatorSize"

  frameHeaderHeight = "(0.045@sf)/1 + 1@frameHeaderPad"
  frameHeaderHeightHigher = "92@sf/@pf"
  frameHeaderPad = "1@dp"
  frameTopPadding = "1@frameHeaderHeight + 1@blockInterval"
  navBarTopPadding = "1@blockInterval"
  unlocksListboxItemInterval = "2@sf/@pf"
  frameFooterHeightLarge = "1@navBarBattleButtonHeight + 1@navBarTopPadding + 1@buttonMargin + 1@framePadding"
  frameFooterHeight = "1@buttonHeight + 1@navBarTopPadding + 1@buttonMargin + 1@framePadding"
  frameFooterHeightBigBattle = "1@battleButtonHeight + 1@navBarTopPadding + 1@buttonMargin + 1@framePadding"

  customizationDecoratorBlockWidth = "1@decalIconHeight + 2@decalItemMargin"
  customizationBlockWidth = "4@customizationDecoratorBlockWidth"
  countDecalsInWidth = "((0.35*sw \\@customizationDecoratorBlockWidth) $max 4) $min 6"

  titleLogoSizeMul = "1.3"
  
  titleLogoBgToTextRatio = "64/50"
  titleLogoIdealHeight = "(1@topBarHeight - 1@bh) * 1@titleLogoSizeMul * 1@titleLogoBgToTextRatio"
  titleLogoPlateHeight = "((1@titleLogoIdealHeight + 16) \\ 32 * 32) $max 64"
  titleLogoPlateWidth = "2*@titleLogoPlateHeight"
  
  titleLogoPlatePadding = "-1*@titleLogoPlateWidth / 128"
  titleLogoPlatePaddingTop = "1@bh"
  titleLogoShadePaddingW = "5@sf/@pf"
  titleLogoShadePaddingH = "3@sf/@pf"
  titleLogoFullWidth = "1@titleLogoPlateWidth + 2@titleLogoPlatePadding + 4@titleLogoShadePaddingW"
  titleLogoFullHeight = "1@titleLogoPlateHeight + 1@titleLogoPlatePaddingTop + 4@titleLogoShadePaddingH"
  titleLogoSafeareaOffsetTop = "0 -1@titleLogoPlateHeight * ((1 - (1 / (1@titleLogoBgToTextRatio))) / 2) -1@titleLogoPlatePaddingTop -2@titleLogoShadePaddingH"

  loginLogoScale = "((@sf/@pf + 0.5) \\ 1) $max 1"

  companyLogoW = "156@loginLogoScale"
  companyLogoH = "78@loginLogoScale"
  companyLogoPadW = "50@loginLogoScale"
  companyLogoPadH = "25@loginLogoScale"

  toBattleButtonBottom = "1@titleLogoPlateHeight + 1@bh + 0.006@sf"
  gcToBattleButtonWidth = "192@sf/@pf + (0.08@sf * 1@isWide)"
  gcToBattleButtonPlaceWidth = "1@gcToBattleButtonWidth $max 1@titleLogoFullWidth"
  maxToBattleButtonTextWidth = "1@gcToBattleButtonWidth - 2@buttonTextPadding"

  gcWidthFull = "sw - 2@offsetBetweenScreenAndAirinfo"
  topGcPanelWidth = "0.5@gcWidthFull - 0.5@gcToBattleButtonPlaceWidth"
  bottomGcWidth = "@slotbarWidthFull"

  queueTableColumnWidth = "0.05@sf"
  gameModeSelectBlockWidth = "6*(0.06*@sf + 0.01*@scrn_tgt + 2)"

  bigOptionsScrollStep = "3@baseTrHeight"

  controlsLeftRow = "0.45@sf"

  nameWidth = "0.24@sf"
  nameWidthInWideScreen = "(0.24 + 0.12@isWide)*@sf"
  clanNameTableWidth = "30@sf/100"
  clanMedalSizeMin = "80@sf/@pf_outdated"

  shopCols = "7"
  shopWidthMax = "180*@sf/@pf_outdated"
  shopWidthMin = "120*@sf/@pf_outdated"
  shop_width = "(((1@shopUsefulWidth \\ @shopCols - 1px) $min @shopWidthMax) $max @shopWidthMin) \\ 1"
  shopUsefulWidth = "1@slotbarWidthFull - 1@modBlockTierNumHeight - 1@scrollBarSize"
  shop_interval = "((1@shop_width - @shopWidthMin)\\2 $min 18*@sf/@pf_outdated) $max 2*@sf/@pf_outdated"
  shop_pad = "0.02*@scrn_tgt\\1 + 4*@sf/@pf_outdated"
  shop_height = "(1@shopAirHeight + 2@shop_pad + 6*@sf/@pf_outdated)\\1"
  is_shop_items_wide = "@shop_width\\(180@dp) $min 1"

  lines_pad = "(1@shop_pad - 3*@sf/@pf_outdated) / 1"
  lines_shop_interval = "(1@shop_interval - 2*@sf/@pf_outdated) /1"

  slot_button_fullWidth = "((140 + 5@isWide)*@sf/@pf_outdated)\\1"
  slot_width = "1@slot_button_fullWidth + 2@slot_interval"
  slot_interval = "(4*@sf/@pf)\\1"
  slot_vert_pad = "0.005*@scrn_tgt\\1"
  slot_height = "@shopAirHeight + 10*@sf/@pf_outdated"
  slot_hdr_width = "@cIco +12@sf/@pf\\1"
  slotPaddingNoTable = "(16@sf/@pf) \\ 1"
  slotScrollButtonWidth = "(0.025@sf)\\1"

  slotExtraInfoHeight = "21@sf/@pf"
  slotExtraInfoHeightHuge = "1.5@slotExtraInfoHeight"
  slotbar_top_shade = "4@sf/@pf"
  slotbar_pad_top = "30@sf/@pf"
  slotbar_pad_bottom = "30@sf/@pf"
  slotbar_bottom_margin = "9@sf/@pf"

  frameThickPadding = "16@sf/@pf"
  frameMediumPadding = "10@sf/@pf"
  crewWndBaseHeight = "724@sf/@pf"
  upgradeQualContainerBaseHeight = "208@sf/@pf"

  crewSkillTabHeight = "56@sf/@pf"
  crewAceResearchBlockPadding = "14@sf/@pf"
  crewAceResearchProgresBlockHeight = "6@sf/@pf"
  groupHeight = "0.03*@scrn_tgt\\1"

  flightMenuBrHeight = "22*@sf/@pf_outdated"

  slotsCount = "((1@rw -2@slot_interval -2@slotScrollButtonWidth)                   \\@slot_width) $min 10"
  slotsCountExt = "((1@rw -2@slot_interval -2@slotScrollButtonWidth -1@slot_hdr_width) \\@slot_width) $min 10"
  slotbarWidth = "(1@slot_width*1@slotsCount    +2@slot_interval +5@scrn_tgt/100.0 +2@sf/@pf_outdated) \\1"
  slotbarWidthExt = "(1@slot_width*1@slotsCountExt +2@slot_interval +5@scrn_tgt/100.0 +2@sf/@pf_outdated +1@slot_hdr_width) \\1"
  slotbarWidthFull = "(1@slotbarWidth + 1) \\2*2"
  slotbarWidthFullExt = "(1@slotbarWidthExt + 1) \\2*2"

  slotbarHeight = "1@slotbar_top_shade + 1@slotbar_pad_top + 1@slot_height + 1@slotbar_pad_bottom"
  slotbarInvisPad = "(18*@sf/@pf) \\ 1"
  offsetBetweenScreenAndAirinfo = "(1@bw + 1@mIco + 2@listboxPad + 2@airInfoPadding) $min  0.5 * (sw - 1@slotbarWidthFull)"
  airInfoPanelRightSide = "1@bw + 1@mIco + 2@listboxPad + 2@airInfoPadding"
  airInfoPanelWidth = "0.43@sf"
  airInfoPannelContentPadding = "1@scrn_tgt/100.0"
  
  airInfoPanelDmSwitcherWidth = "((@airInfoPanelWidth - 2@listboxPad) \\ 3) * 3 + 4@listboxPad + 2@airInfoPannelContentPadding"

  slotbarOffset = "1@bottomBarHeight"
  slotbarTop = "36@sf/@pf"
  slotbarShopBtnOffset = "1@offsetFromEdge + 1@shopWidthMax + 13@sf/@pf"

  offsetFromEdge = "1@frameHeaderPad + 1@buttonMargin"

  shopBottomOffset = "1@wndWithSlotbarBottomOffset"
  shopYPos = "sh -1@shopBottomOffset"
  shopWndWidth = "1@slotbarWidthFull"
  battleBtnBottomOffset = "sh-1@shopBottomOffset"

  onlineShopWidth = "@sf $max 512"
  researchNotificationWidth = "0.8@sf $max 600"

  hudActionBarItemSize = "0.06@shHud"
  hudActionBarItemHeight = "0.1@shHud"

  hudInfantryActionBarHeight = "0.08@shHud"
  hudInfantryActionBarWidth = "0.06@shHud"
  hudInfantryWeaponryMargin = "0.01@shHud"
  hudInfantryActionBarItemMargin = "0.005@shHud"
  hudInfantryActionBarItemIconSize = "0.037@shHud"

  hudActionBarItemBigSize = "0.075@shHud"
  hudActionBarItemOffset = "0.005@shHud"
  actionBarBottomPos = "sh - 1@bhHud"
  hudActionBarTextShHight = "0.022@shHud"
  hudActionBarExpandBtnHeight = "0.012@shHud"
  hudActionBarExpandBtnGap = "0.002@shHud"

  bulletTooltipPadding = "8@sf/@pf"
  bulletTooltipCardWidth = "1@bulletAnimationWidth + 2@bulletTooltipPadding"
  bulletTooltipCardWidthNarrow = "0.7*@bulletAnimationWidth + 2@bulletTooltipPadding"
  framePadding = "1@blockInterval"
  unlockBlockWidth = "0.55@sf\\1"

  modItemHeight = "(1@modIcoSize-3@sf/@pf)\\1"
  modBlockTierNumHeight = "(0.33@modCellHeight)\\1"
  modCellWidth = "1@modItemWidth +1@modPadSize"
  modCellHeight = "1@modItemHeight +2@modPadSize"

  wndWithSlotbarBottomOffset = "1@slotbarHeight +1@slotbarOffset +1@slotbar_top_shade +1@slotbarTop"
  maxWindowHeightNoSrh = "sh - 1@bh - 1@titleLogoPlateHeight - 1@bottomBarHeight - 0.01@scrn_tgt"
  maxWindowHeight = "1@maxWindowHeightNoSrh $min 1@srh"
  maxWindowHeightWithSlotbar = "sh - 1@bh - 1@titleLogoPlateHeight - 1@wndWithSlotbarBottomOffset"
  maxWindowHeightWithFullSlotbar = "1@maxWindowHeightWithSlotbar - 1@slotbarTop"
  maxWeaponsWindowHeight = "sh -1@topBarHeight -1@wndWithSlotbarBottomOffset"
  maxWeaponsWindowHeightNoSlotbar = "sh -1@topBarHeight -1@bottomBarHeight"

  maxWindowWidth = "1@rw"

  minYposWindow = "1@bh + 1@titleLogoSafeareaOffsetTop + 1@titleLogoFullHeight"

  paymentIconWidth = "270@sf/@pf"
  paymentIconHeight = "90@sf/@pf"

  discountBoxDownHeight = "35*@sf/@pf"
  discountBoxUnitTop = "23*@sf/@pf"
  discountBoxPadding = "1@blockInterval"
  discountBoxDownArrowHeight = "14*@sf/@pf"
  discountBoxHeight = "23*@sf/@pf"

  eventTacticalMapSize = "0.23@scrn_tgt + 0.07@scrn_tgt * 1@isWide"
  eventRewardIconHeight = "0.08@scrn_tgt"

  blockInterval = "(6@sf/@pf) \\ 1"
  chatIndent = "(120@sf/@pf) \\ 1"
  airInfoPadding = "10@sf/@pf"
  helpInterval = "0.01@sf"
  helpLineInterval = "0.5@helpInterval"
  helpLineWidth = "1@dp"
  helpLineShadowOffset = "1@dp"
  helpLineShadowColor = "#80000000"
  itemsInterval = "0.015@scrn_tgt"
  itemsIntervalBig = "0.03@scrn_tgt"

  modItemWidth = "(1@modIcoSize + 112@sf/@pf) \\ 1"

  tutorArrowSize = "(32@sf/@pf) \\ 1"

  newWidgetIconHeight = "33@sf/@pf"
  newWidgetIconImgOffsetX = "-0.5@newWidgetIconHeight"

  wwMapTooltipOffset = "0.02@sf"
  wwMapPanelInfoWidth = "0.07@rw*(1-1@isWide) + 0.29@rw"

  wwMapTooltipInfoWidth = "660@sf/@pf"
  framedMessageMaxWidth = "0.5@sf"

  infoPanelVertPosition = "1@titleLogoPlateHeight + 1@bh + 0.02@sf+1@checkboxSize+1@blockInterval"
  maxInfoPanelContentHeightWithSlotbar = "sh - 1@infoPanelVertPosition - 1@airInfoToggleButtonSize - 2@framePadding - 1@wndWithSlotbarBottomOffset - 0.04@sf"

  minChatHeight = "0.11@scrn_tgt"
  maxChatHeight = "0.33@scrn_tgt"
  chatLogLineHeight = "0.02@scrn_tgt"
  minChat3LinesHeight = "1@minChatHeight + 2@chatLogLineHeight"
  minMisObjHeight = "0.08@scrn_tgt"
  respawnOptListContainerWidth = "(1@slotbarWidthFullExt -8*@sf/@pf_outdated) $max (1@rw * (1-1@isWide))"
  gameChatWidth = "(0.4 + 0.13@isWide)@rhHud"

  topMenuHoverMenuIndent = "0.01@sf"

  shortcutUpDpAndStick = "J:Dpad.Up | J:L.Thumb.Up"
  shortcutUpDp = "J:Dpad.Up"

  shortcutDownDpAndStick = "J:Dpad.Down | J:L.Thumb.Down"
  shortcutDownDp = "J:Dpad.Down"

  shortcutLeftDpAndStick = "J:Dpad.Left | J:L.Thumb.Left"
  shortcutLeftDp = "J:Dpad.Left"

  shortcutRightDpAndStick = "J:Dpad.Right | J:L.Thumb.Right"
  shortcutRightDp = "J:Dpad.Right"

  tooltipPadding = "12@sf/@pf"

  weaponIconPadding = "4*@sf/@pf"
  briefingBackgroundWidth = "1.8*@rh"
  briefingScreenWidth = "1@briefingBackgroundWidth $min sw"
  briefingScreenWPad = "(sw-@briefingScreenWidth)/2 $max 0"
  briefingMapWidth = "0.39*@briefingBackgroundWidth"
  briefingMapLeftPos = "(0.12@briefingBackgroundWidth)@isWide"
  briefingMissionTextLeftPos = "1@briefingMapLeftPos + 1@briefingMapWidth + 0.01@scrn_tgt"
  weaponStatusIconSize = "16*@sf/@pf"
  systemMsgIndent = "0.14@rw"
  battleTaskTooltipMinWidth = "1@arrowButtonWidth + 1@offsetBetweenScreenAndAirinfo"

  chapterBlockWidth = "0.32@sf"
  chapterWideBlockWidth = "1@chapterBlockWidth + 0.08@sf*1@isWide"

  dmInfoTextWidth = "(0.07@sf) \\ 1"

  dropDownMenuBottomActivityGap = "8@dp"

  gamercardVoiceChatWidth = "180@sf/@pf"
  voiceChatSmallIconWidth = "11@sf/@pf"
  voiceChatSmallIconHeight = "16@sf/@pf"
  voiceChatBaseIconWidth = "18@sf/@pf"
  voiceChatBaseIconHeight = "26@sf/@pf"

  fadedImageFramePad = "3@sf/@pf"
  WWOperationDescriptionWidth = "900@sf/@pf + (0.08@sf * 1@isWide)"
  viewUnitsInGroupPadding = "30@sf/@pf"
  bottomMenuPanelHeight = "1@bottomBarHeight - 1@bh"
  fontBigBoldHeight = "51@sf/@pf"
  narrowTooltipWidth = "370@sf/@pf"
  tierIconSize = "60@sf/@pf"
  modPresetTextMaxWidth = "350@sf/@pf"

  twoStepLoginBgrImgWidth = "1012@sf/@pf"
  twoStepLoginBgrImgHeight = "626@sf/@pf"
  twoStepLoginImgWidth = "295@sf/@pf"
  twoStepLoginImgHeight = "506@sf/@pf"
  decorationInfoMaxWidth = "6@decalIconHeight"
  defaultNavPanelWidth = "0.3@sf"
  shopInfoMinWidth = "1@itemInfoWidth+2@itemSpacing+1@scrollBarSize"
  waitIconWidth = "44@sf/@pf"

  trashBinIconSize = "28@sf/@pf"
  trashBinBigIconSize = "60@sf/@pf"

  contactTooltipMinWidth = "(640@sf/@pf) \\1"
  contactTooltipAvatarMargin = "(27@sf/@pf) \\1"
  contactTooltipAvatarImgSize = "(166@sf/@pf) \\1"
  contactTooltipAvatarFullSize = "(176@sf/@pf) \\1"
  contactTooltipContentMinWidth = "1@contactTooltipMinWidth-@contactTooltipAvatarFullSize-2@contactTooltipAvatarMargin+2@blockInterval"

  premiumItemWidth = "170@sf/@pf"
  premiumItemHeight = "250@sf/@pf"

  shopItemPad = "4*@sf/@pf"
  slotExtraInfoSidePad = "(0.05@slot_button_fullWidth)\\1"
  rentIconSize = "26@sf/@pf\\2*2"
  slotBorderSize = "1@dp"
  slotbarBottomLineHeight = "1@sf/@pf"
  slotTopLineHeight = "2@dp"
  unitTooltipTopLineHeight = "3@dp"
  unitTooltipTopLinePad = "-1@dp" 
  slotBottomShadeHeight = "2@sf/@pf"
  slotGroupTagHeight = "4@dp"
  groupUnfoldMarkWidth = "29@sf/@pf \\ 1"
  groupUnfoldMarkHeight = "20@sf/@pf \\ 1"
  swapCrewsHeaderHeight = "30@sf/@pf \\ 1"
  topUnitsBonusHeight = "0.5@shop_height"
  unitTrashBinPosY = "sh - 1@slotbarOffset - 1@slotbarHeight - 1@slotbarTop - h - 30@sf/@pf"

  shopFilterHFlowHeight = "0.04*@sf"
  shopFilterTextCountryHeight = "28@sf/@pf"
  listboxItemsInterval = "1@dp"
  listboxHPadding = "0.015@sf"
  slotsHeaderBoxPadding = "0.01@sf"

  nav_button_font = "@fontNormal"
  nav_button_accented_font = "@fontNormalBold"

  buttonTextPadding = "0.5*@scrn_tgt/100.0"
  bigButtonTextPadding = "0.01@sf"
  buttonImgPadding = "(1@dp + 3*@sf/@pf)\\1"
  smallButtonImgPadding = "(1@dp + 2*@sf/@pf)\\1"

  buttonWidth = "2 * (0.16*@sf\\2)"
  bigButtonWidth = "0.25*@sf\\1"
  buttonHeight = "@cIco + 2@buttonImgPadding"
  battleButtonHeight = "20*@sf/@pf_outdated + 3*@scrn_tgt/100.0"
  slotBattleButtonHeight = "3*@scrn_tgt/100.0"
  bigButtonHeight = "1@frameHeaderHeight - 2@frameHeaderPad"
  smallButtonHeight = "1@sIco + 2@smallButtonImgPadding"

  navBarBattleButtonHeight = "(38@sf/@pf)\\1 + 2@buttonImgPadding"
  navBarBattleButtonMinWidth = "1.3 * (2 * (0.16*@sf\\2))"

  buttonMargin = "@blockInterval"
  smallButtonMargin = "1@dp"
  additionalButtonHeight = "0.7@buttonHeight"

  buttonIconHeight = "@cIco + 5*@sf/@pf_outdated"

  topMenuButtonWidth = "0.15@sf"

  topMenuBattleButtonHeight = "0.055@sf"

  buttonCloseHeight = "@bigButtonHeight"
  smallButtonCloseHeight = "@smallButtonHeight"

  buttonImgMargin = "0.2*@scrn_tgt/100.0"

  buttonImgSvgHeight = "100@dp"
  trashButtonHeight = "1@cIco"

  keyboardHintButtonHeight = "1@buttonHeight - 4@sf/@pf"

  checkboxSize = "(30@sf/@pf) \\ 1"
  checkboxImgSize = "(24@sf/@pf) \\ 1"

  switchBoxHeight = "28@sf/@pf" 
  switchBoxWidth = "80@sf/@pf"
  switchBoxShortWidth = "56@sf/@pf"
  switchBoxBorderSize = "3@dp"
  switchButtonLineHeight = "2@dp"

  kbh = "0.040*@scrn_tgt\\1 + 0.005*@scrn_tgt\\1*1@isWide"
  kbPad = "0.005*@scrn_tgt\\1"

  markerWidth = "29@sf/@pf"
  markerHeight = "36@sf/@pf"
  nationBonusIconHeight = "33@sf/@pf"
  nationBonusIconWidth = "23@sf/@pf"
  discountMarkerWidth = "60@sf/@pf"
  eventIconWidth = "30@sf/@pf"
  eventIconHeight = "33@sf/@pf"

  optContainerRightCellWidth = "450@sf/@pf"
  optContainerCellEdgePadding = "27@sf/@pf"
  optCellSeparatorMargin = "12@sf/@pf"
  optContainerControlWidth = "pw-@optContainerCellEdgePadding-@optCellSeparatorMargin"

  bigCountyIconWidth = "134@sf/@pf"
  bigCountyIconHeight = "70@sf/@pf"
  smallCountyIconWidth = "67@sf/@pf"

  promoRadiobuttonH = "4@sf/@pf"

  slideGroupMargin = "1@dp"

  dropPad = "1*@scrn_tgt/100.0"

  countryOptionWidth = "105@sf/@pf"
  countryOptionLineHeight = "28@sf/@pf"
  countryOptionHeight = "100@sf/@pf + 1@dp"

  popupArrowWidth = "22@dp"
  popupArrowHeight = "12@dp"

  progressHeight = "8@sf/@pf"
  progressHeightSlot = "5@sf/@pf"
  progressHeightSmall = "3@sf/@pf"
  progressHeightBig = "16@sf/@pf \\ 1"
  referenceProgressHeight = "3@dp"
  referenceProgressOffset = "0@dp"

  skillProgressBgIncSize = "0"
  skillProgressHeightMul = "0.5"
  skillProgressWidthMul = "2" 
  referenceMarkerWidth = "9/22*0.02@sf"

  crewSkillBlockHeight = "14@sf/@pf"
  crewSkillGlowBlockHeight = "30@sf/@pf"
  crewSkillBockWidth = "(36@sf/@pf) \\ 1"

  shortcutImageHeight = "0.04@shHud"

  hintRowCenterOffsetY = "0.0185@shHud"

  comboListPadding = "0"
  comboOptionPadding = "5@sf/@pf_outdated"
  comboBtnWidth = "@baseTrHeight - 4@dp"
  comboBtnHeight = "11@sf/@pf"
  comboOptContainerHeight = "32@sf/@pf"

  option_font = "@fontNormal"
  option_selected_font = "@fontNormal"

  sliderThumbWidth = "9@sf/@pf_outdated"
  sliderThumbHeight = "22@sf/@pf_outdated"
  sliderValueButtonHeight = "1@cIco+4"
  sliderButtonSquareHeight = "0.025@scrn_tgt"
  sliderButtonSquareHeightSm = "20*@sf/@pf"
  sliderHeight = "7*@sf/@pf_outdated"
  sliderIncHeight = "5*@sf/@pf_outdated"
  sliderWidth = "(0.3@sf) \\ 1" 

  frameProfileTopOffset = "6@sf/@pf"
  frameHeaderPadding = "15@sf/@pf"
  centeredWndTopPosUnderLogo = "1@minYposWindow + 0.3*(sh - 1@minYposWindow - 1@bh - 1@bottomMenuPanelHeight - h)"

  focusFrameAnimOffsetMin = "0.01@sf"
  focusFrameAnimOffsetMax = "0.05@sf"

  imgFrameSize = "1.45*@profileMedalSize"
  imgFramePad = "4@sf/@pf"

  infoCircleSize = "(18@sf/@pf) \\ 1"
  infoBtnIconSize = "(22@sf/@pf) \\ 1"

  actionsListPadding = "3@dp"
  actionItemSidePadding = "8*@sf/@pf"
  menuSeparatorPadding = "15*@sf/@pf"

  wheelmenuBtnHeight = "75(@sf/1080)"

  shHud = "sh $min (0.75sw)"

  bwHud = "0.5*(sw * (1 - 1@_safearea_hud_w)) $max 1@debugRowHeight"
  bhHud = "0.5*(sh * (1 - 1@_safearea_hud_h)) $max 1@debugRowHeight"
  rwHud = "sw - 2@bwHud"
  rhHud = "sh - 2@bhHud"

  nhsf = "((sh / 1080) $max 1) * @pf" 

  fontHudTiny = "very_tiny_text_hud"
  fontHudSmall = "tiny_text_hud"
  fontHudNormal = "small_text_hud"
  fontHudMedium = "medium_text_hud"
  fontHudBigBold = "big_text_hud"

  hitCamRenderAspectRatio = "1.86"
  hitCameraWidth = "0.4*@shHud"
  hitCameraHeight = "@hitCameraWidth / @hitCamRenderAspectRatio"

  artilleryTargetArcSize = "(20/1080@shHud+1)\\2*2"
  artilleryTargetArcOffset = "(16/1080@shHud+1)\\2*2"
  artilleryTargetInnerDiameterMin = "(2/1080@shHud+1px)\\2*2 $max 4@dp"

  hudMisObjIconsSize = "32@nhsf/@pf"
  hudPadding = "10/720@scrn_tgt"

  sizeTacticalMap = "0.3*@shHud"
  sizeTacticalMapSmall = "0.05*@shHud * 5 + 0.002*@shHud * 4"
  sizeDamageIndicatorFull = "0.3*@shHud"
  sizeDamageIndicator = "0.62@sizeDamageIndicatorFull"
  multiplayerScoreHeight = "36@dp"
  missionProgressHeight = "@hudMisObjIconsSize + 1@blockInterval"
  multiplayerScoreHeightWithOffset = "0.08@scrn_tgt"

  topCenterMessagesTopPos = "0.06@shHud"
  topCenterMainMessagesMinHeight = "0.15@shHud"

  missionResultNestHeight = "0.0666@sf"

  tankGunsAmmoBlockHeight = "0.03@shHud"
  notificationsWithCompassTopOffset = "60@sf/@pf"

  hitcamDebuffIconSize = "0.02@shHud \\ 1"
  hitcamDebuffPadding = "0.003@shHud"
  hitcamDebuffPaddingBig = "2@hitcamDebuffPadding"

  killerCardProfileBgScale = "1.05" 

  infantryShortcutImageHeight = "0.025@shHud"

  enemyDmgStatusPanelWidth = "98%@hitCameraWidth"
  enemyDmgStatusPanelHeight = "12%@hitCameraWidth"
  enemyDmgStatusPanelMarginBottom = "1%@hitCameraWidth"
  enemyDmgStatusWidth = "@enemyDmgStatusPanelWidth / 10.5"

  spectatorTopOffset = "45@sf/@pf"
  spectatorTableWidth = "1@nameWidth +1.5@tableIcoSize +1@tablePad +2 + 2@scrollBarSize"
  teammateStatWidth = "35@sf/@pf"
  spectatorRowWidth = "1.4@spectatorTableWidth"
  spectatorRowHeight = "1.4@baseTrHeight"
  spectatorToolbarBtnSize = "1.5@sIco"
  spectatorToolbarPadding = "0.25@sIco"
  spectatorUnitBlockWidth = "2@tableIcoSize"
  spectatorIconBlockWidth = "2@cIco + 1@spectatorUnitBlockWidth + 1@teammateStatWidth + 3@sf/@pf"
  spectatorBw = "1@bw - 1@bwInVr"
  spectatorTimerProgressWidth = "240@sf/@pf"

  actionIconSize = "52@sf/@pf"
  arrowIconSize = "24@sf/@pf"
  fixedPresetWidth = "280@sf/@pf"
  fixedPresetHeight = "104@sf/@pf"
  fixedPresetGap = "6@blockInterval"
  damageControlIconSize = "124@sf/@pf"

  awsCounterMeasureHeight = "(0.032*@shHud)\\1"
  awsItemHeight = "(0.06*@shHud)\\1"
  awsPadBottom = "(0.022*@shHud)\\1"
  awsPadCounterMeasures = "(0.008*@shHud)\\1"
  awsHeight = "3@awsPadCounterMeasures + 1@awsPadBottom + 1@awsItemHeight + 1@awsCounterMeasureHeight"
  awsPinnedScale = "0.75"
  awsPinnedSize = "1@awsPinnedScale * 1@awsItemHeight"

  apsItemHeight = "(0.75*0.06*@shHud)\\1"
  apsShiftY = "50@sf/@pf"

  wwMapActiveWidth = "1@_safearea_menu_w*sw"
  wwMapOffset = "((sw - 1@wwMapActiveWidth) / 2) \\ 1"
  wwMapQueueInfoYpos = "1@topBarHeight + 3@sf/@pf"

  headerIndent = "0.02@scrn_tgt"
  bigArmyGroupIconSize = "48*@sf/@pf_outdated"

  objectiveBlockHeaderHeight = "1@sIco + 8*@sf/@pf_outdated + 2*@sf/@pf_outdated"
  logBlockHeaderHeight = "1@objectiveBlockHeaderHeight"
  objectiveHeight = "0.06@sf + 2@wwMapInterlinePadding"
  unitStringHeight = "0.026@sf + 1@wwMapInterlinePadding"

  wwArmyIco = "(36*@sf/@pf_outdated) \\ 1"

  statusPanelHeight = "0.035@sf"
  ownerPanelHeight = "0.03@sf"
  flyOutSliderWidth = "0.2@scrn_tgt"

  wwBattleBackgroundShadowLedge = "0.2@sf \\ 1"

  wwWindowListBackgroundPadding = "0.01@scrn_tgt"
  wwOperationMapMinSize = "0.4@scrn_tgt"

  wwLogTimeColumnWidth = "78@sf/@pf"
  wwLogZoneColumnWidth = "36*@sf/@pf_outdated"

  wwBattleInfoMapMaxSize = "0.33@scrn_tgt+0.2@wwBattleInfoScreenIncHeight"
  wwBattleMapShadowPadding = "6*@sf/@pf_outdated"
  wwBlockTabMinWidth = "22*@sf/@pf_outdated"

  wwMapBlockStretcher = "(sh - 1@sf) * 0.15"
  content2BlockHeight = "0.305@sf + 1@wwMapBlockStretcher"
  content3BlockHeight = "0.275@sf + 1@wwMapBlockStretcher"

  wwMapInterlinePadding = "(sh - 1@sf) * 0.03"
  wwMapInterlineStrengthPadding = "(sh - 1@sf) * 0.01"

  wwBattleInfoScreenIncHeight = "sh - 1@sf"
  wwFlyOutScreenInfoWidth = "1@slot_interval +1@flyOutSliderWidth +2@sliderButtonSquareHeight +1@buttonWidth +1@slot_button_fullWidth +2@slot_interval +1@modItemWidth +1@modItemHeight"
  roleArmyWidth = "240@sf/@pf"
  wwFlyOutScreenInfoWidthByGroup = "1@wwFlyOutScreenInfoWidth - 1@modItemWidth + 1@roleArmyWidth"

  wwArmySmallIconWidth = "36*@sf/@pf"
  wwSmallCountryFlagWidth = "67*@sf/@pf"
  wwSmallCountryFlagHeight = "1@wwSmallCountryFlagWidth"

  wwGlobeTooltipPadding = "15@sf/@pf"
  wwPopupPadding = "5@blockInterval"
  wwPopupGradientHeight = "500@sf/@pf"
  wwPopupContentTop = "470@sf/@pf"

  wwRewardItemHeight = "1@itemHeight + 1@battlePassFlagSize + 1@buttonHeight + 2@blockInterval"

  bulletAnimationHeight = "(152@sf/@pf)\\1"
  bulletAnimationWidth = "4@bulletAnimationHeight"

  tooltipAnimationHeight = "3/4@tooltipAnimationWidth\\1"
  tooltipAnimationWidth = "(600@sf/@pf)\\1"
  weaponFrameBlockInterval = "(7@sf/@pf)\\1"
  weaponFramePadding = "(11@sf/@pf)\\1"

  weaponsPresetDescriptionWidth = "1@bulletTooltipCardWidthNarrow+1@scrollBarSize+2@framePadding"

  penetrationTableFirstColWidth = "50@sf/@pf"

  bulletGraphLineThickness = "(2 * (2@sf/@pf\\2)) $max 2"
  bulletGraphPointSize = "(2 * (6@sf/@pf\\2)) $max 6"
  bulletGraphSlotHeight = "(70@sf/@pf)\\1"

  subUnlockProgressBarWidth = "350@sf/@pf"

  itemPadding = "(5/720@sf)\\1"
  itemSpacing = "(0.5@smallButtonHeight)\\1"
  itemIconWidth = "1@itemIconHeight"
  itemHeight = "1@itemIconHeight + 2@itemPadding"
  itemWidth = "1@itemIconWidth + 2@itemPadding"
  itemIconBlockHeight = "2@itemHeight-4@itemPadding"
  itemIconBlockWidth = "2@itemWidth-4@itemPadding"
  periodRewardIconWidth = "0.75@itemWidth"
  periodRewardIconWidthInItem = "0.6@itemWidth"
  periodRewardProgressBarIconWidth = "36@sf/@pf"
  periodRewardProgressBarIconHeight = "30@sf/@pf"

  awardItemHeaderHeight = "70@sf/@pf"
  arrowOfEveryDayLoginAwardWidth = "44@sf/@pf"
  arrowOfEveryDayLoginAwardHeight = "19@sf/@pf"

  itemInfoWidth = "0.5@sf"
  itemsSeparatorSize = "1@dp"
  recipeInterval = "(14@sf/@pf) \\ 1"

  itemPercentHeight = "0.18@itemIconHeight"

  loopProgressHeight = "0.03@sf"

  trophiesGroupAvailableWidth = "1@maxWindowWidth - 1@trophiesGroupItemsInfoBlockWidth"
  trophiesGroupItemsInfoBlockWidth = "1@itemInfoWidth + 2@framePadding + 2@itemSpacing + 1@scrollBarSize + 1@blockInterval"
  requiredItemsInColumnInPixels = "1@rh - 1@titleLogoPlateHeight - 1@frameFooterHeight - 1@frameHeaderHeight - 2@framePadding - 1@itemSpacing - 1@gamercardHeight"

  warbondShopLevelProgressHeight = "0.025@sf"
  warbondShopLevelItemHeight = "1@warbondShopLevelProgressHeight + 0.02@sf"

  battleTasksHardMedalWidth = "0.045@sf"

  trophyWndWidth = "0.85@sf + 2@framePadding"
  trophyWndPad = "(1@trophyWndWidth - 5@itemWidth)/2"
  rewardInTrophyWndTopPos = "0.035@scrn_tgt"

  compactItemHeight = "(0.75@itemHeight) \\ 1"
  smallItemHeight = "(0.5@itemHeight) \\ 1"

  craftTreeBlockInterval = "(60@sf/@pf) \\ 1"
  compactCraftTreeBlockInterval = "0.75@craftTreeBlockInterval \\ 1"
  smallCraftTreeBlockInterval = "0.75@craftTreeBlockInterval \\ 1"
  headerAndCraftTreeBlockInterval = "(0.5@craftTreeBlockInterval) \\ 1"

  craftTreeItemInterval = "(50@sf/@pf) \\ 1"
  compactCraftTreeItemInterval = "(0.75@craftTreeItemInterval) \\ 1"
  smallCraftTreeItemInterval = "(0.5@craftTreeItemInterval) \\ 1"

  craftTreeResourceWidth = "(110@sf/@pf) \\ 1"
  compactCraftTreeResourceWidth = "(0.75@craftTreeResourceWidth) \\ 1"
  smallCraftTreeResourceWidth = "(0.5@craftTreeResourceWidth) \\ 1"

  subsetComboBoxWidth = "(0.4@sf) \\ 1"

  workshoPreviewHeight = "770@sf/@pf $min 1@rh"
  startCraftImgHeight = "0.6@sf"

  itemWithRecyclingSpacingY = "(54@sf/@pf) \\ 1"

  ingameCurrencyShopItemWidth = "(342@sf/@pf) \\ 1"
  ingameCurrencyShopItemHeight = "(230@sf/@pf) \\ 1"
  ingameCurrencyShopItemMargin = "(24@sf/@pf) \\ 1"

  eventSlotWidth = "380@sf/@pf"
  rewardSlotHeight = "230@sf/@pf"

  eSItemWidth = "(374@sf/@pf) \\ 1"
  eSItemHeight = "(528@sf/@pf) \\ 1"
  eSItemPNGHeaderHeight = "(56@sf/@pf) \\ 1"
  eSItemHeaderHeight = "(24@sf/@pf) \\ 1"
  eSItemPadding = "(18@sf/@pf) \\ 1"
  eSItemMargin = "(14@sf/@pf) \\ 1"
  eSItemInterval = "(10@sf/@pf) \\ 1"
  eSItemBgrTopPos = "1@eSItemHeaderHeight + 1@eSItemInterval"
  eSItemBgrHeight = "1@eSItemHeight - 1@eSItemBgrTopPos"
  eSRatingIco = "(38@sf/@pf) \\ 1"

  eSItemCountriesTopPos = "(310@sf/@pf) \\ 1"
  eSItemButtonHeight = "(49@sf/@pf) \\ 1"
  eSItemCornerSize = "(69@sf/@pf) \\ 1"
  eSItemIcoSize = "(33@sf/@pf) \\ 1"
  tournamentNameTextPos = "1@eSItemCountriesTopPos + 2@eSItemIcoSize + 2@eSItemInterval"

  eSDayBgrWidth = "(540@sf/@pf) \\ 1"
  eSDayBgrHeight = "(40@sf/@pf) \\ 1"
  eSBtnTextPadding = "(24@sf/@pf) \\ 1"
  eSEventBtnWidth = "(380@sf/@pf) \\ 1"
  eSEventBtnHeight = "(68@sf/@pf) \\ 1"
  eSEventHeaderHeight = "(108@sf/@pf) \\ 1"
  eSEventContentHeight = "sh-1@bh-0.15@rh-1@eSDayBgrHeight-1@eSEventHeaderHeight"

  battlePassStageWidth = "1@itemWidth"
  battlePassFlagSize = "50*@sf/@pf \\ 1"
  battlePassFlagBigSize = "84@sf/@pf \\ 1"
  battlePassFlagSmallSize = "1@dIco"
  battlePassStageHeight = "1@itemHeight + 1@battlePassFlagSize + 1@buttonHeight + 2@blockInterval"
  battlePassStageMargin = "2@dp"
  battlePassFreeTextHeight = "1@fontHeightNormal + 10@sf/@pf"
  battlePassFreeTextMargin = "1@dp"
  battlePassRankInfoHeight = "128@sf/@pf \\ 1"
  battlePassBigFlagTextAbsPos = "0.5@battlePassRankInfoHeight - 0.5@battlePassFlagBigSize + 1@blockInterval"
  battlePassStampWidth = "135@sf/@pf \\ 1"
  battlePassStampHeight = "41@sf/@pf \\ 1"

  battlePassPromoBottomMargin = "1@battlePassFreeTextHeight"
  battlePassWndPreferredWidth = "(10@battlePassStageWidth + 12@battlePassStageMargin) \\ 1"
  battlePassWndPreferredPromoHeight = "(0.55*450/800)@battlePassWndPreferredWidth"
  battlePassWndPromoHeight = "1@battlePassWndPreferredPromoHeight $min (1@maxWindowHeight - 2@frameHeaderHeight - 1@battlePassStageHeight - 2@battlePassFreeTextHeight- 2@battlePassStageMargin - 1@frameFooterHeight)"
  battlePassWndPromoWidth = "(800.0/450)@battlePassWndPromoHeight"

  profileHeaderPadding = "28@sf/@pf"
  profileHeaderTopPadding = "20@sf/@pf"
  profileHeaderBottomPadding = "20@sf/@pf"
  medalItemMargin = "8@sf/@pf"
  collectionItemMargin = "8@sf/@pf"
  unlockListRightMargin = "13@sf/@pf"
  maxAccountHeaderHeight = "54@sf/@pf + 1@frameHeaderHeight + 1@avatarButtonSize + 1@profileHeaderTopPadding + 1@profileHeaderBottomPadding + 1@bh - 1@bhInVr"
  minAccountHeaderHeight = "1@frameProfileTopOffset + 1@frameHeaderHeight + 1@buttonHeight + 7@sf/@pf + 1@bh - 1@bhInVr"
  accountHeaderWidth = "720@sf/@pf"

  profileFrameWidth = "1.0 *(1@rw-2@framePadding)"
  maxProfileContentWidth = "1.0 * (2080@sf/@pf - 2@framePadding)"

  profilePageRightPartWidth = "(0.7938 * @profileFrameWidth) $min 1642@sf/@pf"
  profilePagePartsMargin = "(0.013 * @profileFrameWidth) $min 26@sf/@pf"

  profileUnockIconWidth = "160@sf/@pf"
  profileUnockIconPadding = "26@sf/@pf"
  profileSeparatorExtraWidth = "128@sf/@pf"
  maxProfileFrameWidth = "2560@sf/@pf - 2@framePadding"
  beyondScrollbarSize = "10@sf/@pf"
  countriesSmallListHeight = "50@sf/@pf"
  comboboxSmallFontPixHt = "22@sf/@pf \\ 1"

  smallProfileHeaderH = "130@sf/@pf"
  profileHeaderH = "190@sf/@pf"
  favoriteUnitImageHeight = "280@sf/@pf"
  showcaseLinePadding = "13@sf/@pf"
  showcaseStatValHeight = "42@sf/@pf \\ 1"
  showcaseStatNameHeight = "18@sf/@pf \\ 1"
  showcaseStatIconSize = "55@sf/@pf"
  showcaseMinStatHeight = "159@sf/@pf"
  favoriteUnitShowcaseHeight = "1@favoriteUnitImageHeight + 2@showcaseLinePadding + 2@showcaseMinStatHeight + 1@showcaseStatNameHeight + 1@showcaseLinePadding"
  collectionMainPrizeWidth = "(pw - 7@collectionItemMargin)/4 + 1@collectionItemMargin"
  frameSeparatorHeight = "1@sf/@pf"
  profileBgImageAspectRatio = "1920/260 \\1"

  mapPreferenceIconSize = "(170*@sf/@pf) \\ 1"
  mapPreferenceIconMargin = "2@blockInterval"
  mapPreferenceIconNestWidth = "1@mapPreferenceIconSize + 1@mapPreferenceIconMargin"
  mapPreferencePreviewSize = "(500*@sf/@pf) \\ 1"
  mapPreferenceListHeight = "1@maxWindowHeight - 1@frameHeaderHeight - 1@frameTopPadding - 1@framePadding - 1@buttonHeight - 1@mapPreferenceIconMargin"
  mapPreferencePreviewFullWidth = "1@mapPreferenceIconMargin + 2@framePadding + 1@dp + 1@mapPreferencePreviewSize"

  posOptionCellPadding = "3" 

  modalInfoWindowWidth = "554@sf/@pf"
  modalInfoWindowMargin = "10@sf/@pf"
  modalInfoBlocksInterval = "8@sf/@pf"
  modalInfoKeyWidth = "0.4783@modalInfoWindowWidth"
  airInfoKeyWidth = "0.4783@airInfoPanelWidth"
  modalInfoValueMargin = "30@sf/@pf"
  unitPackCardSize = "330@sf/@pf"
  weaponsCountColWidth = "45@sf/@pf"
  modalInfoTierIconSize = "41@sf/@pf"

  mis_chapter_font = "@fontMedium"
  mis_chapter_selected_font = "@fontMedium"
  mis_item_font = "@fontNormal"
  mis_item_selected_font = "@fontNormal"
  shopItemFont = "@fontSmall"
  slotItemFont = "@fontSmall"

  missionBoxImageOffsetX = "12*@sf/@pf_outdated"
  missionItemTextPaddingLeft = "3@sf/@pf"
  bigMedalPlaceYpos = "2@scrn_tgt/100.0"
  campaignMarginTop = "10*@sf/@pf_outdated"

  unlockIconSize = "4.44*@scrn_tgt/100.0"
  unlockHeaderIconSize = "4.44*@scrn_tgt/100.0"
  unlockBlockInterval = "(12@sf/@pf) \\ 1"

  selImgLeftPadding = "14*@sf/@pf"
  selImgRightPadding = "11*@sf/@pf"
  selImgBottomPadding = "8*@sf/@pf"
  unlockSimplifiedDescPadding = "1@sf/100.0"

  gameModeChangeButtonHeight = "0.028@sf"
  gameModeSelectWindowBlockMargin = "2@dp"
  gameModeSelectWindowBlockWidth = "2*(0.2@scrn_tgt \\ 1)" 

  gameModeSelectWindowBlockWidthWide = "3@gameModeSelectWindowBlockWidth + 2@gameModeSelectWindowBlockMargin"
  gameModeSelectWindowBlockWidthHalf = "1.5@gameModeSelectWindowBlockWidth + 0.5@gameModeSelectWindowBlockMargin"
  gameModeSelectWindowWidth = "3@gameModeSelectWindowBlockWidth + 4@gameModeSelectWindowBlockMargin + 1@scrollBarSize"

  debrBarContentPad = "12@sf/@pf"
  debrPad = "25@sf/@pf"
  debrBigGap = "2.5@debrPad"
  debrWndPad = "4@dp"
  debrMyPlaceBlockOffset = "0.5@debrPad"
  debrBonusHeight = "85@sf/@pf"
  debrBonusWidth = "42/64@debrBonusHeight"
  debrBonusIcoSize = "@debrBonusHeight"
  debrWagerHeight = "95@sf/@pf"
  debrSepWidth = "1@dp"

  arrowButtonHeight = "0.042@sf"
  arrowBaseBtnWidth = "1/3@mIco"
  contentRightPadding = "1@arrowButtonHeight + 1@blockInterval"
  arrowButtonWidth = "4@smallItemHeight"
  maxPromoButtonWidth = "1@arrowButtonWidth + 1@arrowBaseBtnWidth + 1@newWidgetIconHeight + 1@scrollBarSize + 0.13@sf"
  promoButtonMinHeight = "1@smallItemHeight + 1@arrowButtonHeight + 2@dp"

  promoButtonSizeWithOffsets = "1@mIco"
  imageRouletteTextAreaHeigth = "48@sf/@pf"

  airInfoToggleButtonSize = "@mIco + 2@buttonImgPadding"
  promoButtonWidth = "1@arrowButtonWidth + 1@contentRightPadding"

  squadInvitesWidgetPadding = "6@sf/@pf"
  squadMemberCrossPlaySize = "(9@sf/@pf) \\1 * 2"
  squadMemberStatusSize = "(3@sf/@pf) \\1 * 2"
  squadMemberLeaderStatusSize = "(6@sf/@pf) \\1 * 2"

  firstChoiceUserIconHeight = "48@sf/@pf"
  firstChoiceHeaderHeight = "0.05@scrn_tgt"
  countryChoiceInterval = "16@sf/@pf"
  startingUnitSlotsInterval = "10@sf/@pf"
  firstChoiceCountriesColmns = "3"

  countryChoiceInfoWidth = "(@firstChoiceCountriesColmns - 1)*1@slot_width + 1@startingUnitSlotsInterval * @firstChoiceCountriesColmns"
  countryChoiceWndMaxWidth = "(1920@sf/@pf $min 1@rw) - 80@sf/@pf"
  countryChoiceImageWidth = "((1@countryChoiceWndMaxWidth - 1@countryChoiceInfoWidth - 1@countryChoiceInterval * @firstChoiceCountriesColmns)/@firstChoiceCountriesColmns)\\1"
  countryVideoAspectRatio = "9/16"
  countryChoiceImageHeight = "(1@countryVideoAspectRatio * 1@countryChoiceImageWidth)\\1"

  unitVideoAspectRatio = "0.5"
  unitChoiceImageWidth = "((1@countryChoiceWndMaxWidth - 3@countryChoiceInterval)/4)\\1"
  unitChoiceImageHeight = "(1@unitVideoAspectRatio * 1@unitChoiceImageWidth)\\1"

  firstChoiceShadowH = "0.36ph"

  popupFilterRowHeight = "1@buttonHeight"

  baseToggleButtonWidth = "1@dIco"

  steamButtonWidth = "0.3@sf\\1"
  steamButtonHeight = "0.055@sf\\1"

  infantryBlockMargin = "17@sf/@pf"
  infantryCustomizationWidth = "378@sf/@pf"
  infantrySkinItemWidth = "(1@infantryCustomizationWidth - 3@infantryBlockMargin)/2"

  limitBuyUnitWidth = "366@sf/@pf"
  limitBuyUnitHeight = "362@sf/@pf"
  limitBuyUnitContentWidth = "350@sf/@pf"
  limitBuyUnitContentHeight = "346@sf/@pf"

  presetTabHeight = "1@bottomMenuPanelHeight - 1@blockInterval"
  editPresetsItemHeight = "50@sf/@pf"
  hoverButtonHeight = "(32*@sf/@pf) \\ 1"

  contAreaScrlOffset = "2px" 

  scrollBarVisibleSize = "(8@sf/@pf) \\ 1"
  scrollBarSize = "1@scrollBarVisibleSize + 1@contAreaScrlOffset"
  scrollArrowsSize = "3.5*@scrn_tgt/100.0"
}
