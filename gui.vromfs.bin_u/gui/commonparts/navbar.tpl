
hintDiv { modalPos:t='left'; hintText {}}

navLeft {
  <<#left>>
  <<#button>>
  include "gui/commonParts/button"
  <</button>>
  <<#textField>>
  activeText {
    id:t='<<id>>'
    text:t='<<text>>'
    position:t='relative'
    pos:t='0, 50%ph-50%h'
  }
  <</textField>>
  <</left>>
}

navMiddle {
  <<#middle>>
  <<#button>>
  include "gui/commonParts/button"
  <</button>>
  <<#textField>>
  activeText {
    id:t='<<id>>'
    text:t='<<text>>'
    position:t='relative'
    pos:t='0, 50%ph-50%h'
  }
  <</textField>>
  <</middle>>
}

navRight {
  <<#right>>
  <<#button>>
  include "gui/commonParts/button"
  <</button>>
  <<#textField>>
  activeText {
    id:t='<<id>>'
    text:t='<<text>>'
    position:t='relative'
    pos:t='0, 50%ph-50%h'
    padding-right:t='5*@sf/@pf_outdated'
  }
  <</textField>>
  <</right>>
}
