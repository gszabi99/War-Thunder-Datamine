<<#rows>>
<<#needAddRow>>
tr {
  id:t='<<id>>'
  <<#even>> even:t='yes' <</even>>
  title:t='$tooltipObj'
<</needAddRow>>

  tooltipObj {
    id:t='tooltip'
    on_tooltip_open:t='onSkillRowTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
    skillName:t='<<skillName>>'
    memberName:t='<<memberName>>'
  }

  td {
    id:t='name_<<rowIdx>>'
    cellType:t='left';
    padding-left:t='5*@scrn_tgt/100.0'
    optiontext { text:t='<<name>>' }
  }
  td {
    id:t='<<rowIdx>>'
    cellType:t='right';
    padding-right:t='3.5*@scrn_tgt/100.0'

    <<#btnSpec>>
    hoverBgButton {
      id:t='btn_spec<<id>>'
      size:t='ph, ph'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
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
      tdiv {
        flow:t='horizontal'
        position:t='relative'
        pos:t='pw/2 - w/2, ph - h'
        size:t='<<barsCount>>*pw/4, 6@sf/@pf'
        <<#bars>>
        img {
          size:t='pw/<<barsCount>>, ph'
          background-image:t='<<barsType>>'
          background-svg-size:t='pw/<<barsCount>>, ph'
        }
        <</bars>>
      }
    }
    text {
      valign:t='center'
      text:t='+'
      display:t='<<display>>'
    }
    <</btnSpec>>

    tdiv{
      id:t='btnDec_place'
      size:t='1@sliderButtonSquareHeight+@buttonMargin, ph'
      pos:t='0.01@scrn_tgt, 0'; position:t='relative';

      Button_text {
        id:t='buttonDec_<<rowIdx>>'
        square:t='yes'
        holderId:t='<<rowIdx>>'
        display:t='<<visibleButtonDec>>'
        text:t='-'
        tooltip:t='#crew/skillDecrease'
        on_click:t='onButtonDec'
        on_click_repeat:t = 'onButtonDecRepeat'
      }
    }

    invisSlider {
      id:t='skillSlider_<<rowIdx>>'
      size:t='<<maxSkillCrewLevel>> * (0.185@scrn_tgt \ (<<maxSkillCrewLevel>> * @skillProgressWidthMul)) * @skillProgressWidthMul, 2*@scrn_tgt/100.0'
      pos:t='0, 50%ph-50%h'; position:t='relative'
      min:t='0'
      max:t='<<progressMax>>'
      value:t='<<skillSliderValue>>'
      <<#progressEnable>>enable:t='<<progressEnable>>'<</progressEnable>>
      snap-to-values:t='yes'
      clicks-by-points:t='yes'
      on_change_value:t='onSkillChanged'

      skillProgressBg {
        height:t='(pw / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul + 1@skillProgressBgIncSize'
        width:t='pw + 1@skillProgressBgIncSize + 1'
      }

      skillProgress {
        id:t='availableSkillProgress'
        height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul'
        width:t='pw'
        pos:t='50%pw-50%w, 50%ph-50%h';
        position:t="absolute"
        type:t='available'
        max:t='<<progressMax>>'
      }

      skillProgress {
        id:t='glowSkillProgress'
        height:t='w / <<maxSkillCrewLevel>>'
        width:t='pw'
        pos:t='50%pw-50%w, 50%ph-50%h';
        position:t="absolute"
        type:t='glow'
        max:t='<<progressMax>>'
        value:t='<<glowSkillProgressValue>>'
      }

      skillProgress {
        id:t='newSkillProgress'
        height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul'
        width:t='pw'
        pos:t='50%pw-50%w, 50%ph-50%h';
        position:t="absolute"
        type:t='new'
        max:t='<<progressMax>>'
        value:t='<<newSkillProgressValue>>'
      }

      skillProgress {
        id:t='shadeSkillProgress'
        height:t='w / <<maxSkillCrewLevel>>'
        width:t='pw'
        pos:t='50%pw-50%w, 50%ph-50%h';
        position:t="absolute"
        type:t='shade'
        max:t='<<maxValue>>'
        value:t='<<shadeSkillProgressValue>>'
      }

      skillProgress {
        id:t='skillProgress'
        height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul'
        width:t='pw'
        pos:t='50%pw-50%w, 50%ph-50%h';
        position:t="absolute"
        type:t='old'
        max:t='<<maxValue>>'
        value:t='<<skillProgressValue>>'
      }

      focus_border{}
      sliderButton{}
    }
    activeText {
      valign:t='center'
      text:t='='
      margin-left:t='0.01@scrn_tgt'
    }
    activeText {
      id:t='curValue';
      min-width:t='5*@scrn_tgt/100.0';
      padding-left:t='1*@scrn_tgt/100.0'
      valign:t='center'
      text:t='<<curValue>>'
      tooltip:t='<<bonusTooltip>>'
    }
    tdiv {
      width:t="1@sliderButtonSquareHeight"
      height:t="1@sliderButtonSquareHeight"
      position:t='relative'
      pos:t="0, 50%ph-50%h"
      Button_text {
        id:t='buttonInc_<<rowIdx>>';
        text:t='+';
        square:t='yes';
        display:t='<<visibleButtonInc>>'
        on_click:t='onButtonInc';
        on_click_repeat:t = 'onButtonIncRepeat'
        tooltip:t='#crew/skillIncrease'
        holderId:t='<<rowIdx>>'
      }
    }
  }
  td {
    padding-right:t='5*@scrn_tgt/100.0'
    min-width:t='15*@scrn_tgt/100.0';
    textareaNoTab {
      id:t='incCost';
      commonTextColor:t='yes';
      valign:t='center';
      text:t='<<incCost>>'
      tooltip:t='#crew/incCost/tooltip'
    }
  }
<<#needAddRow>>
}
<</needAddRow>>
<</rows>>
