root{
  type:t='big'
  blur {}
  blur_foreground {}

  frame{
    width:t='0.7@scrn_tgt'
    flow:t='vertical'
    class:t='wndNav'
    isCenteredUnderLogo:t='yes'

    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<windowHeader>> <<currentCount>>/<<maxCount>>'
      }
      Button_close { id:t='btn_back' }
    }

    tdiv{
      padding:t='1@blockInterval, 0'
      size:t='pw, fh'
      flow:t='vertical'

      activeText {
        pos:t='50%pw-50%w, 0';
        position:t='relative';
        caption:t='yes'
        text-align:t='center'
        text:t='<<unitName>>'
      }
      textAreaCentered {
        pos:t='50%pw-50%w, 0'
        position:t='relative'
        text-align:t='center'
        text:t='<<unitType>>'
      }
      tdiv {
        pos:t='50%pw-50%w, 0';
        position:t='relative';
        tdiv {
          tooltip:t='#shop/age/tooltip'
          margin-left:t='0.02@sf'
          textareaNoTab {
            text:t='<<unitAgeHeader>>'
          }
          textareaNoTab {
            overlayTextColor:t='active'
            text:t='<<unitAge>>'
          }
        }
        tdiv {
          tooltip:t='#shop/battle_rating/tooltip'
          margin-left:t='0.02@sf'
          textareaNoTab {
            text:t='<<unitRatingHeader>>'
          }
          textareaNoTab {
            overlayTextColor:t='active'
            text:t='<<unitRating>>'
          }
        }
      }

      tdiv {
        pos:t='50%pw-50%w, 0'; position:t='relative'
        height:t='40%sh'; max-height:t='294*@sf/@pf'
        width:t='540/294h'; max-width:t='540*@sf/@pf'
        img {
          position:t='absolute'
          size:t='0.4pw, 0.4ph'
          background-image:t='<<countryImage>>'
        }
        img {
          top:t='ph-h'
          position:t='absolute'
          size:t='pw, 0.5pw'
          background-image:t='<<unitImage>>'
        }
      }

      div {
        width:t='pw'
        flow:t='vertical'
        tdiv {
          activeText{
            text:t='#wishlist/comment'
          }
        }

        EditBox
        {
          id:t='comment'
          width:t='pw'
          max-len:t='<<max_comment_size>>'
          text:t=''
          on_set_focus:t='onFocus'
          on_hover:t='onHover'
          on_unhover:t='onHover'
          on_cancel_edit:t='onCancelEdit'
        }

        fieldReq{
          id:t='req_comment'
          display:t='hide'
          textareaNoTab{
            smallFont:t='yes'
            width:t='pw'
            text:t='<<max_comment_size_req>>'
          }
        }
      }
    }

    navBar {
      navRight{
        Button_text{
          id:t='btn_submit'
          hideText:t='yes'
          btnName:t='X'
          visualStyle:t='purchase'
          on_click:t='onSubmit'
          buttonWink{}
          buttonGlance{}
          ButtonImg{}
          textarea{
            id:t='btn_submit_text'
            class:t='buttonText'
            text:t='#msgbox/btn_add'
          }
        }
      }

      navLeft {
        Button_text {
          id:t='btn_cancel'
          btnName:t='B'
          text:t = '#msgbox/btn_cancel'
          tooltip:t = '#msgbox/btn_cancel'
          on_click:t = 'goBack'
          ButtonImg{}
        }
      }
    }
  }
}