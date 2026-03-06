<<#rows>>
<<#needAddRow>>
row {
  id:t='<<id>>'
  width:t='pw'
  <<#even>> even:t='yes' <</even>>
  padding:t='10@sf/@pf,3@sf/@pf,10@sf/@pf,2@sf/@pf'
<</needAddRow>>

  div {
    flow:t='vertical'
    width:t='fw'

    topLine {
      width:t='fw'
      id:t='name_<<rowIdx>>'
      // all activeText blocks have enormous internal padding, so need to squeeze this block to the bottom one
      padding-bottom:t='-3@sf/@pf'

      activeText {
        text:t='<<name>>'

        title:t='$tooltipObj'
        tooltipObj {
          id:t='tooltip'
          tooltipId:t='<<skillTooltipId>>'
          on_tooltip_open:t='onGenericTooltipOpen'
          on_tooltip_close:t='onTooltipObjClose'
          display:t='hide'
          noPadding:t='yes'
        }
      }
      activeText {
        id:t='currentExpPoints'
        text:t='<<currentExpPoints>>'
      }
      activeText {
        id:t='addExpPointsValue'
        text:t='<<addExpPointsValueStr>>'
        overlayTextColor:t='good'
      }
      activeText {
        text:t='<<maxExpPointsStr>>'
      }
    }

    bottomLine {
      width:t='fw'
      id:t='<<rowIdx>>'

      div {
        id:t='crewSpecs_<<rowIdx>>'
        position:t='relative'
        pos:t='0, 50%ph-50%h'

        <<#btnSpec>>
        div {
          margin-right:t='22@sf/@pf'
          hoverBgButton {
            id:t='btn_spec<<id>>'
            size:t='38@sf/@pf, 38@sf/@pf'
            position:t='relative'
            pos:t='0, 50%ph-50%h'
            holderId:t='<<rowIdx>>'
            foreground-image:t='<<icon>>'
            foreground-position:t='3'
            noFade:t='yes'
            enable:t='<<enable>>'
            display:t='<<display>>'
            on_click:t='onSpecIncrease<<id>>'
            title:t='$tooltipObj'

            tooltipObj {
              <<#isExpertSpecType>>tooltipId:t='<<buySpecTooltipId1>>'<</isExpertSpecType>>
              <<^isExpertSpecType>>tooltipId:t='<<buySpecTooltipId2>>'<</isExpertSpecType>>
              on_tooltip_open:t='onGenericTooltipOpen'
              on_tooltip_close:t='onTooltipObjClose'
              display:t='hide'
            }
          }
          tdiv {
            position:t='relative'
            pos:t='0, 50%ph-50%h'
            size:t='<<barsCount>> * 1@crewSkillBockWidth, 1@crewSkillBlockHeight'
            <<#barsType>>
            skillProgressBg {
              width:t='pw + 2@sf/@pf'
              height:t='ph + 2@sf/@pf'
            }
            img {
              size:t='pw, ph'
              background-image:t='<<barsType>>'
              background-svg-size:t='1@crewSkillBockWidth, 1@crewSkillBlockHeight'
              background-repeat:t='repeat-x'
              background-position:t='0'
            }
            <</barsType>>
          }
        }
        <</btnSpec>>
      }

      tdiv{
        id:t='btnDec_place'
        width:t='1@sliderButtonSquareHeightSm'
        height:t='1@sliderButtonSquareHeightSm'
        position:t='relative'
        pos:t='0, 50%ph-50%h'

        Button_text {
          id:t='buttonDec_<<rowIdx>>'
          square:t='yes'
          holderId:t='<<rowIdx>>'
          useParentSize:t='yes'
          reduceMinimalWidth:t='yes'
          enable:t='<<activeButtonDec>>'
          text:t='-'
          tooltip:t='#crew/skillDecrease'
          on_click:t='onButtonDec'
          on_click_repeat:t = 'onButtonDecRepeat'
        }
      }

      invisSlider {
        id:t='skillSlider_<<rowIdx>>'
        size:t='<<maxSkillCrewLevel>> * 1@crewSkillBockWidth, 1@crewSkillBlockHeight'
        position:t='relative'
        pos:t='0, 50%ph-50%h'
        min:t='0'
        max:t='<<progressMax>>'
        value:t='<<skillSliderValue>>'
        <<#progressEnable>>enable:t='<<progressEnable>>'<</progressEnable>>
        snap-to-values:t='yes'
        clicks-by-points:t='yes'
        on_change_value:t='onSkillChanged'
        margin:t='4@sf/@pf, 0'

        skillProgressBg {
          class:t='modernWnd'
          width:t='pw + 2@sf/@pf'
          height:t='ph + 2@sf/@pf'
        }

        skillProgress {
          class:t='modernWnd'
          id:t='availableSkillProgress'
          height:t='1@crewSkillBlockHeight'
          width:t='pw'
          pos:t='50%pw-50%w, 50%ph-50%h'
          position:t='absolute'
          type:t='available' //available now to increase
          max:t='<<progressMax>>'
        }

        skillProgress {
          class:t='modernWnd'
          id:t='glowSkillProgress'
          height:t='1@crewSkillGlowBlockHeight'
          width:t='pw'
          pos:t='50%pw-50%w, 50%ph-50%h'
          position:t='absolute'
          type:t='glow' //light above and bottom the cell
          max:t='<<progressMax>>'
          value:t='<<glowSkillProgressValue>>'
        }

        skillProgress {
          class:t='modernWnd'
          id:t='newSkillProgress'
          height:t='1@crewSkillBlockHeight'
          width:t='pw'
          pos:t='50%pw-50%w, 50%ph-50%h'
          position:t='absolute'
          type:t='new' //just added right now, can be reset
          max:t='<<progressMax>>'
          value:t='<<newSkillProgressValue>>'
        }

        skillProgress {
          class:t='modernWnd'
          id:t='shadeSkillProgress'
          height:t='1@crewSkillGlowBlockHeight'
          width:t='pw'
          pos:t='50%pw-50%w, 50%ph-50%h'
          position:t='absolute'
          type:t='shade' //to hide light above and bottom the cell for old ones
          max:t='<<maxValue>>'
          value:t='<<shadeSkillProgressValue>>'
        }

        skillProgress {
          class:t='modernWnd'
          id:t='skillProgress'
          height:t='1@crewSkillBlockHeight'
          width:t='pw'
          pos:t='50%pw-50%w, 50%ph-50%h'
          position:t='absolute'
          type:t='old'//already got and bought
          max:t='<<maxValue>>'
          value:t='<<skillProgressValue>>'
        }

        focus_border{}
        sliderButton {
          increasedHeight:t='yes'
        }
      }

      tdiv {
        width:t='1@sliderButtonSquareHeightSm'
        height:t='1@sliderButtonSquareHeightSm'
        position:t='relative'
        pos:t='0, 50%ph-50%h'
        Button_text {
          id:t='buttonInc_<<rowIdx>>'
          text:t='+'
          square:t='yes'
          enable:t='<<activeButtonInc>>'
          useParentSize:t='yes'
          reduceMinimalWidth:t='yes'
          on_click:t='onButtonInc'
          on_click_repeat:t = 'onButtonIncRepeat'
          tooltip:t='#crew/skillIncrease'
          holderId:t='<<rowIdx>>'
        }
      }

      textareaNoTab {
        id:t='incCost'
        width:t='68@sf/@pf'
        position:t='relative'
        top:t='50%ph-50%h'
        text:t='<<incCost>>'
        text-align:t='right'
        tooltip:t='#crew/incCost/tooltip'
      }
    }
  }
<<#needAddRow>>
}
<</needAddRow>>
<</rows>>
