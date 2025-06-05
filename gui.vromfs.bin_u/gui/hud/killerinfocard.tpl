hudFrame {
  id:t='killer_card'
  halign:t='center'
  flow:t='vertical'

  cardCaption {
    size:t='pw,21/720@shHud'
    padding:t='5/720@shHud'
    flow:t='horizontal'
    img {
      size:t='16/720@shHud,16/720@shHud'
      valign:t='center'
      background-svg-size:t='16/720@shHud,16/720@shHud'
      background-image:t='!#ui/gameuiskin#skull_round.avif'
    }

    textareaNoTab {
      valign:t='center'
      margin-left:t='5/720@shHud'
      text:t='<<cardCaption>>'
      overlayTextColor:t='active'
      font-pixht:t='11/720@shHud'
    }
  }

  killerProfileBlock {
    size:t='pw,70/720@shHud'
    border:t='yes'
    border-color:t='#666666'
    overflow:t='hidden'

    img {
      position:t='absolute'
      pos:t='pw/2-w/2,ph/2-h/2'
      size:t='ph * @profileBgImageAspectRatio * @killerCardProfileBgScale, ph * @killerCardProfileBgScale'
      background-svg-size:t='ph * @profileBgImageAspectRatio * @killerCardProfileBgScale, ph * @killerCardProfileBgScale'
      background-repeat:t='aspect-ratio'
      background-image:t='!ui/images/profile_headers/<<headerBackground>>'
    }

    avatar {
      size:t='56/720@shHud,56/720@shHud'
      valign:t='center'
      margin-left:t='7/720@shHud'

      img {
        position:t='relative'
        pos:t='pw/2-w/2,ph/2-h/2'
        size:t='pw,ph'
        background-svg-size:t='pw,ph'
        background-image:t='<<pilotIcon>>'

        <<#hasAvatarFrame>>
        avatarFrame { background-image:t='!ui/images/avatar_frames/<<frame>>.avif' }
        <</hasAvatarFrame>>
      }
    }

    killerProfile {
      margin-left:t='12/720@shHud'
      valign:t='center'
      flow:t='vertical'

      tdiv {
        textareaNoTab {
          text:t='<<clanTag>>'
          font-pixht:t='16/720@shHud'
        }
        textareaNoTab {
          margin-left:t='5/720@shHud'
          text:t='<<name>>'
          normalBoldFont:t='yes'
          overlayTextColor:t='active'
          font-pixht:t='16/720@shHud'
        }
      }

      textareaNoTab {
        text:t='<<title>>'
        overlayTextColor:t='active'
        font-pixht:t='9/720@shHud'
      }
    }
  }

  killerUnitBlock {
    height:t='87/720@shHud'
    min-width:t='320/720@shHud'

    unitImg {
      position:t='relative'
      size:t='2ph,ph'
      valign:t='center'
      padding:t='3/720@shHud'
      padding-right:t='0'

      img {
        position:t='absolute'
        pos:t='3/720@shHud,3/720@shHud'
        size:t='0.4pw,0.4ph'
        background-image:t="<<countryFlagImg>>"
        background-repeat:t='aspect-ratio'
      }

      img {
        size:t='pw,ph'
        valign:t='center'
        background-image:t="<<unitImg>>"
        background-repeat:t='aspect-ratio'
      }
    }

    unitInfo {
      id:t='unit_info'
      position:t='relative'
      valign:t='center'
      margin-left:t='15/720@shHud'
      padding-right:t='15/720@shHud'
      flow:t='vertical'

      textareaNoTab {
        text:t='<<unitName>>'
        overlayTextColor:t='active'
        font-pixht:t='12/720@shHud'
      }

      textareaNoTab {
        text:t='<<unitTypeText>>'
        font-pixht:t='12/720@shHud'
      }

      textareaNoTab {
        text:t='<<rankAndbattleRatingText>>'
        font-pixht:t='12/720@shHud'
      }

      <<#hasShellInfo>>
      separator {
        size:t='pw,1@dp'
        margin-y:t='4.5/720@shHud'
        bgcolor:t='#666666'
      }

      shellInfo {
        flow:t='horizontal'

        textareaNoTab {
          valign:t='center'
          text:t='<<?logs/ammunition>><<?ui/colon>>'
          font-pixht:t='12/720@shHud'
        }

        <<#hasShellIcon>>
        shellLayeredIcon {
          size:t='20/720@shHud,20/720@shHud'
          <<#shellIconLayers>>
          img {
            size:t='pw,ph'
            position:t='absolute'
            pos:t='0.5pw-0.5w, 0.5ph-0.5h'
            background-image:t='!<<layeredIconSrc>>'
            background-svg-size:t='pw, ph'
            background-repeat:t='aspect-ratio'
          }
          <</shellIconLayers>>
        }
        <</hasShellIcon>>

        textareaNoTab {
          valign:t='center'
          font-pixht:t='12/720@shHud'
          text:t='<<shellNameLoc>>'
          overlayTextColor:t='active'
        }
      }
      <</hasShellInfo>>
    }
  }
}