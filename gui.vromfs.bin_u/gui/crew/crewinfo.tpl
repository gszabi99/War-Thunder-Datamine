tdiv {
  width:t='pw'
  flow:t='vertical'

  activeText {
    id:t='crew_name'
    pos:t='50%pw-50%w, 1*@scrn_tgt/100.0'
    position:t='relative'
    text:t='<<crewName>>'
  }
  tdiv {
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    tooltip:t='#crew/usedSkills/tooltip'

    text {
      text:t='#crew/usedSkills'
      crew_data:t='yes'
    }
    textareaNoTab {
      id:t='crew_cur_skills'
      margin-left:t='1@blockInterval'
      overlayTextColor:t='active'
      text:t='<<crewLevelText>>'
    }
  }
  tdiv {
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    tooltip:t='#crew/qualification/tooltip'

    text {
      text:t='<<crewSpecializationLabel>>'
      crew_data:t='yes'
    }
    img {
      size:t='1@cIco, 1@cIco'
      pos:t='-6@sf/@pf_outdated, 0'
      position:t='relative'
      margin-left:t='1@blockInterval'
      margin-right:t='2@sf/@pf_outdated'
      background-image:t='<<crewSpecializationIcon>>'
      background-svg-size:t='1@cIco, 1@cIco'
    }
    activeText {
      text:t='<<crewSpecialization>>'
    }
  }
  <<#needCurPoints>>
  tdiv {
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    tooltip:t='#crew/availablePoints/tooltip'

    text {
      text:t='#crew/availablePoints'
      crewStatus:t='<<crewStatus>>'
      crew_data:t='yes'
    }
    textareaNoTab {
      id:t='crew_cur_points'
      margin-left:t='1@blockInterval'
      overlayTextColor:t='active'
      crewStatus:t='<<crewStatus>>'
      text:t='<<crewPoints>>'
    }
  }
  <</needCurPoints>>

  table {
    padding:t='1@blockInterval'
    width:t='pw'

    <<#categoryRows>>
    tr {
      td {
        <<#categoryTooltip>>
        title:t='$tooltipObj'
        tooltipObj {
          id:t='tooltip_<<categoryTooltip>>'
          on_tooltip_open:t='onGenericTooltipOpen'
          on_tooltip_close:t='onTooltipObjClose'
          display:t='hide'
        }
        <</categoryTooltip>>
        padding-right:t='12*@sf/@pf_outdated'

        textarea {
          pos:t='0, 0.5(ph-h)'
          position:t='relative'
          text:t='<<categoryName>>'
        }
      }
      td {
        expProgress {
          pos:t='0.5(pw-w), 0.5(ph-h)'
          width:t='pw'
          position:t='relative'
          type:t='old'
          value:t='<<categoryValue>>'
          minvalue:t='0'
          maxvalue:t='<<categoryMaxValue>>'
        }
      }

      td {
        textarea {
          pos:t='pw-w, 0'
          position:t='relative'
          text:t='<<categoryValue>>/<<categoryMaxValue>>'
        }
      }
    }
    <</categoryRows>>
  }

  Button_text {
    width:t='pw'
    on_click:t='onCrewButtonClicked'
    text:t='#slotInfoPanel/crewButton'
    tooltip:t='#slotInfoPanel/crewButton/tooltip'

    showConsoleImage:t='no'
    discount_notification {
      id:t='onCrewButtonClicked_discount'
      type:t='lineText'
      text:t='<<discountText>>'
      tooltip:t='<<discountTooltip>>'
    }
  }
}
