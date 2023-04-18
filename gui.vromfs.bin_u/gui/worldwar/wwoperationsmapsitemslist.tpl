<<#items>>
  <<itemTag>><<^itemTag>>mission_item_unlocked<</itemTag>> {
    id:t='<<id>>'

    <<#isCollapsable>>
    collapse_header:t='yes'
    collapsed:t='no'
    collapsing:t='no'
    <</isCollapsable>>

    <<#itemClass>>
    class:t='<<itemClass>>'
    <</itemClass>>

    img {
      id:t='medal_icon'
      medalIcon:t='yes'
      background-image:t='<<itemIcon>>'
      <<#iconColor>>
        style:t='background-color:<<iconColor>>'
      <</iconColor>>
      <<#isLastPlayedIcon>>
        isLastPlayedIcon:t='yes'
      <</isLastPlayedIcon>>
    }

    <<#hasWaitAnim>>
    animated_wait_icon {
      id:t = 'wait_icon_<<id>>'
      class:t='missionBox'
      background-rotation:t = '0'
    }
    <</hasWaitAnim>>

    missionDiv {
      css-hier-invalidate:t='yes'

      <<#unseenIcon>>
      unseenIcon {
        value:t='<<unseenIcon>>'
      }
      <</unseenIcon>>

      img{
        id:t='queue_members_<<id>>'
        size:t='@cIco, @cIco'
        top:t='50%ph-50%h'
        position:t='relative'
        margin-left:t="1@blockInterval"
        display:t='hide'
        background-image:t='#ui/gameuiskin#friends.svg'
        background-svg-size:t='@cIco, @cIco'
      }

      mission_item_text {
        id:t = 'txt_<<id>>'
        top:t='50%ph-50%h'
        <<^isActive>>
        overlayTextColor:t='disabled'
        <</isActive>>
        text:t = '<<itemText>>'
      }
    }

    <<#isCollapsable>>
    fullSizeCollapseBtn {
      id:t='btn_<<id>>'
      css-hier-invalidate:t='yes'
      on_click:t='onCollapse'
      activeText{}
    }
    <</isCollapsable>>
  }
<</items>>