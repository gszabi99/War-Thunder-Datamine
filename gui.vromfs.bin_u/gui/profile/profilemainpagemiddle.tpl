<<#statLines>>
  tdiv {
    position:t='relative'
    flow:t='horizontal'
    left:t='(pw-w)/2'
    padding-top:t='13@sf/@pf'
    <<#stats>>
      tdiv {
        position:t='relative'
        width:t='200@sf/@pf'
        height:t='166@sf/@pf'
        flow:t='vertical'
        <<#isLeftCell>>
        padding-right:t='57@sf/@pf'
        <</isLeftCell>>
        <<#isRightCell>>
        padding-left:t='57@sf/@pf'
        <</isRightCell>>

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

        <<^isEndInRow>>
          tdiv {
            size:t='2@sf/@pf, ph-14@sf/@pf'
            position:t='absolute'
            pos:t='pw-w, (ph-h)/2'
            background-color:t='@showcaseBoxBorder'
          }
        <</isEndInRow>>
      }
    <</stats>>
  }
<</statLines>>