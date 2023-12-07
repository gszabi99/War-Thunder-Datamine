<<#qrCodes>>
  tdiv {
    flow:t='vertical'
    padding:t='2@blockInterval'
    position:t='relative'

    <<#qrText>>
    textarea {
      id:t='qrHeader'
      position:t='relative'
      min-width:t='pw'
      left:t='(pw-w)/2'
      text-align:t='center'
      text:t='<<qrText>>'
      margin-bottom:t='1@blockInterval'
    }
    <</qrText>>

    include "%gui/commonParts/qrCode.tpl"

    <<#needShowUrlLink>>
      tdiv {
        left:t='0.5pw-0.5w'
        position:t='relative'
        margin-top:t='1@blockInterval'

        <<#isAllowExternalLink>>
        Button_text {
          <<#btnId>>
          id:t='<<btnId>>'
          <</btnId>>
          <<^btnId>>
          id:t='btnLink'
          <</btnId>>
          <<#buttonKey>>
          btnName:t='<<buttonKey>>'
          <</buttonKey>>
          text:t='#open_url_in_browser'
          hideText:t='yes'
          link:t='<<baseUrl>>'
          externalLink:t='yes'
          margin-top:t='1@blockInterval'
          on_click:t='onMsgLink'
          ButtonImg{}
          btnText {
            id:t='btn_link_text'
            text:t='#open_url_in_browser'
            underline {}
          }
        }
        <</isAllowExternalLink>>
        <<^isAllowExternalLink>>
        textareaNoTab {
          text:t='<<urlWithoutTags>>'
        }
        <</isAllowExternalLink>>
      }
    <</needShowUrlLink>>
  }
<</qrCodes>>
