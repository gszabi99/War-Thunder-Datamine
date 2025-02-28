<<#statLines>>
  tdiv {
    position:t='relative'
    flow:t='horizontal'
    left:t='(pw-w)/2'
    <<^isFirstLine>>
    padding-top:t='<<scale>>*1@showcaseLinePadding'
    <</isFirstLine>>
    css-hier-invalidate:t='yes'

    <<#labels>>
    blankTextArea {
      text:t='<<text>>'
      font:t='@fontSmall'
      font-pixht:t='<<scale>>*1@showcaseStatNameHeight'
      color:t='@showcaseGreyText'
      showInEditMode:t='no'
    }
    <<#comboBoxData>>
    blankTextArea {
      text:t=' '
      font:t='@fontSmall'
      color:t='@showcaseGreyText'
      display:t='hide'
      showInEditMode:t='yes'
    }
    tdiv {
      position:t='absolute'
      pos:t='-w/2, 5@sf/@pf'
      width:t='1@accountHeaderWidth'
      display:t='hide'
      showInEditMode:t='yes'
      include "%gui/profile/showcase/scaledComboBox.tpl"
    }
    <</comboBoxData>>
    <</labels>>

    <<#statsBig>>
    tdiv {
        position:t='relative'
        flow:t='vertical'
        width:t='pw'

        <<#icon>>
        tdiv {
          position:t='relative'
          size:t='<<scale>>*200@sf/@pf, <<scale>>*200@sf/@pf'
          left:t='(pw-w)/2'
          background-image:t='<<icon>>'
          background-repeat:t='expand-svg'
          background-svg-size:t='<<scale>>*200@sf/@pf, <<scale>>*200@sf/@pf'
          background-color:t='#788089'
        }
        <</icon>>

        <<#statValue>>
          blankTextArea {
            padding-top:t='<<scale>>*4@sf/@pf'
            position:t='relative'
            left:t='(pw-w)/2'
            font:t='@fontBigBold'
            color:t='@showcaseBlue'
            font-pixht:t='<<scale>>*85@sf/@pf \ 1'
            text:t='<<statValue>>'
            input-transparent:t='yes'
          }
        <</statValue>>

        <<#statName>>
          blankTextArea {
            position:t='relative'
            font:t='@fontNormal'
            text-align:t='center'
            left:t='(pw-w)/2'
            color:t='@showcaseGreyText'
            text:t='<<statName>>'
            input-transparent:t='yes'
          }
        <</statName>>
        tooltip:t='<<tooltip>>'
      }
    <</statsBig>>

    <<#stats>>
      tdiv {
        position:t='relative'
        width:t='<<scale>>*1@accountHeaderWidth/3'
        min-height:t='<<scale>>*1@showcaseMinStatHeight'
        flow:t='vertical'
        padding:t='<<scale>>*20@sf/@pf, 0'

        tdiv {
          position:t='relative'
          size:t='pw, <<scale>>*20@sf/@pf'
        }
        <<#icon>>
        tdiv {
          position:t='relative'
          size:t='<<scale>>*1@showcaseStatIconSize, <<scale>>*1@showcaseStatIconSize'
          left:t='(pw-w)/2'
          background-image:t='<<icon>>'
          background-repeat:t='expand-svg'
          background-svg-size:t='<<scale>>*1@showcaseStatIconSize, <<scale>>*1@showcaseStatIconSize'
          background-color:t='#FFFFFF'
        }
        <</icon>>

        <<#statValue>>
          blankTextArea {
            <<#statValueId>>
            id:t='<<statValueId>>'
            <</statValueId>>
            padding-top:t='<<scale>>*4@sf/@pf'
            position:t='relative'
            left:t='(pw-w)/2'
            font:t='@fontBigBold'
            font-pixht:t='<<scale>>*1@showcaseStatValHeight'
            color:t='@showcaseBlue'
            text:t='<<statValue>>'
            input-transparent:t='yes'
          }
        <</statValue>>

        <<#statName>>
          blankTextArea {
            position:t='relative'
            font:t='@fontSmall'
            font-pixht:t='<<scale>>*1@showcaseStatNameHeight'
            width:t='pw'
            text-align:t='center'
            left:t='(pw-w)/2'
            color:t='@showcaseGreyText'
            text:t='<<statName>>'
            input-transparent:t='yes'
          }
        <</statName>>
        tooltip:t='<<tooltip>>'
      }
      <<^isEndInRow>>
        tdiv {
          position:t='absolute'
          size:t='<<scale>>*2@sf/@pf, ph-<<scale>>*26@sf/@pf'
          pos:t='<<scale>>*(<<idx>> + 1) * 1@accountHeaderWidth/3 - w/2, (ph-h)/2 + <<scale>>*18@sf/@pf'
          background-color:t='@showcaseBoxBorder'
        }
      <</isEndInRow>>
    <</stats>>
  }

  tdiv {
    position:t='relative'
    width:t='pw'
    flow:t='vertical'
    <<#textStats>>
      include "%gui/profile/showcase/textStat.tpl"
    <</textStats>>
  }

  <<#hasUnitImage>>
    tdiv {
      position:t='relative'
      flow:t='horizontal'
      left:t='(pw-w)/2'
      css-hier-invalidate:t='yes'
      <<#unitsImages>>
        include "%gui/profile/showcase/unitImage.tpl"
      <</unitsImages>>
    }
  <</hasUnitImage>>
<</statLines>>