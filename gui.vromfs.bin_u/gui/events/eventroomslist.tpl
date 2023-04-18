<<#items>>
<<#isLocked>>mission_item_locked<</isLocked>><<^isLocked>>mission_item_unlocked<</isLocked>> {
  id:t='<<id>>'
  <<#isSelected>>
  selected:t='yes'
  <</isSelected>>

  <<#isCollapsable>>
  collapse_header:t='yes'
  collapsed:t='no'
  collapsing:t='no'
  <</isCollapsable>>

  on_hover:t='onItemHover'
  on_unhover:t='onItemHover'

  <<#isBattle>>
  img {
    id:t='battle_icon'
    pos:t='ph/2-h/2, ph/2-h/2'; position:t='relative'
    size:t='@cIco, @cIco'
    background-image:t='#ui/gameuiskin#lb_each_player_session.svg'
    background-svg-size:t='@cIco, @cIco'
  }
  <</isBattle>>

  missionDiv {
    css-hier-invalidate:t='yes'

    <<#itemText>>
    mission_item_text {
      id:t = 'txt_<<id>>'
      text:t = '<<itemText>>'
    }
    <</itemText>>

    <<#teamACountries>>
      <<#country>>
        cardImg {
          background-image:t='<<image>>'
          pos:t='2, 50%ph-50%h'
          position:t='relative'
        }
      <</country>>
    <</teamACountries>>

    <<#teamBCountries>>
      <<#teamACountries>>
        mission_item_text {
          text:t = '#country/VS'
        }
      <</teamACountries>>

      <<#country>>
        cardImg {
          background-image:t='<<image>>'
          pos:t='2, 50%ph-50%h'
          position:t='relative'
        }
      <</country>>
    <</teamBCountries>>
  }

  <<#isCollapsable>>
  fullSizeCollapseBtn {
    id:t='btn_<<id>>'
    css-hier-invalidate:t='yes'
    square:t='yes'
    on_click:t='onCollapse'
    activeText{}
  }
  <</isCollapsable>>

  ButtonImg { btnName:t='A' }
}
<</items>>
