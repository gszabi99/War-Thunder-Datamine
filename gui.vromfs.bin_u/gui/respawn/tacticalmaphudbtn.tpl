Button_text {
  class:t='shortcut'
  position:t='relative'
  accessKey:t='<<accessKey>>'
  noMargin:t='yes'
  tooltip:t = '#options/forceHudType'
  on_click:t = 'onForcedSetHudType'
  noPadding:t='yes'

  <<^isConsoleButton>>
    img {
      position:t='relative'
      id:t = 'hud_type_img'
      size:t='ph, ph'
      background-image:t='#ui/gameuiskin#objective_tank.svg'
      margin-right:t="1@blockInterval"
    }
  <</isConsoleButton>>

  shortcutContent {
    css-hier-invalidate:t='yes'
    shortcutHint {
      position:t='relative'
      height:t='1@buttonHeight'
      behaviour:t='bhvHint'
      showIfNotAssign:t='no'
      hintStyle:t='fitHeight'
      value:t='<<shortcut>>'
    }
    shortcutMask {
      position:t='absolute'
      bgcolor:t='#FFFFFF'
      size:t='pw, ph'
      display:t='hide'
    }
    <<#isConsoleButton>>
    ButtonImg {
      position:t='absolute'
      display:t='hide'
      left:t='(pw-w)/2'
      btnName:t='A'
    }
    <</isConsoleButton>>
  }
  <<#isConsoleButton>>
    img {
      position:t='relative'
      id:t = 'hud_type_img'
      size:t='ph, ph'
      background-image:t='#ui/gameuiskin#objective_tank.svg'
    }
  <</isConsoleButton>>
}