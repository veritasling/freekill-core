import QtQuick
import Fk
import Fk.Components.LunarLTK

QtObject {
  id: root

  property var photoItem
  property var luaPlayer: Ltk.getPlayer(playerid)

  property int index: 0 // photo们在屏幕内的排位 用于arrangePhotos

  // 玩家相关信息
  property int playerid: -1
  property string avatar: ""
  property string screenName: ""
  property string netstate: "online"

  // 角色相关信息
  property string general: ""
  property string deputyGeneral: ""
  property int maxHp: 0
  property int hp: 0
  property int shield: 0
  property int gender: Ltk.General.Female
  property string kingdom: "qun"
  property string role: "unknown"
  property bool dying: false
  property bool dead: false
  property int rest: 0
  property bool faceup: true
  property bool chained: false
  property list<string> sealedSlots: []
  property int seatNumber: 1
  property int drank: 0
  property int phase: Ltk.Player.NotActive
  property bool surrendered: false

  // 一些并非是固定值的角色属性，需随时刷新的玩意
  property int maxCard: 0
  property int distance: -1
  property bool role_shown: false
  property list<int> handcards

  // 其他UI元素
  property var targetTip: []

  function updateHandcards() {
    handcards = luaPlayer.getCardIds("h");
  }

  function refreshData() {
    maxCard = luaPlayer.getMaxCards();
    role_shown = Lua.selfPlayer.roleVisible(luaPlayer);
    handcardsChanged();
  }

  function updateTargetTip() {
    const dataList = Ltk.getTargetTip(playerid);
    // 翻译是个逻辑，这里要负责直接向ui呈送需要的文本
    for (const data of dataList) {
      data.content = Ltk.processPrompt(data.content);
    }
    targetTip = dataList;
  }
}
