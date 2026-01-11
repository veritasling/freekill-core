import QtQuick
import Fk

// 试做型RoomModel
//
// 目标是干掉大部分游戏对局内UI页面/组件的property定义
// 他们只需要一个property RoomModel model就行了，剩下需要的数据从model拿
// 因此，model需要定义对局页面依赖的各种数据
//
// 然后，这个model再负责从Lua中及时取得最新数据。
//
// 预计还需要定义一系列signal
//
// 隔壁PhotoModel同理

QtObject {
  id: root

  property var roomPage

  property string promptText    // 要显示的prompt文本（已翻译）

  property int playerNum        // 房间当前游玩人数
  property int dashboardId      // 初次开局时主视角id 用于保存主视角本来的玩家防止被切视角乱掉

  property int drawPileNum      // 牌堆剩余数
  property int roundCount       // 轮数
  property int playedTime       // 对局已经过的时长

  property list<PhotoModel> players // 所有玩家的photo所需数据（包括自己的）

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
  // 顺便某个角色的pile牌在Photo的显示方面也算作mark；pile在1秒5刷环节更新
  //
  // 当然这是在RoomModel底下，因为banner和mark的逻辑完完全全一样干脆沿用
  property list<var> marks: []

  signal playerAdded(PhotoModel model) // 新玩家加入的信号（addNpc）

  function getTimeString(time) {
    let s = time % 60;
    const m = (time - s) / 60;
    const h = (time - s - m * 60) / 3600;
    if (s < 10) s = '0' + s;
    return h ? `${h}:${m}:${s}` : `${m}:${s}`;
  }

  function getPhoto(pid) {
    for (const model of players) {
      if (model.playerid === pid) {
        return model;
      }
    }
  }

  function setPrompt(text) {
    promptText = Ltk.processPrompt(text);
  }

  // 一秒5刷智慧
  function refreshData() {
    drawPileNum = Lua.client.draw_pile.length;
    for (const model of players) {
      model.refreshData();
    }
  }

  function propertyUpdate(_, data) {
    const [uid, property_name, value] = data;
    const model = getPhoto(uid);
    if (model && property_name in model) {
      model[property_name] = value;
    }
  }

  function startGame() {
    for (const model of players) {
      model.general = "";
    }
  }

  // 因为Banner也是同一逻辑所以放在这
  function setMark(marks, mark, rawValue, playerid) {
    const elem = marks.find(e => e.origName === mark);
    if (rawValue === 0) {
      if (elem) marks.splice(marks.indexOf(elem), 1);
      return;
    }

    let value = rawValue;
    if (mark.startsWith("@@")) {
      value = "";
    } else if (rawValue instanceof ArrayBuffer) {
      // cbor的情况
      value = Ltk.toUIString(rawValue);
    } else if (!(rawValue instanceof Object)) {
      value = rawValue.toString();
    }

    let textValue = "";
    let qmlPath, cheatSource;
    let qmlData = { name: mark };

    if (!mark.startsWith("@")) {
      // Lua不会把不可见mark传来的，所以这部分肯定是玩家pile
      const pile = Ltk.getPlayer(playerid).getPile(mark).filter((e) => Lua.selfPlayer.cardVisible(e));
      if (pile.length === 0) return;

      textValue = pile.length.toString();
      cheatSource = "ViewPile";
      qmlData.ids = pile;
    } else if (mark.startsWith("@$")) {
      // 游戏牌名列表 但也可能是游戏牌id列表呢
      textValue = value.length.toString();
      cheatSource = "ViewPile";
      if (typeof value[0] === "number") {
        qmlData.ids = value;
      } else {
        qmlData.cardNames = value;
      }
    } else if (mark.startsWith("@&")) {
      // 武将牌名列表
      textValue = value.length.toString();
      cheatSource = "ViewGeneralPile";
      qmlData.cardNames = value;
    } else if (mark.startsWith("@[")) {
      const close_br = mark.indexOf(']');
      if (close_br !== -1) {
        const mark_type = mark.slice(2, close_br);
        const data = Ltk.getQmlMark(mark_type, mark, playerid);
        if (data) {
          qmlPath = data.qml_path;
          qmlData.data = data.qml_data;
          qmlData.owner = playerid;
          textValue = data.text;
        }
      }
    } else {
      textValue = value instanceof Array
           ? value.map((markText) => Lua.tr(markText)).join(' ')
           : Lua.tr(value);
    }

    // @!! 追加翻译标记名和描述
    let desc;
    if (mark.startsWith('@!!')) {
      desc = `<b>${Lua.tr(mark)}</b><br>` +
        `${Lua.tr(":" + mark)}${textValue && "<br>" + textValue}`;
    }


    if (elem) {
      elem.value = textValue;
      elem.origValue = value;
      elem.desc = desc;
    } else {
      marks.push({
        name: Lua.tr(mark),
        value: textValue,
        origName: mark,
        origValue: value,
        qmlPath, qmlData, cheatSource,
        desc,
      });
    }
  }

  function setPlayerMark(_, data) {
    const [ id, mark, v ] = data;
    const player = getPhoto(id);
    setMark(mark.startsWith("@!") ? player.picMarks : player.marks, mark, v, id);
  }

  function setBanner(_, data) {
    const [ mark, v ] = data;
    setMark(marks, mark, v);
  }

  function updateLimitSkill(sender, data) {
    const [ id, skill, time ] = data;
    getPhoto(id)?.updateLimitSkill(skill, time);
  }

  function addNpc(_, data) {
    const [id, name, avatar] = data;
    const photoModelComponent = Qt.createComponent("Fk.Components.LunarLTK", "PhotoModel");
    const model = photoModelComponent.createObject(null, {
      playerid: id,
      avatar,
      screenName: name,
      index: players.length,
    });
    model.index = players.length;
    players.push(model);
    playerNum++;
    playerAdded(model);
  }

  // 确定只会修改model属性的逻辑都搬家到这里
  function setupCallbacks() {
    roomPage.addCallback(Command.PropertyUpdate, propertyUpdate);
    roomPage.addCallback(Command.StartGame, startGame);
    roomPage.addCallback(Command.SetPlayerMark, setPlayerMark);
    roomPage.addCallback(Command.SetBanner, setBanner);
    roomPage.addCallback(Command.UpdateLimitSkill, updateLimitSkill);
    roomPage.addCallback("AddNpc", addNpc);
  }

  function initialize() {
    dashboardId = Self.id;
    const luaPlayers = Lua.client.players;
    playerNum = luaPlayers.length;
    const photoModelComponent = Qt.createComponent("Fk.Components.LunarLTK", "PhotoModel");
    for (const player of luaPlayers) {
      const prop = player.__toqml().prop;
      delete prop.scale;
      delete prop.selectable;
      delete prop.state;
      const model = photoModelComponent.createObject(null, prop);
      model.index = players.length;
      players.push(model);
    }
  }
}
