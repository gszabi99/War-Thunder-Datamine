<<#hasExtraInfoBlock>>
extraInfoBlock {
  id:t='extra_info_block'
  interactive:t='yes'

  content {
    behavior:t='button'
    on_r_click:t='onCrewSlotClick'
    on_click:t='onCrewSlotClick'
    <<#hasActions>>
      interactive:t='yes'
      hasActions:t='yes'
      on_hover:t='onCrewBlockHover'
      on_drag_start:t='onCrewDragStart'
    <</hasActions>>

    <<^hasActions>>
      hasActions:t='no'
      on_hover:t='showCrewSlotHint'
    <</hasActions>>

    crewIdInCountry:t='<<crewIdInCountry>>'
    crewId='<<crewId>>'
    <<#forcedUnit>>forcedUnit:t='<<forcedUnit>>'<</forcedUnit>>
    isEmptySlot:t='<<@isEmptySlot>>'

    crewInfoNumBlock {
      icon {
        margin-right:t='@sf/@pf'
      }
      crewNumText {
        text:t='<<crewNum>>'
      }
    }

    <<#hasCrewIdTextInfo>>
    crewNumText {
      text:t='<<crewNumWithTitle>>'
    }
    <</hasCrewIdTextInfo>>

    <<#hasCrewInfo>>
    crewInfoExpBlock {
      expAvailableIcon {
        hasUnseenIcon:t='<<hasCrewUnseenIcon>>'
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

    slotHoverHighlight {}
    slotBottomGradientLine {}
    focus_border {}
  }
}
<</hasExtraInfoBlock>>
