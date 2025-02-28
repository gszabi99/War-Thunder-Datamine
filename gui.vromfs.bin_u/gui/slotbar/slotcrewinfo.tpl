tdiv {
  position:t='relative'
  flow:t='vertical'
  width:t='pw'
  left:t='(pw-w)/2'
  min-width:t='1@slot_width - 2@slot_interval + 12@sf/@pf'
  padding:t='3@sf/@pf'

  activeText {
    id:t='crew_name'
    pos:t='pw/2-w/2, 0'
    position:t='relative'
    text:t='<<crewNumWithTitle>>'
    smallFont:t='yes'
    margin-top:t='2@sf/@pf'
    margin-bottom:t='3@sf/@pf'
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

<<#hasSeparator>>
tdiv {
  size:t='p.p.w, 1'
  pos:t='(pw-w)/2, ph-h'
  position:t='absolute'
  background-color:t='#4B4F53'
}
<</hasSeparator>>