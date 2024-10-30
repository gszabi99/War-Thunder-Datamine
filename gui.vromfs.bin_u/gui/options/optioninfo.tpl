tdiv {
  width:t='pw'
  flow:t='vertical'
  padding-left:t='10@sf/@pf'
  padding-top:t='14@sf/@pf'

  activeText {
    width:t='pw'
    mediumFont:t='yes'
    text:t='<<title>>'
  }

  <<#imageSrc>>
  img {
    id:t='option_info_image'
    width:t='pw'
    height:t='0.552pw' // 0.552 is the info-images ratio
    margin-top:t='2@blockInterval'
    margin-bottom:t='4@blockInterval'
    background-image:t='<<imageSrc>>'
    background-repeat:t='aspect-ratio'
  }
  <</imageSrc>>

  textareaNoTab {
    width:t='pw'
    margin-top:t='3@blockInterval'
    text:t='<<description>>'
  }
}