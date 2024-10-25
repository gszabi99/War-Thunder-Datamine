activeText {
  width:t='pw'
  text:t='<<title>>'
}

<<#imageSrc>>
  img {
    id:t='option_info_image'
    width:t='1000@sf/@pf'
    height:t='750@sf/@pf'
    background-image:t='<<imageSrc>>'
    background-repeat:t='aspect-ratio'
  }
<</imageSrc>>

textareaNoTab {
  width:t='pw'
  margin-top:t='3@blockInterval'
  text:t='<<description>>'
}
