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
        textareaNoTab {
          max-width:t='pw'
          fontSmall:t='yes'
          text:t='<<presetName>>'
        }
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

        textareaNoTab {
          max-width:t='pw'
          fontSmall:t='yes'
          text:t='<<presetName>>'
        }
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
          margin-bottom:t='1/2@bulletTooltipPadding'
          <<#value>>
          textareaNoTab {
            width:t='fw'
            max-width:t='fw'
            text:t='<color=@activeTextColor><<value>></color> - <<text>>'
            smallFont:t='yes'
            valign:t='center'
            overlayTextColor:t='minor'
          }
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
            width:t='pw/2'

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
      id:t='loading'
      pos:t="50%pw-50%w,0"
      position:t='relative'
      background-rotation:t = '0'
    }
    <</delayed>>

    <<#changeToSpecs>>
    weaponPresetChangeSpecBlock {
      flow:t='vertical'
      width:t='pw'
      padding-bottom:t='1/2@bulletTooltipPadding'
      tooltipDesc {
        tinyFont:t='yes'
        padding:t='1@bulletTooltipPadding'
        <<#presetsNames>>
        text:t='<<changeSpecTitle>><<?ui/colon>>'
        <</presetsNames>>

        <<^presetsNames>>
        text:t='<<changeSpecTitle>>'
        background-color:t='@frameHeaderBackgroundColor'
        margin-bottom:t='1@bulletTooltipPadding'
        <</presetsNames>>
      }

      <<#changeToSpecsParams>>
      tdiv {
        width:t='pw'
        padding:t='1@bulletTooltipPadding, 0'
        margin-bottom:t='1/2@bulletTooltipPadding'
        <<#effectValue>>
        textareaNoTab {
          width:t='fw'
          max-width:t='fw'
          text:t='<<effectValue>> - <<text>>'
          smallFont:t='yes'
          valign:t='center'
          overlayTextColor:t='minor'
        }
        <</effectValue>>
      }
      <</changeToSpecsParams>>

      textareaNoTab {
        padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
        width:t='pw'
        text:t='<<changeSpecNotice>>'
        tinyFont:t='yes'
        overlayTextColor:t='minor'
      }
    }
    <</changeToSpecs>>

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
