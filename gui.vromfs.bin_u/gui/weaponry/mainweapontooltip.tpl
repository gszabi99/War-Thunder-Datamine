tdiv {
  flow:t='vertical'

  weaponTooltipBlock {
    flow:t='vertical'
    min-width:t='1@bulletTooltipCardWidthNarrow'
    css-hier-invalidate:t='yes'

    weaponsListBlock {
      flow:t='vertical'
      padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'

      <<#weaponsList>>
      tdiv {
        padding:t='0, 1/2@bulletTooltipPadding'
        <<#turretName>>
        activeText { text:t='<<turretName>>'; smallFont:t='yes' }
        <</turretName>>
        tdiv {
          flow:t='vertical'
          <<#turretName>>
          margin-left:t='1/2@bulletTooltipPadding'
          <</turretName>>
          <<#titlesAndAmmo>>
          tdiv {
            activeText { text:t='<<weaponTitle>>'; smallFont:t='yes' }
            textareaNoTab {
              text:t='<<ammo>>';
              smallFont:t='yes'
              overlayTextColor:t='minor';
              margin-left:t='1/2@bulletTooltipPadding'
            }
          }
          <</titlesAndAmmo>>
        }
      }
      <</weaponsList>>
    }

    <<#weaponsModifications>>
    weaponsModificationsBlock {
      position:t='absolute'
      top:t='ph'
      flow:t='vertical'
      width:t='pw'
      border:t='yes'
      border-color:t='@frameDarkMenuBorderColor'
      background-color:t='@weaponCardBackgroundColor'
      padding-bottom:t='1@bulletTooltipPadding'

      tooltipDesc {
        tinyFont:t='yes'
        text:t='<<title>>'
        padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
        background-color:t='@frameHeaderBackgroundColor'
      }

      <<#modifications>>
      textareaNoTab {
        text:t='<<modName>>'
        smallFont:t='yes'
        padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
        <<#active>>
        overlayTextColor:t='active';
        <</active>>
        <<^active>>
        overlayTextColor:t='minor';
        <</active>>
      }
      <</modifications>>
    }


    <</weaponsModifications>>
  }
}