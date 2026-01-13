// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import LunarLtk
import LunarLtk.Components

Item {
  id: root
  required property PhotoModel dataModel
  property bool sealed: dataModel.sealedSlots.includes("JudgeSlot")

  Image {
    visible: root.sealed
    x: -6; y: 8; z: 9
    source: SkinBank.delayedTrickDir + "sealed"
    height: 21
    fillMode: Image.PreserveAspectFit
  }

  InvisibleCardArea {
    id: area
  }

  Row {
    id: grid
    anchors.fill: parent
    spacing: -4

    Repeater {
      model: root.dataModel.delayedTricks

      Item {
        required property CardModel modelData
        height: 55 * 0.6
        width: 47 * 0.6
        Image {
          anchors.fill: parent
          source: SkinBank.getDelayedTrickPicture(parent.modelData.name)
          fillMode: Image.PreserveAspectFit
        }

        // 先鸽 看看怎么协调一下model
        // Text { // 右下角的数量，1省略
        //   anchors.right: parent.right
        //   anchors.rightMargin: 5
        //   anchors.bottom: parent.bottom
        //   anchors.bottomMargin: 5
        //   text: len
        //   visible: len > 1
        //   font.family: Config.libianName
        //   font.pixelSize: 20
        //   font.bold: true
        //   color: "white"
        //   style: Text.Outline
        // }
      }
    }
  }

  function add(inputs) { area.add(inputs); }
  function remove(outputs) { return area.remove(outputs); }
  function updateCardPosition(animated) { area.updateCardPosition(animated); }
}
