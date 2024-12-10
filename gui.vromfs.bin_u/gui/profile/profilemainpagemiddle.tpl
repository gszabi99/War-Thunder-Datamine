<<#statLines>>
  tdiv {
    position:t='relative'
    flow:t='horizontal'
    left:t='(pw-w)/2'
    padding-top:t='13@sf/@pf'

    <<#statsBig>>
    tdiv {
        position:t='relative'
        flow:t='vertical'
        width:t='pw'

        <<#icon>>
        tdiv {
          position:t='relative'
          size:t='200@sf/@pf, 200@sf/@pf'
          left:t='(pw-w)/2'
          background-image:t='<<icon>>'
          background-repeat:t='expand-svg'
          background-svg-size:t='200@sf/@pf, 200@sf/@pf'
          background-color:t='#788089'
        }
        <</icon>>

        <<#statValue>>
          blankTextArea {
            padding-top:t='4@sf/@pf'
            position:t='relative'
            left:t='(pw-w)/2'
            font:t='@fontBigBold'
            color:t='@showcaseBlue'
            font-pixht:t='85@sf/@pf'
            text:t='<<statValue>>'
          }
        <</statValue>>

        <<#statName>>
          blankTextArea {
            position:t='relative'
            font:t='fontNormal'
            text-align:t='center'
            left:t='(pw-w)/2'
            color:t='@showcaseGreyText'
            text:t='<<statName>>'
          }
        <</statName>>
      }
    <</statsBig>>

    <<#stats>>
      tdiv {
        position:t='relative'
        width:t='1@accountHeaderWidth/3'
        min-height:t='166@sf/@pf'
        flow:t='vertical'
        padding:t='20@sf/@pf, 0'

        tdiv {
          position:t='relative'
          size:t='pw, 20@sf/@pf'
        }
        <<#icon>>
        tdiv {
          position:t='relative'
          size:t='55@sf/@pf, 55@sf/@pf'
          left:t='(pw-w)/2'
          background-image:t='<<icon>>'
          background-repeat:t='expand-svg'
          background-svg-size:t='55@sf/@pf, 55@sf/@pf'
          background-color:t='#FFFFFF'
        }
        <</icon>>

        <<#statValue>>
          blankTextArea {
            padding-top:t='4@sf/@pf'
            position:t='relative'
            left:t='(pw-w)/2'
            font:t='@fontBigBold'
            color:t='@showcaseBlue'
            text:t='<<statValue>>'
          }
        <</statValue>>

        <<#statName>>
          blankTextArea {
            position:t='relative'
            font:t='tiny_text'
            width:t='pw'
            text-align:t='center'
            left:t='(pw-w)/2'
            color:t='@showcaseGreyText'
            text:t='<<statName>>'
          }
        <</statName>>
      }
      <<^isEndInRow>>
        tdiv {
          position:t='absolute'
          size:t='2@sf/@pf, ph-14@sf/@pf'
          pos:t='(<<idx>> + 1) * 1@accountHeaderWidth/3 - w/2, (ph-h)/2'
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
    tdiv {
      position:t='relative'
      background-color:t='#05111111'
      size:t='pw - 30@sf/@pf, 44@sf/@pf'
      left:t='(pw-w)/2'

      <<^isFirst>>
        margin-top:t='11@sf/@pf'
      <</isFirst>>
      <<#isFirst>>
        margin-top:t='36@sf/@pf'
      <</isFirst>>

      tdiv {
        re-type:t='textarea'
        behaviour:t='textArea'
        position:t='absolute'
        font:t="tiny_text_hud"
        text:t='<<text>>'
        color:t='#7C8389'
        left:t='20@sf/@pf'
        top:t='(ph-h)/2'
      }
      <<#value>>
      tdiv {
        position:t='absolute'
        re-type:t='textarea'
        behaviour:t='textArea'
        font:t="tiny_text_hud"
        text:t='<<value>>'
        color:t='#FFFFFF'
        left:t='pw - w - 18@sf/@pf'
        top:t='(ph-h)/2'
      }
      <</value>>
    }
    <</textStats>>
  }

<</statLines>>