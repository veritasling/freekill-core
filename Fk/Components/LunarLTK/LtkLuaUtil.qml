// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick
import Fk

QtObject {

  // 遵循Lua里面那样，把相关枚举全堆到这里
  enum General {
    Male = 1,
    Female = 2,
    Bigender = 3,
    Agender = 4
  }

  enum Player {
    RoundStart = 1,
    Start = 2,
    Judge = 3,
    Draw = 4,
    Play = 5,
    Discard = 6,
    Finish = 7,
    NotActive = 8,
    PhaseNone = 9
  }

  enum Card {
    Spade = 1,
    Club = 2,
    Heart = 3,
    Diamond = 4,
    NoSuit = 5,

    Black = 1,
    Red = 2,
    NoColor = 3,

    Unknown = 0,
    PlayerHand = 1,
    PlayerEquip = 2,
    PlayerJudge = 3,
    PlayerSpecial = 4,
    Processing = 5,
    DrawPile = 6,
    DiscardPile = 7,
    Void = 8
  }

  // 奇技淫巧系列

  function getPlayer(id) {
    return Lua.evaluate(`ClientInstance:getPlayerById(${id})`);
  }

  function getCard(id) {
    return Lua.evaluate(`Fk:getCardById(${id})`);
  }

  function getGeneral(name) {
    return Lua.evaluate(`Fk.generals['${name}']`);
  }

  function getSkill(name) {
    return Lua.evaluate(`Fk.skills['${name}']`);
  }

  function getPackage(name) {
    return Lua.evaluate(`Fk.packages['${name}']`);
  }

  ///////////////// 施工中 //////////////////////
  // 把client_util.lua公式化转了一遍。还没剔除
  ///////////////// 施工中 //////////////////////

  function getGeneralData(name) {
    return Lua.call("GetGeneralData", name);
  }

  function getGeneralDetail(name) {
    return Lua.call("GetGeneralDetail", name);
  }

  function getSameGenerals(name) {
    return Lua.call("GetSameGenerals", name);
  }

  function isCompanionWith(general, general2) {
    return Lua.call("IsCompanionWith", general, general2);
  }

  function getCardData(id, filterCard) {
    return Lua.call("GetCardData", id, filterCard);
  }

  function getCardExtensionByName(cardName) {
    return Lua.call("GetCardExtensionByName", cardName);
  }

  function getAllGeneralPack() {
    return Lua.call("GetAllGeneralPack");
  }

  function getAllProperties() {
    return Lua.call("GetAllProperties");
  }

  function getGenerals(pack_name) {
    return Lua.call("GetGenerals", pack_name);
  }

  function searchAllGenerals(word) {
    return Lua.call("SearchAllGenerals", word);
  }

  function searchGenerals(pack_name, word) {
    return Lua.call("SearchGenerals", pack_name, word);
  }

  function filterAllGenerals(filter) {
    return Lua.call("FilterAllGenerals", filter);
  }

  function updatePackageEnable(pkg, enabled) {
    return Lua.call("UpdatePackageEnable", pkg, enabled);
  }

  function getAvailableGeneralsNum() {
    return Lua.call("GetAvailableGeneralsNum");
  }

  function getAllCardPack() {
    return Lua.call("GetAllCardPack");
  }

  function getCards(pack_name) {
    return Lua.call("GetCards", pack_name);
  }

  function getPlayerSkills(id) {
    return Lua.call("GetPlayerSkills", id);
  }

  function getSkillData(skill_name) {
    return Lua.call("GetSkillData", skill_name);
  }

  function cardFitPattern(card_name, pattern) {
    return Lua.call("CardFitPattern", card_name, pattern);
  }

  function getVirtualEquipData(playerid, cid) {
    return Lua.call("GetVirtualEquipData", playerid, cid);
  }

  function getGameModes() {
    return Lua.call("GetGameModes");
  }

  function resetClientLua() {
    return Lua.call("ResetClientLua");
  }

  function getCompNum() {
    return Lua.call("GetCompNum");
  }

  function getPlayerGameData(pid) {
    return Lua.call("GetPlayerGameData", pid);
  }

  function setPlayerGameData(pid, data) {
    return Lua.call("SetPlayerGameData", pid, data);
  }

  function setObserving(o) {
    return Lua.call("SetObserving", o);
  }

  function setReplaying(o) {
    return Lua.call("SetReplaying", o);
  }

  function setReplayingShowCards(o) {
    return Lua.call("SetReplayingShowCards", o);
  }

  function checkSurrenderAvailable() {
    return Lua.call("CheckSurrenderAvailable");
  }

  function findMosts() {
    return Lua.call("FindMosts");
  }

  function entitle(data, seat, winner) {
    return Lua.call("Entitle", data, seat, winner);
  }

  function saveRecord() {
    return Lua.call("SaveRecord");
  }

  function getCardProhibitReason(cid) {
    return Lua.call("GetCardProhibitReason", cid);
  }

  function getTargetTip(pid) {
    return Lua.call("GetTargetTip", pid);
  }

  function canSortHandcards(pid) {
    return Lua.call("CanSortHandcards", pid);
  }

  function chooseGeneralPrompt(rule_name, data, extra_data) {
    return Lua.call("ChooseGeneralPrompt", rule_name, data, extra_data);
  }

  function chooseGeneralFilter(rule_name, to_select, selected, data, extra_data) {
    return Lua.call("ChooseGeneralFilter", rule_name, to_select, selected, data, extra_data);
  }

  function chooseGeneralFeasible(rule_name, selected, data, extra_data) {
    return Lua.call("ChooseGeneralFeasible", rule_name, selected, data, extra_data);
  }

  function poxiPrompt(poxi_type, data, extra_data) {
    return Lua.call("PoxiPrompt", poxi_type, data, extra_data);
  }

  function poxiFilter(poxi_type, to_select, selected, data, extra_data) {
    return Lua.call("PoxiFilter", poxi_type, to_select, selected, data, extra_data);
  }

  function poxiFeasible(poxi_type, selected, data, extra_data) {
    return Lua.call("PoxiFeasible", poxi_type, selected, data, extra_data);
  }

  function getQmlMark(mtype, name, p) {
    return Lua.call("GetQmlMark", mtype, name, p);
  }

  function getMiniGame(gtype, p, data) {
    return Lua.call("GetMiniGame", gtype, p, data);
  }

  function getPendingSkill() {
    return Lua.call("GetPendingSkill");
  }

  function revertSelection() {
    return Lua.call("RevertSelection");
  }

  function updateRequestUI(elemType, id, action, data) {
    return Lua.call("UpdateRequestUI", elemType, id, action, data);
  }

  function finishRequestUI() {
    return Lua.call("FinishRequestUI");
  }

  function hasVisibleCard(me, other, special_name) {
    return Lua.call("HasVisibleCard", me, other, special_name);
  }

  function refreshStatusSkills() {
    return Lua.call("RefreshStatusSkills");
  }

  function getPlayersAndObservers() {
    return Lua.call("GetPlayersAndObservers");
  }

  function toUIString(v) {
    return Lua.call("ToUIString", v);
  }

  function convertNumber(number) {
    if (number === 1)
    return "A";
    if (number >= 2 && number <= 10)
    return number;
    if (number >= 11 && number <= 13) {
      const strs = ["J", "Q", "K"];
      return strs[number - 11];
    }
    return "";
  }

  function getPlayerStr(playerid) {
    const player = getPlayer(playerid);
    const general = player.general;
    const deputy = player.deputyGeneral;
    const seatNumber = player.seat;

    let ret;
    if (general === "anjiang" && (deputy === "anjiang" || !deputy)) {
      ret = Lua.tr("seat#" + player.seat);
    } else {
      ret = Lua.tr(general);
      if (deputy && deputy !== "") {
        ret = ret + "/" + Lua.tr(deputy);
      }
    }
    if (playerid == Self.id) {
      ret = ret + Lua.tr("playerstr_self")
    }
    return ret;
  }

  function processPrompt(prompt) {
    const data = prompt.split(":");
    let raw = Lua.tr(data[0]);
    const src = parseInt(data[1]);
    const dest = parseInt(data[2]);
    if (raw.match("%src"))
    raw = raw.replace(/%src/g, getPlayerStr(src));
    if (raw.match("%dest"))
    raw = raw.replace(/%dest/g, getPlayerStr(dest));

    if (data.length > 3) {
      for (let i = 4; i < data.length; i++) {
        raw = raw.replace(new RegExp("%arg" + (i - 2), "g"), Lua.tr(data[i]));
      }

      raw = raw.replace(new RegExp("%arg", "g"), Lua.tr(data[3]));
    }
    return raw;
  }
}
