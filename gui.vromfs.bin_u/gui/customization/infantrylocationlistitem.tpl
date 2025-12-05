<<#options>>
option {
  pare-text:t='yes'
  enable:t='yes'
  optName:t='<<optName>>'
  optiontext {
    id:t='option_text'
    text:t = '<<text>>'
  }

  <<#unseenValue>>
  infantryUnseenIcon {
    id:t='unseen_location'
    iconType:t='location'
    value:t='<<unseenValue>>'
  }
  <</unseenValue>>
}
<</options>>