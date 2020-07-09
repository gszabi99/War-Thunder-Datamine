<<#rewardsList>>
expandable {
  width:t='pw'

  selImg {
    width:t='pw'
    flow:t='vertical'

    tdiv {
      width:t='pw'

      tdiv {
        position:t='absolute'
        flow:t='vertical'

        activeText {
          text:t='<<title>>'
        }
      }

      <<#hasInternalRewards>>
      tdiv {
        width:t='fw'
        flow:t='vertical'

        textareaNoTab {
          left:t='0.5(pw-w)'
          position:t='relative'
          padding:t='1@blockInterval'
          smallFont:t='yes'
          text:t='#worldwar/rewards/reward_in_squadron'
        }

        tdiv {
          left:t='0.5(pw-w)'
          position:t='relative'

          <<#internalRewardsList>>
          tdiv {
            padding:t='1@blockInterval, 0'
            flow:t='vertical'

            tdiv {
              left:t='0.5(pw-w)'
              position:t='relative'
              smallItems:t='yes'
              <<@internalTrophyMarkup>>
            }

            textareaNoTab {
              left:t='0.5(pw-w)'
              position:t='relative'
              padding:t='1@blockInterval'
              smallFont:t='yes'
              text:t='<<internalCondition>>'
            }
          }
          <</internalRewardsList>>
        }
      }
      <</hasInternalRewards>>
      <<^hasInternalRewards>>
      tdiv {
        margin-left:t='0.3pw'

        <<@trophyMarkup>>

        textareaNoTab {
          top:t='0.5(ph-h)'
          position:t='relative'
          padding:t='1@blockInterval'
          smallFont:t='yes'
          text:t='<<trophyName>>'
        }
      }
      <</hasInternalRewards>>

      text {
        left:t='pw-w'
        position:t='absolute'
        padding:t='1@blockInterval'
        smallFont:t='yes'
        text:t='<<condition>>'
      }
    }
  }

  inClanRewards {
  }
}
<</rewardsList>>
