// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.GameCommon as Game

import LunarLtk

pragma ComponentBehavior: Bound

/* Layout of card:
 *      +--------+
 * num -|5       |
 * suit-|s       |
 *      |  img   |
 *      |        |
 *      |footnote|
 *      +--------+
 */

Game.PokerCard {
  id: root
  width: 93 * cardScale
  height: 130 * cardScale

  required property CardModel dataModel
  onDataModelChanged: dataModel.cardItem = root;

  suit: dataModel.suit
  number: dataModel.number
  color: dataModel.color
  footnote: dataModel.footnote
  footnoteVisible: dataModel.footnoteVisible
  known: dataModel.known

  selectable: dataModel.selectable
  onSelectedChanged: dataModel.selected = selected;

  Connections {
    target: root.dataModel
    function onSelectedChanged() {
      if (root.selected !== root.dataModel.selected) {
        root.selected = root.dataModel.selected;
      }
    }
  }

  property bool markVisible: false

  hoverHandler.cursorShape: selectable ? Qt.PointingHandCursor : Qt.ArrowCursor

  property bool showDetail: true
  onRightClicked: {
    if (!showDetail || !known) return;
    roomScene.startCheat("CardDetail", { card: this });
  }

  cardFrontSource: SkinBank.getCardPicture(dataModel.cardId || dataModel.name)
  cardBackSource: SkinBank.searchBuiltinPic("/image/card/", "card-back")

  Rectangle {
    id: virt_rect
    visible: root.known && root.dataModel.virtName && root.dataModel.virtName !== root.dataModel.name
    width: parent.width
    height: 20 * root.cardScale
    y: 40 * root.cardScale
    color: "snow"
    opacity: 0.8
    radius: 4 * root.cardScale
    border.color: "black"
    border.width: 1

    Text {
      anchors.centerIn: parent
      font.pixelSize: Math.floor(16 * root.cardScale)
      font.family: Config.libianName
      font.letterSpacing: -0.6
      text: Lua.tr(root.dataModel.virtName)
    }
  }

  Component {
    id: cardMarkDelegate
    Item {
      required property var modelData
      visible: root.known || modelData.origName.includes("-public")
      width: root.width / 2 * root.cardScale
      height: 16 * root.cardScale
      Rectangle {
        width: markText.width + 12
        height: 16 * root.cardScale
        // color: "#A50330"
        radius: 4 * root.cardScale
        // border.color: "snow"
        // border.width: 1
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.7; color: "#A50330" }
          GradientStop { position: 1.0; color: "transparent" }
        }
      }
      Text {
        id: markText
        x: 2
        font.pixelSize: Math.floor(16 * root.cardScale)
        font.family: Config.libianName
        font.letterSpacing: -0.6
        text: parent.modelData.value
        color: "white"
        style: Text.Outline
        styleColor: "purple"
      }
    }
  }

  GridLayout {
    width: root.width
    y: 60 * root.cardScale
    columns: 2
    rowSpacing: root.cardScale
    columnSpacing: 0
    visible: root.known && root.markVisible
    Repeater {
      model: root.dataModel.marks
      delegate: cardMarkDelegate
    }
  }

  Text {
    id: prohibitText
    visible: !root.selectable && root.known
    anchors.centerIn: parent
    font.family: Config.libianName
    font.pixelSize: Math.floor(18 * root.cardScale)
    opacity: 0.9
    horizontalAlignment: Text.AlignHCenter
    lineHeight: 18 * root.cardScale
    lineHeightMode: Text.FixedHeight
    color: "snow"
    width: 20 * root.cardScale
    wrapMode: Text.WrapAnywhere
    style: Text.Outline
    styleColor: "red"
    text: root.dataModel.prohibitReason
  }
}
