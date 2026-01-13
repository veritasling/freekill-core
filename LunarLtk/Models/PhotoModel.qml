import QtQuick
import Fk
import LunarLtk

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

  // 需要直接显示出来的卡牌
  property list<CardModel> delayedTricks: [];
  property list<CardModel> equips: [];

  // 其他UI元素
  property var targetTip: []  // “可烈弓”之类的目标提示文本，已翻译好
  property list<var> limitSkills: []  // 限定技区域，var的内容为 { skill, time }

  // 此人的所有标记，不分图和无图，毕竟这里是数据model环节
  // var的结构为如此的object：
  // - name: 标记名（已翻译）
  // - value: 标记应该显示出的值（比如某些标记的长度，或how_to_show）
  // - origName: 未翻译的标记名
  // - origValue: 未处理过的原value
  // - desc: @!!图片标专用（已力竭）
  // - qmlPath: 若为qml mark则为要加载的qml文件
  // - qmlData: 同前
  // - cheatSource: 应付pile和武将牌列表的玩意，一下子想不出好办法
  property list<var> marks: []
  property list<var> picMarks: [] // Photo特有，内容与marks一致

  // 与UI交互相关
  property string state: "normal" // normal - 正常 candidate - 待选
  property bool selectable: false
  property bool selected: false // 这个反过来被绑定

  onSelectedChanged: {
    if (state !== "candidate") return;
    Ltk.updateRequestUI("Photo", playerid, "click", { selected, autoTarget: Config.autoTarget } );
  }

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

  function updateLimitSkill(skill, time) {
    const elem = limitSkills.find(e => e.skill === skill);
    if (elem) {
      elem.time = time;
      if (time === -1) {
        limitSkills.splice(limitSkills.indexOf(elem), 1);
      }
    } else if (time > -1) {
      limitSkills.push({ skill, time });
    }
  }
}
