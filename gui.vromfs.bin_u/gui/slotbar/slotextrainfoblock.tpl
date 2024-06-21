<<#hasExtraInfoBlock>>
extraInfoBlock {
  id:t='extra_info_block'
  isEmptySlot:t='<<@isEmptySlot>>'
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
      crewStatus:t='<<crewStatus>>'
      margin-right:t='2@sf/@pf'
    }
    shopItemText {
      id:t='crew_level'
      text:t='<<crewLevel>>'
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
    id:t='extra_info_block_crew_hint'
    slotCrewHint {
      <<#showCrewHintUnderSlot>>
      placement:t='under_slot'
      <</showCrewHintUnderSlot>>

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
          text:t='#crew/usedSkills/short'
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
          position:t='relative'
          margin-right:t='4@sf/@pf'
          background-image:t='<<crewSpecializationIcon>>'
          background-svg-size:t='@sIco, @sIco'
        }
        activeText {
          text:t='<<crewSpecialization>>'
        }
      }
      <</hasUnit>>

      <<^showAdditionExtraInfo>>
      <<#needCurPoints>>
      tdiv {
        pos:t='pw/2-w/2, 0'
        position:t='relative'
        smallFont:t='yes'
        margin-bottom:t='4@sf/@pf'
        text {
          text:t='#crew/availablePoints/short'
          crew_data:t='yes'
        }
        textareaNoTab {
          id:t='crew_cur_points'
          margin-left:t='@blockInterval'
          overlayTextColor:t='active'
          text:t='<<crewPoints>>'
        }
      }
      <</needCurPoints>>
      <</showAdditionExtraInfo>>

    }
    <<#hasActions>>
    Button_text {
      id:t='open_crew_wnd_btn'
      class:t='smallButton'
      pos:t='pw/2-w/2, 0'
      position:t='relative'
      width:t='pw-6@sf/@pf'
      on_click:t='onOpenCrewWindow'
      margin-top:t='2@sf/@pf'
      margin-bottom:t='5@sf/@pf'
      crewId='<<crewId>>'
      inactiveColor:t='yes'
      tdiv {
        position:t='absolute'
        pos:t='pw/2-w/2, ph/2-h/2'
        expAvailableIcon {
          crewStatus:t='<<crewStatus>>'
          margin-right:t='2@sf/@pf'
        }
        text {
          pos:t='0, ph/2-h/2+@sf/@pf'
          position:t='relative'
          text:t='#slotInfoPanel/crewButton'
          smallFont:t='yes'
        }
      }
    }
    <</hasActions>>

    tdiv {
      position:t='absolute'
      size:t="pw, @slotExtraInfoHeight"
      pos:t='pw/2-w/2, ph'
      background-color:t="@extraInfoBlockBgColor"
      css-hier-invalidate:t="yes"
      border:t="yes"
      border-color:t="@extraInfoBlockBorderColor"
      border-offset:t="@sf/@pf"

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
        shopItemText {
          id:t='crew_level_hint_block'
          text:t='<<crewLevel>>'
        }
        icon {
          id:t='crew_spec_hint_block'
          background-image:t='<<crewSpecIcon>>'
          margin-left:t='4@sf/@pf'
        }
      }
      <</hasCrewInfo>>

      slotHoverHighlight {}
      slotBottomGradientLine {}
    }
  }
  <</hasCrewHint>>
  <<#hasActions>>
  Button_text {
    visualStyle:t='common'
    class:t='swapCrew'
    display:t='hide'
    on_click:t='onSwapCrews'
    crewIdInCountry:t='<<crewIdInCountry>>'
    img {}
  }
  <</hasActions>>
}
<</hasExtraInfoBlock>>
