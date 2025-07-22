airWeaponSelector {
  id:t='air_weapon_selector'
  position:t='absolute'
  flow:t='vertical'
  isPinned:t='no'
  left:t='-w/2'
  css-hier-invalidate:t='yes'

  tdiv {
    id:t='countermeasures_container'
    position:t='absolute'
    pos:t='0, -h - 1@awsPadCounterMeasures'
    flow:t='horizontal'
    behaviour:t='posNavigator'
    navigatorShortcuts:t='SpaceA'
    css-hier-invalidate:t='yes'

    <<#counterMeasures>>
      airWeaponSelectorCountermeasure {
        id:t='countermeasure_<<index>>'
        amount:t='0'
        counterMeasureMode:t='<<index>>'
        on_hover:t='onCounterMeasureHover'
        on_unhover:t='onCounterMeasureUnhover'
        on_click:t='onCounterMeasureClick'
        on_dbl_click:t='onCounterMeasureClick'
        css-hier-invalidate:t='yes'
        isSelected:t='no'
        isBordered:t='no'
        <<#icon>>
        img{
          background-image:t='<<icon>>'
        }
        <</icon>>
        label {
          id:t='label'
          position:t='relative'
          text:t='<<label>>'
          nameText:t='<<label>>'
          top:t='(ph-h)/2'
          margin-left:t='0.008@shHud'
          margin-right:t='0.072@shHud'
        }
        <<#isFlareChaff>>
        tdiv {
          position:t='absolute'
          width:t='0.064@shHud'
          height:t='0.032@shHud'
          left:t='pw-w'
          top:t='(ph-h)/2'
          css-hier-invalidate:t='yes'
          tdiv {
            flow:t='horizontal'
            position:t='absolute'
            rotation:t='90'
            pos:t='(pw-w)/2, (ph-h)/2'
            css-hier-invalidate:t='yes'
            img{
              position:t='relative'
              background-image:t='#ui/gameuiskin#bullet_flare'
              size:t='0.016@shHud, 0.064@shHud'
              background-svg-size:t='0.016@shHud, 0.064@shHud'
              background-repeat:t='aspect-ratio'
              bgcolor:t='#FFFFFF'
            }

            img{
              position:t='relative'
              background-image:t='#ui/gameuiskin#bullet_chaff'
              size:t='0.016@shHud, 0.064@shHud'
              background-svg-size:t='0.016@shHud, 0.064@shHud'
              background-repeat:t='aspect-ratio'
              bgcolor:t='#FFFFFF'
            }
          }
        }
        <</isFlareChaff>>
        <<#haveShortcut>>
          <<#isXinput>>
          airWeaponSelectorCountermeasureSch {
            id:t='shortcutContainer'
            behaviour:t='BhvHint'
            position:t='absolute'
            left:t='pw/2 - w/2'
            top:t='- h - 0.005@shHud'
            value:t='<<gamepadShortcat>>'
          }
          <</isXinput>>
          <<^isXinput>>
          airWeaponSelectorCountermeasureSch {
            id:t='shortcutContainer'
            width:t='pw'
            position:t='absolute'
            pos:t='0, -h'
            re-type:t='9rect'
            background-color:t='#C0FFFFFF'
            background-repeat:t='expand'
            background-image:t='#ui/gameuiskin#block_bg_rounded_gray'
            background-position:t='4, 4, 4, 4'
            padding:t='0.002@shHud, 0.002@shHud, 0.002@shHud, 0'
            margin-bottom:t='0.004@shHud'
            min-height:t='@hudActionBarTextShHight'
            textarea{
              id:t='shortcutText'
              pos:t='pw/2-w/2, ph/2-h/2'
              position:t='relative'
              text-align:t='center'
              hudFont:t='small'
              shortcut:t='yes'
              text:t='<<shortcut>>'
            }
          }
          <</isXinput>>
        <</haveShortcut>>
        focus_border{}
      }
    <</counterMeasures>>
  }

  tdiv {
    id:t='buttons_container'
    position:t='relative'
    flow:t='horizontal'
    interactive:t='yes'
    on_unhover:t='onAirWeapSelectorUnhover'
    behaviour:t='posNavigator'
    navigatorShortcuts:t='SpaceA'
    css-hier-invalidate:t='yes'

    <<#tiersView>>
      airWeaponSelectorItem{
        id:t='tier_<<tierId>>'
        position:t='relative'
        tierId:t='<<tierId>>'
        weaponIdx:t='-1'
        hasBullets:t='no'
        isSelected:t='no'
        isBordered:t='no'
        isGun:t='<<isGun>>'
        <<^isActive>>enable:t='no'<</isActive>>
        margin:t='0.003@shHud, 0, 0.003@shHud, 0'
        on_hover:t='onAirWeapSelectorHover'
        on_unhover:t='onAirWeapSelectorUnhover'
        on_dbl_click:t='onSecondaryWeaponClick'
        on_click:t='onSecondaryWeaponClick'

        airWeaponSelectorIcon {
          background-image:t='<<#img>><<img>><</img>>'
        }
        label {
          id:t='label'
          position:t='absolute'
          text:t=''
          pos:t='0.002@shHud, ph-h'
        }

        <<#tierTooltipId>>
          title:t='$tooltipObj'
          tooltip-float:t='middleTop'
          tooltip-relative-offset:t='0, 0.003@shHud'
          tooltipObj {
            id:t='tierTooltip'
            tooltipId:t='<<tierTooltipId>>'
            on_tooltip_open:t='onGenericTooltipOpen'
            on_tooltip_close:t='onTooltipObjClose'
            display:t='hide'
          }
        <</tierTooltipId>>

        focus_border {}
      }
    <</tiersView>>
  }

  airWeaponSelectorHint {
    position:t='absolute'
    width:t='pw - 0.002@shHud'
    left:t='0.001@shHud'
    top:t='ph + 0.002@shHud'
    background-color:t='#FF000000'
    color-factor:t='102'
    tdiv{
      id:t='weapon_tooltip'
      position:t='relative'
      re-type:t='text'
      pos:t='(pw-w)/2, (ph-h)/2'
      color:t='@white'
      text-align:t='center'
      font-size:t='@fontSmall'
      text:t=' '
    }
  }

  tdiv {
    flow:t='horizontal'
    position:t='absolute'
    pos:t='pw - w - 0.002@shHud, -h - 0.008@shHud'
    css-hier-invalidate:t='yes'

    airWeaponSelectorBtn {
      id:t = 'pin_btn'
      text:t = '[]'
      position:t='relative'
      tooltip:t='#tooltip/pinWeaponSelector'
      _on_click:t = 'onPinBtn'
    }

    airWeaponSelectorCloseBtn {
      id:t='close_btn'
      position:t='relative'
      text:t=''
      on_click:t='onCancel'
      css-hier-invalidate:t='yes'

      img {
        position:t='absolute'
        re-type:t="9rect"
        size:t='0.02@shHud, 0.02@shHud'
        pos:t='pw - w - 0.01@shHud, (ph-h)/2'
        background-image:t='#ui/gameuiskin#btn_close.svg'
        background-svg-size:t='w, h'
        background-repeat:t='expand'
      }
    }

    Button_text {
      id:t = 'close_btn_consoles'
      text:t = '#mainmenu/btnClose'
      position:t='relative'
      btnName:t='B'
      padding-right:t='ph/2'
      padding-bottom:t='0.002@shHud'
      padding-top:t='0.002@shHud'
      padding-left:t='0.01@shHud'
      _on_click:t = 'onCancel'
      color:t='#AAAAAA'
      bgcolor:t='#292C32'
      display:t='hide'
      ButtonImg {}

      img {
        position:t='relative'
        re-type:t='9rect'
        size:t='ph/2, ph/2'
        top:t='(ph-h)/2'
        background-image:t='#ui/gameuiskin#btn_close.svg'
        background-svg-size:t='w, h'
        background-repeat:t='expand'
      }
    }
  }
}

DummyButton {
  btnName:t='B'
  _on_click:t='onCancel'
}

DummyButton {
  btnName:t='A'
  _on_click:t='onJoystickApplySelection'
}

timer{
  bhv:t='Timer'
  id:t='visual_selector_timer'
  timer_handler_func:t='onVisualSelectorTimer'
}