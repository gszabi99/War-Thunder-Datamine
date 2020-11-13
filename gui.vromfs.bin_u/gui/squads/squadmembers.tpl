<<#members>>
  Button_text {
    id:t='member_<<blockID>>'
    width:t='pw'
    btnName:t='A'
    visualStyle:t='noFrame'

    on_click:t = 'onMemberClick'
    on_r_click:t = 'onMemberClick'
    title:t='$tooltipObj'

    ButtonImg {
      showOnSelect:t='focus'
    }

    img {
      id:t='pilotIconImg'
      position:t='relative'
      pos:t='0, ph/2 - h/2'
      size:t='@cIco, @cIco'
      behavior:t='bhvAvatar'

      animated_wait_icon {
        id:t='not_member_data'
        class:t='missionBox'
        background-rotation:t='0'
      }
    }

    btnText {
      id:t='clanTag'
      margin:t='1@blockInterval, 0'
      text:t='<<clanTag>>'
    }
    btnText {
      id:t='contactName'
      margin:t='1@blockInterval, 0'
      text:t='<<name>>'
    }
    contactStatusImg {
      id:t='statusImg';
      pos:t='pw - w -1@blockInterval, ph/2 - h/2'
      position:t='absolute'
      tooltip:t='<<presenceTooltip>>'
      background-image:t='<<presenceIcon>>'
      background-color:t='<<presenceIconColor>>'
    }

    tooltipObj {
      id:t='tooltip';
      uid:t='<<memberUid>>'
      on_tooltip_open:t='onContactTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
  }
<</members>>
