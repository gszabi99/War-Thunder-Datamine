crewStatus:t='<<crewStatus>>'

<<#hasExtraInfoBlock>>
extraInfoBlock {
  id:t='extra_info_block'

  <<#hasCrewIdInfo>>
  crewInfoNumBlock {
    icon {
      margin-right:t='@sf/@pf'
    }
    crewNumText {
      text:t='<<crewNum>>'
    }
  }
  <</hasCrewIdInfo>>

  <<#hasCrewIdTextInfo>>
  crewNumText {
    text:t='<<crewNumWithTitle>>'
  }
  <</hasCrewIdTextInfo>>

  <<#hasCrewInfo>>
  crewInfoExpBlock {
    expAvailableIcon {
      margin-right:t='2@sf/@pf'
    }
    shopItemText {
      id:t='crew_level'
      text:t='<<crewLevel>>'
      _transp-timer:t='0'
    }
    icon {
      id:t='crew_spec'
      background-image:t='<<crewSpecIcon>>'
      margin-left:t='4@sf/@pf'
    }
  }
  <</hasCrewInfo>>

  <<#hasCrewHint>>
  slotCrewHintContainer {
    slotCrewHint {
      activeText {
        id:t='crew_name'
        pos:t='pw/2-w/2, 0'
        position:t='relative'
        text:t='<<crewNumWithTitle>>'
        smallFont:t='yes'
        margin-top:t='4@sf/@pf'
        margin-bottom:t='8@sf/@pf'
      }

      <<#hasUnit>>
      tdiv {
        pos:t='pw/2-w/2, 0'
        position:t='relative'
        smallFont:t='yes'
        margin-bottom:t='4@sf/@pf'

        text {
          text:t='#crew/usedSkills'
          crew_data:t='yes'
        }
        activeText {
          margin-left:t='@blockInterval'
          overlayTextColor:t='active'
          text:t='<<crewLevel>>'
        }
      }
      tdiv {
        pos:t='pw/2-w/2, 0'
        position:t='relative'
        smallFont:t='yes'
        margin-bottom:t='4@sf/@pf'

        text {
          text:t='<<crewSpecializationLabel>>'
          crew_data:t='yes'
        }
        img {
          size:t='@sIco, @sIco'
          pos:t='-6@sf/@pf, 0'
          position:t='relative'
          margin-left:t='@blockInterval'
          margin-right:t='4@sf/@pf'
          background-image:t='<<crewSpecializationIcon>>'
          background-svg-size:t='@sIco, @sIco'
        }
        activeText {
          text:t='<<crewSpecialization>>'
        }
      }
      <</hasUnit>>
      <<#needCurPoints>>
      tdiv {
        pos:t='pw/2-w/2, 0'
        position:t='relative'
        smallFont:t='yes'
        margin-bottom:t='4@sf/@pf'
        text {
          text:t='#crew/availablePoints'
          crewStatus:t='<<crewStatus>>'
          crew_data:t='yes'
        }
        textareaNoTab {
          id:t='crew_cur_points'
          margin-left:t='@blockInterval'
          overlayTextColor:t='active'
          crewStatus:t='<<crewStatus>>'
          text:t='<<crewPoints>>'
        }
      }
      <</needCurPoints>>
    }
    <<#hasActions>>
    Button_text {
      id:t='open_crew_wnd_btn'
      class:t='smallButton'
      pos:t='pw/2-w/2, 0'
      position:t='relative'
      width:t='pw-6@sf/@pf'
      text:t='#slotInfoPanel/crewButton'
      on_click:t='onOpenCrewWindow'
      margin-top:t='2@sf/@pf'
      margin-bottom:t='5@sf/@pf'
      crewId='<<crewId>>'
      <<#crewTrainInactive>>
      inactiveColor:t='yes'
      <</crewTrainInactive>>
    }
    <</hasActions>>
    tdiv {
      position:t='absolute'
      size:t="pw, @slotExtraInfoHeight"
      pos:t='pw/2-w/2, ph'
      slotHoverHighlight {}
      slotBottomGradientLine {}
    }
  }
  <</hasCrewHint>>
}
<</hasExtraInfoBlock>>
