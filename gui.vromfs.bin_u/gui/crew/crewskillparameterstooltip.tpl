skillParametersTooltip {
  id:t='skill_params_tooltip'
  bgcolor:t='@weaponCardBackgroundColor'
  flow:t='vertical'
  padding:t='@frameMediumPadding'

  <<#skillName>>
  textareaNoTab {
    text:t='<<skillName>>'
    overlayTextColor:t='active'
  }
  <</skillName>>

  <<#skillDescription>>
  textarea {
    width:t='pw'
    padding-bottom:t='24@sf/@pf'
    text:t='<<skillDescription>>'
    overlayTextColor:t='disabled'
  }
  <</skillDescription>>

  <<#hasSkillRows>>
  table {
    <<#skillRows>>
    tr {
      height:t='41@sf/@pf'

      td {
        textarea {
          pos:t='0, 0.5(ph-h)'
          position:t='relative'
          text:t='<<skillName>>'
        }
      }
      td {
        tdiv {
          size:t='<<maxSkillCrewLevel>> * (0.185@scrn_tgt \ (<<maxSkillCrewLevel>> * @skillProgressWidthMul)) * @skillProgressWidthMul, 2*@scrn_tgt/100.0'
          pos:t='0, 50%ph - 50%h - 0.002@scrn_tgt'; position:t='relative'

          skillProgressBg {
            height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul + 1@skillProgressBgIncSize'
            width:t='pw + 1@skillProgressBgIncSize + 1'
          }

          skillProgress {
            id:t='availableSkillProgress'
            height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul'
            width:t='pw'
            pos:t='50%pw-50%w, 50%ph-50%h';
            position:t="absolute"
            type:t='available'
            max:t='<<totalSteps>>'
            value:t='<<availableStep>>'
          }

          skillProgress {
            id:t='skillProgress'
            height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul'
            width:t='pw'
            pos:t='50%pw-50%w, 50%ph-50%h';
            position:t="absolute"
            type:t='old'
            max:t='<<skillMaxValue>>'
            value:t='<<skillValue>>'
          }
        }
      }
      td {
        textarea {
          pos:t='0, 0.5(ph-h)'
          position:t='relative'
          text:t='<<skillLevel>>'
        }
      }
    }
    <</skillRows>>
  }
  <</hasSkillRows>>

  table {
    id:t='skill_params_tbl'

    <<#parameterRows>>
    tr {
      <<^isHeader>>
      height:t='46@sf/@pf'
      <</isHeader>>
      <<#isHeader>>
      height:t='34@sf/@pf'
      <</isHeader>>
      <<#isEven>>
      bgcolor:t='#330c0e10'
      <</isEven>>
      // Parameter description
      td {
        width:t='270@sf/@pf'
        padding-right:t='20@sf/@pf'
        textarea {
          position:t='relative'
          pos:t='0, 0.5(ph-h)'
          max-width:t='pw'
          text:t='<<descriptionLabel>>'
        }
      }

      <<#valueItems>>
      td {
        flow:t='horizontal'
        padding-x:t='22@sf/@pf'

        <<#hasSeparatorBefore>>
        verticalLine  { height:t='ph'; position:t='absolute'; }
        <</hasSeparatorBefore>>

        <<#itemImage>>
        img {
          pos:t='0.5(pw-w), 0.5(ph-h)'
          position:t='relative'
          background-image:t='<<itemImage>>'
          size:t='<<imageSize>>*@sf/@pf, <<imageSize>>*@sf/@pf'
          background-svg-size:t='<<imageSize>>*@sf/@pf, <<imageSize>>*@sf/@pf'
          background-repeat:t='aspect-ratio'
          bgcolor:t='#FFFFFF'
          <<#imageLegendText>>
          tooltip:t='<<imageLegendText>>'
          <</imageLegendText>>
        }
        <</itemImage>>

        <<#itemText>>
        textarea {
          position:t='relative'
          pos:t='0.5(pw-w), 0.5(ph-h)'
          text:t='<<itemText>>'
          overlayTextColor:t='<<overlayTextColor>>'
        }
        <</itemText>>

        <<#hasSeparatorAfter>>
        verticalLine  { height:t='ph'; position:t='absolute'; right:t='0' }
        <</hasSeparatorAfter>>
      }
      <</valueItems>>
    }
    <</parameterRows>>
  }

  horizontalLine { width:t='pw' }

  <<#descriptionNotes>>
  textareaNoTab {
    width:t='pw'
    padding-top:t='@frameMediumPadding'
    overlayTextColor:t='faded'
    smallFont:t='yes'
    text:t='<<descriptionNotes>>'
  }
  <</descriptionNotes>>

  <<#footnoteText>>
  textareaNoTab {
    padding-top:t='@frameMediumPadding'
    halign:t='center'
    overlayTextColor:t='faded'
    smallFont:t='yes'
    text:t='<<footnoteText>>'
  }
  <</footnoteText>>
}
