<<#bgBlocks>>
include "%gui/weaponry/weaponryBg.tpl"
<</bgBlocks>>

<<#weaponryList>>
modificationsBlock {
  id:t='weaponry_list'
  position:t='absolute'

  behavior:t='posNavigator'
  navigatorShortcuts:t='yes'
  moveX:t='closest'
  moveY:t='linear'

  on_activate:t='onWeaponryActivate'
  on_pushed:t='::gcb.delayedTooltipListPush'
  on_hold_start:t='::gcb.delayedTooltipListHoldStart'
  on_hold_stop:t='::gcb.delayedTooltipListHoldStop'

  <<@weaponryList>>
}
<</weaponryList>>

DummyButton {
  btnName:t='LB'
  _on_click:t='onBulletsDecrease'
  _on_click_repeat:t = 'onBulletsDecrease'
}

DummyButton {
  btnName:t='RB'
  _on_click:t='onBulletsIncrease'
  _on_click_repeat:t = 'onBulletsIncrease'
}