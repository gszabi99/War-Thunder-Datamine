tdiv {
  flow:t='vertical'

  weaponTooltipBlock {
    width:t='1@bulletTooltipCardWidth'
    flow:t='vertical'

    textareaNoTab {
      padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
      text:t='<<name>>'
    }

    <<#showArmorDesc>>
    <<#armorWeight>>
    armorParams {
      padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
      margin-bottom:t='@bulletTooltipPadding'
      activeText { text:t='<<armorWeight>>'; smallFont:t='yes' }
      textareaNoTab {
        text:t=' - <<armorWeightText>>'
        smallFont:t='yes'
        valign:t='center'
        overlayTextColor:t='minor'
      }
    }
    <</armorWeight>>

    armorCompositionDescrTable {
      width:t='pw'
      flow:t='vertical'

      tooltipDesc {
        tinyFont:t='yes'
        text:t='#armor_parameters/composition'
        padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
        background-color:t='@frameHeaderBackgroundColor'
      }

      armorCompositionDescrTableRows {
        flow:t='vertical'
        width:t='pw'

        <<#armorDescArray>>
        tdiv {
          width:t='pw'

          textareaNoTab {
            width:t='pw*1/2'
            padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
            <<^isMainPart>>
            padding-left:t='2@bulletTooltipPadding'
            <</isMainPart>>
            text:t='<<armorPartName>>'
            smallFont:t='yes'
          }
          verticalLine {
            position:t='absolute'
            pos:t='pw*1/2,0'
            height:t='ph'
          }
          textareaNoTab {
            width:t='pw*1/4'
            text-align:t='center'
            valign:t='center'
            text:t='<<partThickness>>'
            smallFont:t='yes'
            padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
            <<^isHeaderRow>>
            overlayTextColor:t='active'
            <</isHeaderRow>>
          }
          textareaNoTab {
            width:t='pw*1/4'
            text-align:t='center'
            valign:t='center'
            text:t='<<partMaterial>>'
            smallFont:t='yes'
            padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
            <<^isHeaderRow>>
            overlayTextColor:t='active'
            <</isHeaderRow>>
          }
          <<#isHeaderRow>>
          horizontalLine {
            width:t='pw'
            position:t='absolute'
            pos:t='0,ph'
          }
          <</isHeaderRow>>
        }
        <</armorDescArray>>
      }
    }
    <</showArmorDesc>>
  }
}