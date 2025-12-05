<<#tabs>>
crewTab {
  <<#id>>id:t='<<id>>'<</id>>
  tooltip:t='<<tooltip>>'
  width:t='pw'
  height:t='58@sf/@pf'
  css-hier-invalidate:t='yes'

  crewTabImage {
    size:t='58@sf/@pf, 58@sf/@pf'
    margin-left:t='13@sf/@pf'
    margin-right:t='3@sf/@pf'
    img {
      background-image:t='<<tabImage>>'
      <<@tabImageParam>>
    }
  }

  textareaNoTab {
    <<#id>>id:t='<<id>>_text'<</id>>
    text:t='<<tabName>>'
    position:t='relative'
    smallFont:t='yes'
    top:t='ph/2-h/2'
  }

  <<#cornerImg>>
  cornerImg {
    id:t='<<cornerImgId>>'
    background-image:t='<<cornerImg>>'
  }
  <</cornerImg>>
}
<</tabs>>
