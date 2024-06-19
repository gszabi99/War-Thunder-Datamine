tdiv {
  flow:t='vertical'
  tdiv {
    id:t='countermeasures_container'
    position:t='absolute'
    pos:t='0, -h - 0.008@shHud'
    flow:t='horizontal'

    airWeaponSelectorCountermeasure {
      id:t='countermeasure_1'
      amount:t='0'
      counterMeasureMode:t='1'
      on_hover:t='onCounterMeasureHover'
      on_unhover:t='onCounterMeasureUnhover'
      on_click:t='onCounterMeasureClick'
      isSelected:t='no'
      isBordered:t='no'
      img{
        background-image:t='#ui/gameuiskin#bullet_flare'
      }
      label {
        id:t='label'
        position:t='relative'
        text:t='#HUD/FLARES_SHORT'
        top:t='(ph-h)/2'
        margin-left:t='0.008@shHud'
        margin-right:t='0.072@shHud'
      }
    }

    airWeaponSelectorCountermeasure {
      id:t='countermeasure_2'
      amount:t='0'
      counterMeasureMode:t='2'
      on_hover:t='onCounterMeasureHover'
      on_click:t='onCounterMeasureClick'
      on_unhover:t='onCounterMeasureUnhover'
      isSelected:t='no'
      isBordered:t='no'
      img{
        background-image:t='#ui/gameuiskin#bullet_chaff'
      }
      label {
        id:t='label'
        position:t='relative'
        text:t='#HUD/CHAFFS_SHORT'
        top:t='(ph-h)/2'
        margin-left:t='0.008@shHud'
        margin-right:t='0.072@shHud'
      }
    }

    airWeaponSelectorCountermeasure {
      id:t='countermeasure_0'
      counterMeasureMode:t='0'
      amount:t='0'
      on_hover:t='onCounterMeasureHover'
      on_click:t='onCounterMeasureClick'
      on_unhover:t='onCounterMeasureUnhover'
      isSelected:t='no'
      isBordered:t='no'
      label {
        id:t='label'
        position:t='relative'
        text:t='<<ltcDoLabel>>'
        top:t='(ph-h)/2'
        margin-left:t='0.008@shHud'
        margin-right:t='0.072@shHud'
      }

      tdiv {
        position:t='absolute'
        width:t='0.064@shHud'
        height:t='0.032@shHud'
        left:t='pw-w'
        top:t='(ph-h)/2'
        tdiv {
          flow:t='horizontal'
          position:t='absolute'
          rotation:t='90'
          pos:t='(pw-w)/2, (ph-h)/2'
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
    }
  }

  tdiv {
    id:t='buttons_container'
    position:t='relative'
    flow:t='horizontal'
    interactive:t='yes'
    on_unhover:t='onAirWeapSelectorUnhover'

    <<#tiersView>>
      airWeaponSelectorItem{
        id:t='tier_<<tierId>>'
        tierId:t='<<tierId>>'
        weaponIdx:t='-1'
        hasBullets:t='no'
        isSelected:t='no'
        isBordered:t='no'
        <<^isActive>>enable:t='no'<</isActive>>
        margin-left:t='0.002@shHud'
        margin-right:t='0.002@shHud'
        on_hover:t='onAirWeapSelectorHover'
        on_unhover:t='onAirWeapSelectorUnhover'
        on_click:t='onSecondaryWeaponClick'
        on_dbl_click:t='onSecondaryWeaponClick';

        airWeaponSelectorIcon {
          background-image:t='<<#img>><<img>><</img>>'
        }

        <<#tierTooltipId>>
          title:t='$tooltipObj'
          tooltip-float:t='horizontal'
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

  tdiv {
    width:t='pw - 0.002@shHud'
    left:t='0.001@shHud'
    top:t='ph + 0.001@shHud'
    position:t='absolute'
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

  airWeaponSelectorCloseBtn {
    position:t='absolute'
    pos:t='pw - w - 0.002@shHud, -h - 0.008@shHud'
    text:t='<<closeBtnLabel>>'
    padding-right:t='ph/2'
    on_click:t='onCancel'
    padding-bottom:t='0.002@shHud'
    padding-top:t='0.002@shHud'
    padding-left:t='0.01@shHud'

    img {
      position:t='absolute'
      re-type:t="9rect"
      size:t='ph/2, ph/2'
      pos:t='pw - w - w/2, (ph-h)/2'
      background-image:t='#ui/gameuiskin#btn_close.svg'
      background-svg-size:t='w, h'
      background-repeat:t='expand'
    }
  }

}

DummyButton {
  btnName:t='B'
  _on_click:t='onCancel'
}