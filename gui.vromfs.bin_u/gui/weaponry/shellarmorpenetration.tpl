shellTooltipPenetrationBlock {
  flow:t='vertical'
  width:t='pw'

  tooltipDesc {
    tinyFont:t='yes'
    text:t='<<title>>'
    padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
    background-color:t='@frameHeaderBackgroundColor'
  }

  tdiv {
    width:t='pw'
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

    horizontalLine { width:t='pw' }
    <</highEnergyPenetration>>

    <<#cumulativePenetration>>
    tdiv {
      width:t='1@bulletAnimationWidth'
      flow:t='vertical'

      tdiv {
        width:t='pw'
        textareaNoTab {
          text:t='<<cumulativeTitle>> (<<?bullet_properties/hitAngle>>)'
          valign:t='center'
          overlayTextColor:t='minor'
          smallFont:t='yes'
          padding:t='0, 1@bulletTooltipPadding'
        }
        img {
          size:t='1@sIco, 1@sIco'
          pos:t='1@blockInterval, 0.5ph-0.5h'
          position:t='relative'
          background-image:t='<<icon>>'
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
    horizontalLine { width:t='pw' }
    <</kineticPenetration>>
    <</cumulativePenetration>>

    <<#kineticPenetration>>
    kineticPenetrationTable {
      width:t='pw'
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
            width:t='@penetrationTableFirstColWidth'
            text-align:t='center'
            text:t='<<text>>'

            <<^narrowPenetrationTable>>
            smallFont:t='yes'
            padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
            <</narrowPenetrationTable>>

            <<#narrowPenetrationTable>>
            tinyFont:t='yes'
            padding:t='0, 1/2@bulletTooltipPadding'
            <</narrowPenetrationTable>>
          }

          verticalLine {
            position:t='absolute'
            pos:t='@penetrationTableFirstColWidth,0'
            height:t='ph'
          }

          <<#values>>
          textareaNoTab {
            width:t='(pw-@penetrationTableFirstColWidth)/6'
            text-align:t='center'
            text:t='<<value>>'

            <<^firstRow>>
            overlayTextColor:t='active'
            <</firstRow>>

            <<^narrowPenetrationTable>>
            smallFont:t='yes'
            padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
            <</narrowPenetrationTable>>

            <<#narrowPenetrationTable>>
            tinyFont:t='yes'
            padding:t='0, 1/2@bulletTooltipPadding'
            <</narrowPenetrationTable>>
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