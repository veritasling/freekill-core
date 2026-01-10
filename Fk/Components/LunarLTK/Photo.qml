// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK
import Fk.Components.LunarLTK.Photo
import Fk.Widgets as W

PhotoBase {
  id: root

  required property PhotoModel dataModel
  onDataModelChanged: dataModel.photoItem = root;

  // TODO 这些目前写在PhotoBase，所以先手动绑定，之后大改房间等待页的时候杀之
  playerid: dataModel.playerid
  avatar: dataModel.avatar
  screenName: dataModel.screenName
  general: dataModel.general
  deputyGeneral: dataModel.deputyGeneral
  kingdom: dataModel.kingdom
  seatNumber: dataModel.seatNumber
  dead: dataModel.dead

  property string status: "normal"
  property int distance: -1

  property alias areasSealed: equipAreaItem
  property alias markArea: markAreaItem
  property alias picMarkArea: picMarkAreaItem

  property alias progressBar: progressBar
  property alias progressTip: progressTip.text

  PixmapAnimation {
    id: animPlaying
    source: SkinBank.pixAnimDir + "playing"
    anchors.centerIn: parent
    loop: true
    scale: 0.825
    visible: root.dataModel.phase !== Ltk.Player.NotActive
    running: visible
  }

  PixmapAnimation {
    id: animSelected
    source: SkinBank.pixAnimDir + "selected"
    anchors.centerIn: parent
    loop: true
    scale: 0.825
    visible: root.state === "candidate" && root.selected
    running: visible
  }

  PixmapAnimation {
    id: animSelectable
    source: SkinBank.pixAnimDir + "selectable"
    anchors.centerIn: parent
    loop: true
    visible: root.state === "candidate" && root.selectable
    running: visible
    scale: 0.75
  }

  HpBar {
    id: hp
    x: 6
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 27

    dataModel: root.dataModel
  }

  Rectangle {
    anchors.fill: root.photoMask
    radius: 6

    // visible: root.dataModel.drank > 0
    color: "red"
    opacity: (root.dataModel.drank <= 0 ? 0 : 0.4) + Math.log(root.dataModel.drank) * 0.12
    Behavior on opacity { NumberAnimation { duration: 300 } }
  }

  ColumnLayout {
    id: restRect
    anchors.centerIn: photoMask
    anchors.leftMargin: 15
    visible: root.dataModel.rest > 0

    GlowText {
      Layout.alignment: Qt.AlignCenter
      text: Lua.tr("resting...")
      font.family: Config.libianName
      font.pixelSize: 30
      font.bold: true
      color: "#FEF7D6"
      glow.color: "#845422"
      glow.spread: 0.8
    }

    GlowText {
      Layout.alignment: Qt.AlignCenter
      visible: root.dataModel.rest > 0 && root.dataModel.rest < 999
      text: root.dataModel.rest
      font.family: Config.libianName
      font.pixelSize: 25
      font.bold: true
      color: "#DBCC69"
      glow.color: "#2E200F"
      glow.spread: 0.6
    }

    GlowText {
      Layout.alignment: Qt.AlignCenter
      visible: root.dataModel.rest > 0 && root.dataModel.rest < 999
      text: Lua.tr("rest round num")
      font.family: Config.libianName
      font.pixelSize: 21
      color: "#F0E5D6"
      glow.color: "#2E200F"
      glow.spread: 0.6
    }
  }

  Image {
    visible: equipAreaItem.length > 0
    source: SkinBank.photoDir + "equipbg"
    x: 23
    y: 91
    scale: 0.75
    transformOrigin: Item.TopLeft
  }

  Image {
    source: root.status != "normal" ? SkinBank.statusDir + root.status : ""
    x: -5
    scale: 0.75
    transformOrigin: Item.TopLeft
  }

  Image {
    id: turnedOver
    visible: !root.dataModel.faceup
    source: SkinBank.photoDir + "faceturned" + (Config.heg ? '-heg' : '')
    x: 22; y: 4
    scale: 0.75
    transformOrigin: Item.TopLeft
  }

  EquipArea {
    id: equipAreaItem

    x: 23
    y: 118

    dataModel: root.dataModel
  }

  Item {
    id: specialAreaItem

    x: 23
    y: 104

    InvisibleCardArea {
      id: specialContainer
      // checkExisting: true
    }

    function updatePileInfo(areaName) {
      if (areaName.startsWith('#')) return;
      const data = Ltk.getPile(root.playerid, areaName);
      if (data.length === 0) {
        root.markArea.removeMark(areaName);
      } else {
        root.markArea.setMark(areaName, data.length.toString());
      }
    }

    function add(inputs, areaName) {
      updatePileInfo(areaName);
      specialContainer.add(inputs);
    }

    function remove(inputs, areaName) {
      updatePileInfo(areaName);
      return specialContainer.remove(inputs);
    }

    function updateCardPosition(a) {
      specialContainer.updateCardPosition(a);
    }
  }

  MarkArea {
    id: markAreaItem

    anchors.bottom: equipAreaItem.top
    x: 23
  }

  Image {
    id: chain
    visible: root.dataModel.chained
    source: SkinBank.photoDir + "chain"
    anchors.horizontalCenter: parent.horizontalCenter
    scale: 0.75
    y: 54
  }

  Image {
    // id: saveme
    visible: (root.dead && !root.dataModel.rest) || root.dataModel.dying || root.surrendered
    source: {
      if (root.surrendered) {
        return SkinBank.deathDir + "surrender";
      } else if (root.dead) {
        return SkinBank.getRoleDeathPic(root.dataModel.role);
      }
      return SkinBank.deathDir + "saveme";
    }
    anchors.centerIn: photoMask
    scale: 0.75
  }

  Image {
    id: netstat
    source: SkinBank.stateDir + root.dataModel.netstate
    x: photoMask.x
    y: photoMask.y
    scale: 0.9 * 0.75
    transformOrigin: Item.TopLeft
  }

  Image {
    id: handcardNum
    source: SkinBank.photoDir + "handcard"
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -5
    x: -5
    width: 40
    height: 30

    Text {
      text: {
        const n = root.dataModel.handcards.length;
        const max = root.dataModel.maxCard;
        if (max === root.dataModel.hp || root.dataModel.hp < 0) {
          return n;
        } else {
          const maxCard = max < 900 ? max : "∞";
          return n + "/" + maxCard;
        }
      }
      font.family: Config.libianName
      font.pixelSize: text.includes("/") ? 24 : 20
      //font.weight: 30
      color: "white"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      style: Text.Outline
    }
  }

  RoleComboBox {
    id: role
    value: {
      if (root.dataModel.role === "hidden") return "hidden";
      if (root.dataModel.role_shown) return root.dataModel.role;
      return "unknown";
    }
    anchors.top: parent.top
    anchors.topMargin: -4
    anchors.right: parent.right
    anchors.rightMargin: -4
  }

  LimitSkillArea {
    id: limitSkills
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: role.height + 2
    anchors.rightMargin: 22
  }

  Image {
    visible: root.state === "candidate" && !selectable && !selected
    source: SkinBank.photoDir + "disable"
    x: 23; y: -16
    scale: 0.75
    transformOrigin: Item.TopLeft
  }

  GlowText {
    id: seatNum
    visible: !progressBar.visible
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -24
    font.family: Config.li2Name
    font.pixelSize: 24
    text: {
      const seatChr = [
        "一", "二", "三", "四", "五", "六",
        "七", "八", "九", "十", "十一", "十二",
      ]
      return seatChr[root.seatNumber - 1];
    }

    glow.color: "brown"
    glow.spread: 0.2
    glow.radius: 6
    //glow.samples: 12
  }

  SequentialAnimation {
    id: trembleAnimation
    running: false
    PropertyAnimation {
      target: root
      property: "x"
      to: root.x - 15
      easing.type: Easing.InQuad
      duration: 100
    }
    PropertyAnimation {
      target: root
      property: "x"
      to: root.x
      easing.type: Easing.OutQuad
      duration: 100
    }
  }

  function tremble() {
    trembleAnimation.start()
  }

  ProgressBar {
    id: progressBar
    width: parent.width
    height: 4
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -4
    from: 0.0
    to: 100.0
    property int duration: Config.roomTimeout * 1000

    visible: false
    NumberAnimation on value {
      running: progressBar.visible
      from: 100.0
      to: 0.0
      duration: progressBar.duration

      onFinished: {
        progressBar.visible = false;
        root.progressTip = "";
      }
    }
  }

  Image {
    anchors.top: progressBar.bottom
    anchors.topMargin: 1
    source: SkinBank.photoDir + "control/tip"
    visible: progressTip.text != ""
    scale: 0.75
    transformOrigin: Item.TopLeft
    Text {
      id: progressTip
      font.family: Config.libianName
      font.pixelSize: 18
      x: 18
      color: "white"
      text: ""
    }
  }

  RowLayout {
    anchors.centerIn: parent
    spacing: 5

    Repeater {
      model: root.dataModel.targetTip

      Item {
        required property var modelData
        // Layout.alignment: Qt.AlignHCenter
        width: modelData.type === "normal" ? 30 : 18

        GlowText {
          anchors.centerIn: parent
          visible: parent.modelData.type === "normal"
          text: parent.modelData.content
          font.family: Config.li2Name
          color: "#FEFE84"
          font.pixelSize: {
            if (text.length <= 3) return 27;
            else return 21;
          }
          //font.bold: true
          glow.color: "black"
          glow.spread: 0.3
          glow.radius: 4
          lineHeight: 0.85
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WrapAnywhere
          width: font.pixelSize + 4
        }

        Text {
          anchors.centerIn: parent
          visible: parent.modelData.type === "warning"
          font.family: Config.libianName
          font.pixelSize: 18
          opacity: 0.9
          horizontalAlignment: Text.AlignHCenter
          lineHeight: 18
          lineHeightMode: Text.FixedHeight
          //color: "#EAC28A"
          color: "snow"
          width: 18
          wrapMode: Text.WrapAnywhere
          style: Text.Outline
          //styleColor: "#83231F"
          styleColor: "red"
          text: parent.modelData.content
        }
      }
    }
  }

  InvisibleCardArea {
    id: handcardAreaItem
    anchors.centerIn: parent
    onLengthChanged: root.dataModel.updateHandcards();
  }

  DelayedTrickArea {
    id: delayedTrickAreaItem
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8

    dataModel: root.dataModel
  }

  PicMarkArea {
    id: picMarkAreaItem

    anchors.top: parent.bottom
    anchors.right: parent.right
    anchors.topMargin: -4
  }

  InvisibleCardArea {
    id: defaultArea
    anchors.centerIn: parent
  }

  Rectangle {
    color: "white"
    height: 15
    width: 15
    visible: root.distance != -1
    Text {
      text: root.distance
      anchors.centerIn: parent
    }
  }

  HandcardViewer {
    anchors.right: parent.left
    anchors.bottom: parent.bottom
    scale: 0.75
    transformOrigin: Item.BottomRight

    dataModel: root.dataModel
  }

  function updateLimitSkill(skill, time) {
    limitSkills.update(skill, time);
  }

  function handleMarkAreaUpdate(data) {
    if (data.visible !== undefined) {
      picMarkAreaItem.visible = data.visible;
      markAreaItem.visible = data.visible;
    }
  }

  function getAreaItem(area) {
    if (area === Ltk.Card.PlayerHand) {
      return handcardAreaItem;
    } else if (area === Ltk.Card.PlayerEquip) {
      return equipAreaItem;
    } else if (area === Ltk.Card.PlayerJudge) {
      return delayedTrickAreaItem;
    } else if (area === Ltk.Card.PlayerSpecial) {
      return specialAreaItem;
    }

    return null;
  }
}
