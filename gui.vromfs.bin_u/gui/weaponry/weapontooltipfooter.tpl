  <<#showFooter>>
  tdiv {
    width:t='pw'
    background-color:t='@frameHeaderBackgroundColor'
    padding:t='1@bulletTooltipPadding'

    <<#amountText>>
    tdiv {
      textareaNoTab {
        smallFont:t='yes'
        text:t='<<amountText>>'
      }
    }
    <</amountText>>

    <<#showPrice>>
    tdiv{
      id:t='discount';
      smallFont:t='yes'
      position:t='relative'
      right:t='0'
      textareaNoTab{
        text:t='<<?ugm/price>><<#noDiscountPrice>><<?ugm/withDiscount>><</noDiscountPrice>><<?ui/colon>>'
      }
      tdiv{
        textareaNoTab{
          text:t='<<noDiscountPrice>>'
          margin-right:t='3@sf/@pf'
          tdiv{
            pos:t='50%pw-50%w, 50%ph-50%h';
            position:t='absolute';
            size:t='pw, 1@dp';
            background-color:t='@oldPrice';
          }
        }
        textareaNoTab{
          text:t='<<currentPrice>>'
        }
      }
    }
    <</showPrice>>

    <<#expText>>
    tdiv {
      textareaNoTab {
        smallFont:t='yes'
        text:t='<<expText>>'
      }
    }
    <</expText>>
  }
  <</showFooter>>