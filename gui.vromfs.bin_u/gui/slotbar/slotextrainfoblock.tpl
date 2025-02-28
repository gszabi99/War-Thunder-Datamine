<<#hasExtraInfoBlock>>
extraInfoBlock {
  id:t='extra_info_block'
  isEmptySlot:t='<<@isEmptySlot>>'
  hasActions:t='<<#hasActions>>yes<</hasActions>><<^hasActions>>no<</hasActions>>'
  <<#hasActions>>
  interactive:t='yes'
  <</hasActions>>
  on_r_click:t='onCrewSlotClick'
  on_click:t='onCrewSlotClick'
  crewIdInCountry:t='<<crewIdInCountry>>'
  crewId='<<crewId>>'
  <<#forcedUnit>>forcedUnit:t='<<forcedUnit>>'<</forcedUnit>>

  content {
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

    on_hover:t='onCrewBlockHover'
    focus_border {}
  }
  <<#hasActions>>
  on_drag_start:t='onCrewDragStart'
  <</hasActions>>
}
<</hasExtraInfoBlock>>
