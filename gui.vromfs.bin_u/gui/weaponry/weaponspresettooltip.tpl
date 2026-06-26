tdiv {
  flow:t='vertical'
  width:t='pw'

  <<#reqText>>
  weaponTooltipBlock {
    width:t='pw'
    <<^presetsNames>>
    margin-bottom:t='1/2@bulletTooltipPadding'
    <</presetsNames>>
    padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
    tooltipDesc {
      text:t='<<reqText>>'
    }
  }
  <</reqText>>

  weaponTooltipBlock {
    flow:t='vertical'
    width:t='pw'

    <<#presetsNames>>
    weaponPresetTooltipHeader {
      flow:t='vertical'
      width:t='pw'
      padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
      background-color:t='@frameHeaderBackgroundColor'

      <<#names>>
      include "%gui/weaponry/weaponsPresetTooltipTitle.tpl"
      <</names>>
    }
    <</presetsNames>>

    <<^presetsNames>>
    <<#presetsWeapons>>
    tdiv {
      width:t='pw'
      flow:t='vertical'

      weaponPresetTooltipHeader {
        width:t='pw'
        padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
        background-color:t='@frameHeaderBackgroundColor'

        include "%gui/weaponry/weaponsPresetTooltipTitle.tpl"
      }
      weaponPresetTooltipParams {
        width:t='pw'
        <<^noInternalPadding>>
        padding:t='1@bulletTooltipPadding, 1@bulletTooltipPadding, 1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
        <</noInternalPadding>>
        <<#noInternalPadding>>
        padding:t='0'
        <</noInternalPadding>>
        flow:t='vertical'

        <<#presetParams>>
        <<^divider>>
        tdiv {
          width:t='pw'
          flow:t='h-flow'
          margin-bottom:t='1/2@bulletTooltipPadding'
          <<#value>>
          <<@markupValue>>
          textareaNoTab {
            max-width:t='pw'
            text:t='<color=@activeTextColor><<value>></color> - <<text>>'
            smallFont:t='yes'
            <<#additionalMarkup>>
            valign:t='center'
            <</additionalMarkup>>
            overlayTextColor:t='minor'
          }
          <<@additionalMarkup>>
          <</value>>
        }
        <</divider>>

        <<#divider>>
        horizontalLine {
          width:t='pw'
          margin-top:t='1/2@bulletTooltipPadding'
          margin-bottom:t='3/4@bulletTooltipPadding'
        }
        <</divider>>
        <</presetParams>>

        <<#hasPresetParamsWithImg>>
        tdiv {
          width:t='pw'
          margin-bottom:t='1/2@bulletTooltipPadding'

          <<#presetParamsWithImg>>
          tdiv {
            <<#maxPresetsInRow>>
            width:t='pw/<<maxPresetsInRow>>'
            <</maxPresetsInRow>>
            <<^maxPresetsInRow>>
            width:t='pw/2'
            <</maxPresetsInRow>>
            presetWeaponIcon {
              size:t='0.8@modItemHeight,0.8@modItemHeight'
              border-color:t='@modBorderColor'
              border:t='yes'
              margin-right:t='2@weaponIconPadding'
              <<#isDisabled>>
              iconStatus:t='disabled'
              <</isDisabled>>

              img{
                size:t='pw,pw'
                background-image:t='<<itemImg>>'
                background-svg-size:t='pw,pw'
              }
            }
            textareaNoTab {
              width:t='fw'
              max-width:t='fw'
              text:t='<<weaponNameStr>>'
              smallFont:t='yes'
              valign:t='center'
              <<#isDisabled>>
              overlayTextColor:t='faded'
              <</isDisabled>>
              <<^isDisabled>>
              overlayTextColor:t='minor'
              <</isDisabled>>
            }
          }
          <</presetParamsWithImg>>
        }
        <</hasPresetParamsWithImg>>
      }
    }
    <</presetsWeapons>>
    <</presetsNames>>

    <<#presetCompositionHint>>
    textareaNoTab {
      padding:t='1@bulletTooltipPadding, 1@bulletTooltipPadding'
      width:t='pw'
      text:t='* <<presetCompositionHint>>'
      tinyFont:t='yes'
      overlayTextColor:t='minor'
    }
    <</presetCompositionHint>>

    <<#estimatedDamageToBases>>
    estimatedDamageBlock {
      flow:t='vertical'
      width:t='pw'
      padding-bottom:t='1/2@bulletTooltipPadding'

      tooltipDesc {
        tinyFont:t='yes'
        padding:t='1@bulletTooltipPadding'
        <<#presetsNames>>
        text:t='<<estimatedDamageTitle>><<?ui/colon>>'
        <</presetsNames>>

        <<^presetsNames>>
        text:t='<<estimatedDamageTitle>>'
        background-color:t='@frameHeaderBackgroundColor'
        margin-bottom:t='1@bulletTooltipPadding'
        <</presetsNames>>
      }
      <<#params>>
      tdiv {
        padding:t='1@bulletTooltipPadding, 0'
        margin-bottom:t='1/2@bulletTooltipPadding'

        activeText { text:t='<<damageValue>>'; smallFont:t='yes' }
        textareaNoTab {
          text:t=' - <<text>>'
          smallFont:t='yes'
          valign:t='center'
          overlayTextColor:t='minor'
        }
      }
      <</params>>
    }
    <</estimatedDamageToBases>>

    <<^presetsNames>>
    <<#bulletPenetrationData>>
    include "%gui/weaponry/shellArmorPenetration.tpl"
    <</bulletPenetrationData>>
    <</presetsNames>>

    <<#delayed>>
    animated_wait_icon
    {
      id:t='delayed_icon'
      pos:t='50%pw-50%w,0'
      position:t='relative'
      background-rotation:t='0'
    }
    <</delayed>>

    tdiv {
      id:t='changeToSpecsNest'
      width:t='pw'
      include "%gui/weaponry/weaponTooltipChangeToSpecs.tpl"
    }
    <<#showFooter>>
    div {
      width:t='pw'
      include "%gui/weaponry/weaponTooltipFooter.tpl"
    }
    <</showFooter>>
  }
}

timer {
  id:t = 'weapons_timer'
  timer_handler_func:t = 'onUpdateWeaponTooltip'
  timer_interval_msec:t='100'
}
