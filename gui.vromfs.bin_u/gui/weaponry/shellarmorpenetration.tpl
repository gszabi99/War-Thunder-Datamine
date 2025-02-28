<<#bulletPenetrationData>>
shellTooltipPenetrationBlock {
  flow:t='vertical'
  width:t='1@bulletTooltipCardWidth'

  tooltipDesc {
    tinyFont:t='yes'
    text:t='<<title>>'
    padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
    background-color:t='@frameHeaderBackgroundColor'
  }

  tdiv {
    padding:t='1@bulletTooltipPadding, 0'
    flow:t='vertical'

    <<#highEnergyPenetration>>
    shellTooltipHighEneryAction {
      width:t='1@bulletAnimationWidth'
      flow:t='vertical'

      tdiv {
        padding:t='0, 1@bulletTooltipPadding'
        activeText {
          pos:t='0, 0.5ph-0.5h'
          position:t='relative'
          text:t='<<highEnergyPenetration>>'
          smallFont:t='yes'
        }
        textareaNoTab {
          text:t=' - <<?bullet_properties/armorPiercing/explosive>>'
          valign:t='center'
          overlayTextColor:t='minor'
          smallFont:t='yes'
        }
        img {
          size:t='1@sIco, 1@sIco'
          pos:t='1@blockInterval, 0.5ph-0.5h'
          position:t='relative'
          background-image:t='!#ui/gameuiskin#penetration_high_explosive_fragmentation_icon.svg'
          background-svg-size:t='1@sIco, 1@sIco'
        }
      }
    }

    horizontalLine { width:t='1@bulletAnimationWidth' }
    <</highEnergyPenetration>>

    <<#cumulativePenetration>>
    tdiv {
      width:t='1@bulletAnimationWidth'
      flow:t='vertical'

      tdiv {
        width:t='pw'
        textareaNoTab {
          text:t='<<?bullet_properties/armorPiercing/cumulative>> (<<?bullet_properties/hitAngle>>)'
          valign:t='center'
          overlayTextColor:t='minor'
          smallFont:t='yes'
          padding:t='0, 1@bulletTooltipPadding'
        }
        img {
          size:t='1@sIco, 1@sIco'
          pos:t='1@blockInterval, 0.5ph-0.5h'
          position:t='relative'
          background-image:t='!#ui/gameuiskin#penetration_cumulative_jet_icon.svg'
          background-svg-size:t='1@sIco, 1@sIco'
        }
      }

      horizontalLine { width:t='pw' }

      tdiv {
        width:t='pw'
        padding:t='0, 1/2@bulletTooltipPadding'

        <<#props>>
        tdiv {
          width:t='1/3pw'
          flow-align:t='center'
          padding-top:t='2@sf/@pf'
          activeText {
            text:t='<<value>> - '
            smallFont:t='yes'
          }
          textareaNoTab {
            text:t='<<angle>>'
            smallFont:t='yes'
          }
          <<^isLastRow>>
          verticalLine {
            position:t='absolute'
            pos:t='pw, 0'
            height:t='ph'
          }
          <</isLastRow>>
        }
        <</props>>
      }
    }

    <<#kineticPenetration>>
    horizontalLine { width:t='1@bulletAnimationWidth' }
    <</kineticPenetration>>
    <</cumulativePenetration>>

    <<#kineticPenetration>>
    kineticPenetrationTable {
      width:t='1@bulletAnimationWidth'
      margin-bottom:t='1@bulletTooltipPadding'
      flow:t='vertical'

      tdiv {
        width:t='pw'
        textareaNoTab {
          text:t='<<?bullet_properties/armorPiercing/kinetic>> (<<?bullet_properties/hitAngle>> / <<?distance>>)'
          valign:t='center'
          overlayTextColor:t='minor'
          smallFont:t='yes'
          padding:t='0, 1@bulletTooltipPadding'
        }
        img {
          size:t='1@sIco, 1@sIco'
          pos:t='1@blockInterval, 0.5ph-0.5h'
          position:t='relative'
          background-image:t='!#ui/gameuiskin#penetration_kinetic_icon.svg'
          background-svg-size:t='1@sIco, 1@sIco'
        }
      }

      horizontalLine { width:t='pw' }

      shellTooltipPenetrationTableRows {
        flow:t='vertical'
        width:t='pw'

        <<#props>>
        tdiv {
          width:t='pw'
          textareaNoTab {
            text:t='<<text>>'
            width:t='@penetrationTableFirstColWidth'
            smallFont:t='yes'
          }
          verticalLine {
            position:t='absolute'
            pos:t='@penetrationTableFirstColWidth,0'
            height:t='1@bulletTooltipCellHeight'
          }
          <<#values>>
          textareaNoTab {
            text:t='<<value>>'
            <<^firstRow>>
            overlayTextColor:t='active'
            <</firstRow>>
            width:t='(pw-@penetrationTableFirstColWidth)/6'
            smallFont:t='yes'
          }
          <</values>>

        }
        <<#firstRow>>
        horizontalLine { width:t='pw' }
        <</firstRow>>
        <</props>>
      }
    }
    <</kineticPenetration>>
  }

}
<</bulletPenetrationData>>