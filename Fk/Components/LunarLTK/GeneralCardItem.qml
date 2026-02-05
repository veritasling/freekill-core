// SPDX-FileCopyrightText: 2023-2024 Revol_Cai
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtMultimedia
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.GameCommon as Game
import Fk.Components.LunarLTK
import Fk.Components.LunarLTK.Photo

Game.BasicCard {
  id: root
  width: 93
  height: 130

  property string name
  property string kingdom
  property string subkingdom: "wei"
  property int hp
  property int maxHp
  property int shieldNum
  property int mainMaxHp
  property int deputyMaxHp
  property int inPosition: 0
  property string pkgName: ""
  property bool detailed: true
  property bool showIsFavorite: true
  // 动态皮肤支持
  property var animationInfo: ({ hasAnimation: false, files: {}, types: {} })
  property string currentAnimType: "entry"
  property alias hasCompanions: companions.visible
  
  // 防重复初始化标记
  property bool initializing: false
  // 待处理的初始化Timer（防重复）
  property var pendingInitTimer: null
  
  footnote: ""
  
  // ========== 辅助函数：严格安全路径检查 ==========
  function safePath(path) {
    if (!path || path === "") return "";
    // 检查是否为空resource_pak路径
    if (path === "file:///C:/FreeKill-v0.5.19/FreeKill-release/resource_pak/" || 
        path === "file:///.../resource_pak/" ||
        path.endsWith("resource_pak/") ||
        path.endsWith("resource_pak")) {
      return "";
    }
    return path;
  }

  // 【优化】检查是否启用了动态包（使用函数静态属性保存结果，避免重复遍历）
  function checkHasDynamicPack() {
    // 使用函数对象的属性作为全局缓存（跨实例共享）
    if (checkHasDynamicPack.checked === undefined) {
      checkHasDynamicPack.checked = false
      checkHasDynamicPack.result = false
    }
    
    if (checkHasDynamicPack.checked) {
      return checkHasDynamicPack.result
    }
    
    var hasDynamic = false
    if (typeof Config !== "undefined" && Config.enabledResourcePacks) {
      for (var i = 0; i < Config.enabledResourcePacks.length; i++) {
        var pack = Config.enabledResourcePacks[i]
        if (pack && pack.indexOf("动态") !== -1) {
          hasDynamic = true
          break
        }
      }
    }
    
    checkHasDynamicPack.checked = true
    checkHasDynamicPack.result = hasDynamic
    console.log("DEBUG: Dynamic pack check result:", hasDynamic)
    return hasDynamic
  }

  // ========== 动态皮肤初始化（全局缓存优化版） ==========
  function initializeAnimation() {
    if (!name || name === "" || initializing) return
    
    // 【优化1】如果没有启用动态包，直接标记为无动画，避免调用 SkinBank
    if (!checkHasDynamicPack()) {
      animationInfo = { hasAnimation: false, files: {}, types: {} }
      return
    }
    
    // 【优化2】使用函数静态属性作为全局缓存（跨所有 GeneralCardItem 实例共享）
    if (!initializeAnimation.cache) {
      initializeAnimation.cache = {}
    }
    
    // 【优化3】检查全局缓存
    if (initializeAnimation.cache[name] !== undefined) {
      const cached = initializeAnimation.cache[name]
      animationInfo = cached
      if (cached.hasAnimation && cached.files[currentAnimType]) {
        Qt.callLater(function() {
          startVideoPlayback(currentAnimType)
        })
      }
      return
    }
    
    initializing = true
    console.log(">>> initializeAnimation (global cache miss):", name)
    
    Qt.callLater(function() {
      try {
        const result = SkinBank.getGeneralAnimationFiles(name)
        // 【优化4】写入全局缓存
        initializeAnimation.cache[name] = result || { hasAnimation: false, files: {}, types: {} }
        animationInfo = initializeAnimation.cache[name]
        
        if (result && result.hasAnimation) {
          const startType = result.files.entry ? "entry" : "idle"
          currentAnimType = startType
          startVideoPlayback(startType)
        }
      } catch (e) {
        console.error(">>> Error:", e)
        animationInfo = { hasAnimation: false, files: {}, types: {} }
        initializeAnimation.cache[name] = animationInfo
      } finally {
        initializing = false
      }
    })
  }


  // ========== 视频播放控制（防闪白+防卡死） ==========
  function startVideoPlayback(type) {
    if (!animationInfo.hasAnimation) return;
    
    const source = safePath(animationInfo.files[type]);
    
    // 严格检查空路径，防止卡死
    if (!source || source === "") {
      console.log(">>> Empty source for type:", type, "- disabling animation");
      animationInfo = { hasAnimation: false, files: {}, types: {} };
      return;
    }
    
    const isVideo = animationInfo.types[type] === "video";
    
    if (isVideo) {
      // 停止GIF
      gifPlayer.visible = false;
      gifPlayer.playing = false;
      gifPlayer.source = "";
      
      // 确定目标视频（当前不透明的是current，否则是next）
      var targetVideo = (currentVideo.opacity > 0.5 && currentVideo.playbackState === MediaPlayer.PlayingState) ? nextVideo : currentVideo;
      var otherVideo = (targetVideo === currentVideo) ? nextVideo : currentVideo;
      
      // 如果目标视频已经在播放且源相同，不重复设置
      if (targetVideo.source === source && targetVideo.playbackState === MediaPlayer.PlayingState) {
        return;
      }
      
      // 停止旧视频
      if (otherVideo.opacity === 0) {
        otherVideo.stop();
        otherVideo.source = "";
      }
      
      // 设置新视频
      targetVideo.stop();
      targetVideo.source = source;
      targetVideo.loops = (type === "idle") ? MediaPlayer.Infinite : 1;
      
      // 关键：先设置为透明，等待第一帧渲染
      targetVideo.opacity = 0;
      targetVideo.play();
      
      // 启动第一帧检测
      firstFrameTimer.targetVideo = targetVideo;
      firstFrameTimer.otherVideo = otherVideo;
      firstFrameTimer.start();
    } else {
      // GIF播放
      currentVideo.stop();
      nextVideo.stop();
      currentVideo.opacity = 0;
      nextVideo.opacity = 0;
      currentVideo.source = "";
      nextVideo.source = "";
      
      gifPlayer.source = source;
      gifPlayer.visible = true;
      gifPlayer.playing = true;
    }
  }
  
  // 第一帧就绪检测（防闪白核心）
  Timer {
    id: firstFrameTimer
    property var targetVideo: null
    property var otherVideo: null
    interval: 150  // 增加到150ms确保第一帧渲染完成
    repeat: false
    
    onTriggered: {
      if (!targetVideo) return;
      
      // 检查视频是否已加载并播放
      if (targetVideo.playbackState === MediaPlayer.PlayingState || 
          targetVideo.status === MediaPlayer.Buffered ||
          targetVideo.position > 0) {
        
        console.log(">>> First frame ready, starting crossfade");
        videoFadeAnimation.targetVideo = targetVideo;
        videoFadeAnimation.otherVideo = otherVideo;
        videoFadeAnimation.start();
      } else if (targetVideo.status === MediaPlayer.Error) {
        // 加载失败，回退到静态图
        console.error(">>> Video load error, falling back to static");
        animationInfo = { hasAnimation: false, files: {}, types: {} };
      } else {
        // 如果还没准备好，再延长50ms（最多重试3次）
        console.log(">>> Video not ready, retrying...");
        if (!firstFrameTimer.retryCount) firstFrameTimer.retryCount = 0;
        if (firstFrameTimer.retryCount < 3) {
          firstFrameTimer.retryCount++;
          firstFrameTimer.start();
        } else {
          // 超时，强制开始交叉淡化或回退
          if (targetVideo.playbackState !== MediaPlayer.StoppedState) {
            videoFadeAnimation.targetVideo = targetVideo;
            videoFadeAnimation.otherVideo = otherVideo;
            videoFadeAnimation.start();
          } else {
            animationInfo = { hasAnimation: false, files: {}, types: {} };
          }
          firstFrameTimer.retryCount = 0;
        }
      }
    }
  }
  
  // 交叉淡化动画
  SequentialAnimation {
    id: videoFadeAnimation
    property var targetVideo: null
    property var otherVideo: null
    
    ParallelAnimation {
      NumberAnimation { 
        target: videoFadeAnimation.targetVideo; 
        property: "opacity"; 
        to: 1; 
        duration: 300 
      }
      NumberAnimation { 
        target: videoFadeAnimation.otherVideo; 
        property: "opacity"; 
        to: 0; 
        duration: 300 
      }
    }
    ScriptAction {
      script: {
        // 停止并清理旧视频
        if (videoFadeAnimation.otherVideo) {
          videoFadeAnimation.otherVideo.stop();
          videoFadeAnimation.otherVideo.source = "";
        }
        console.log(">>> Crossfade completed");
      }
    }
  }

  // ========== 主显示区域（防卡死设计） ==========
  Item {
    id: generalDisplay
    anchors.fill: parent
    anchors.margins: 1
    visible: parent.known
    clip: true
    
    // 静态图片（作为fallback始终准备，当视频未加载或失败时显示）
    Image {
      id: staticImage
      anchors.fill: parent
      // 【优化】增强可见性判断：当动画未就绪或视频透明度低时显示
      visible: !!source && source !== "" && (
        !animationInfo.hasAnimation || 
        !animationInfo.files[currentAnimType] ||
        (currentVideo.opacity < 0.1 && nextVideo.opacity < 0.1)
      )
      fillMode: Image.PreserveAspectFit
      source: {
        if (name === "") return "";
        var path = SkinBank.getGeneralPicture(root.name);
        return safePath(path);
      }
      z: 1  // 【新增】确保在视频下层或上层作为兜底
      
      onStatusChanged: {
        if (status === Image.Error) {
          console.log("Static image load failed for:", root.name);
          source = "";
        }
      }
    }
    
    // 动画容器 - 黑色背景防闪白
    Rectangle {
      id: animContainer
      anchors.fill: parent
      visible: animationInfo.hasAnimation && !!animationInfo.files[currentAnimType]
      color: "black"  // 关键修复：黑色背景防止闪白
      clip: true
      z: 2  // 【明确】视频层在静态图之上
      
      // 当前视频
      Video {
        id: currentVideo
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        autoPlay: false
        opacity: 1
        
        onPlaybackStateChanged: {
          if (playbackState === MediaPlayer.StoppedState && opacity > 0.5) {
            if (currentAnimType === "entry") {
              console.log(">>> Entry ended, switch to idle");
              currentAnimType = "idle";
              startVideoPlayback("idle");
            } else if (currentAnimType === "special") {
              console.log(">>> Special ended, preparing to switch");
              // 【修复】触发回退Timer
              specialToIdleTimer.start();
            }
          }
        }
        
        // 修正：Qt 6 中使用 errorOccurred，且需要判断 error !== MediaPlayer.NoError
        onErrorOccurred: {
          console.error(">>> Video error:", errorString, "- falling back to static");
          animationInfo = { hasAnimation: false, files: {}, types: {} };
        }
      }
      
            Video {
        id: nextVideo
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        autoPlay: false
        opacity: 0
        
        // 【修复】添加播放状态处理，与 currentVideo 保持一致
        onPlaybackStateChanged: {
          if (playbackState === MediaPlayer.StoppedState && opacity > 0.5) {
            if (currentAnimType === "entry") {
              console.log(">>> NextVideo Entry ended, switch to idle");
              currentAnimType = "idle";
              startVideoPlayback("idle");
            } else if (currentAnimType === "special") {
              console.log(">>> NextVideo Special ended, preparing to switch");
              specialToIdleTimer.start();
            }
          }
        }
        
        onErrorOccurred: {
          console.error(">>> NextVideo error:", errorString);
        }
      }
      
      // GIF备选
      AnimatedImage {
        id: gifPlayer
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: false
        playing: false
        
        onCurrentFrameChanged: {
          if (frameCount > 0 && currentFrame === frameCount - 1 && currentAnimType === "entry") {
            Qt.callLater(function() {
              currentAnimType = "idle";
              startVideoPlayback("idle");
            });
          }
        }
        
        onStatusChanged: {
          if (status === Image.Error) {
            console.error(">>> GIF load error, falling back to static");
            animationInfo = { hasAnimation: false, files: {}, types: {} };
          }
        }
      }
    }
  }

  // 随机特殊动画Timer
  Timer {
    interval: 8000 + Math.random() * 7000
    running: animationInfo.hasAnimation && currentAnimType === "idle" && !initializing && root.visible
    repeat: true
    onTriggered: {
      const rand = Math.random();
      if (rand < 0.1 && animationInfo.files.entry) {
        currentAnimType = "entry";
        startVideoPlayback("entry");
      } else if (rand < 0.4 && animationInfo.files.special) {
        currentAnimType = "special";
        startVideoPlayback("special");
      }
    }
  }

  // 【修复】specialToIdleTimer - 缩短延迟并添加回退逻辑（只保留这一个定义）
   // 【修复】specialToIdleTimer - 延长延迟确保稳定性
  Timer {
    id: specialToIdleTimer
    interval: 300  // 改为 300ms，与交叉淡化动画同步
    running: false
    repeat: false
    onTriggered: {
      // 优先级回退逻辑：idle → entry → 静态图
      if (animationInfo.files.idle) {
        console.log(">>> Special -> Idle");
        currentAnimType = "idle";
        startVideoPlayback("idle");
      } else if (animationInfo.files.entry) {
        console.log(">>> Special -> Entry (no idle)");
        currentAnimType = "entry";
        startVideoPlayback("entry");
      } else {
        console.log(">>> Special -> No animation fallback");
        animationInfo = { hasAnimation: false, files: {}, types: {} };
      }
    }
  }
  
  cardBackSource: SkinBank.generalCardDir + 'card-back'
  glow.color: "white"

  property bool heg: name.startsWith('hs__') || name.startsWith('ld__') ||
                     name.includes('heg__')

  Image {
    anchors.fill: parent
    anchors.margins: -1
    fillMode: Image.PreserveAspectFit
    source: parent.known ? safePath(SkinBank.generalCardDir + "border") : ""
    visible: !!source && source !== ""
  }

  Image {
    scale: parent.subkingdom ? 0.6 : 1
    width: 34; fillMode: Image.PreserveAspectFit
    anchors.top: parent.top
    anchors.topMargin: parent.subkingdom ? -7 : -2
    anchors.left: parent.left
    anchors.leftMargin: parent.subkingdom ? -8 : -2
    source: (parent.kingdom && parent.known) ? safePath(SkinBank.getGeneralCardDir(parent.kingdom) + parent.kingdom) : ""
    visible: parent.detailed && parent.known && !!source && source !== ""
  }

  Image {
    scale: 0.6; x: 8; y: 12
    transformOrigin: Item.TopLeft
    width: 34; fillMode: Image.PreserveAspectFit
    source: (parent.subkingdom && parent.detailed && parent.known) ? safePath(SkinBank.getGeneralCardDir(parent.subkingdom) + parent.subkingdom) : ""
    visible: parent.detailed && parent.known && !!source && source !== ""
  }

  Component {
    id: duelkingdomMagatama
    Item {
      width: 10
      height: 10 / childrenRect.width * childrenRect.height
      Image {
        id: mainMagatama
        source: (root.kingdom && !root.subkingdom) ? safePath(SkinBank.getGeneralCardDir(root.kingdom) + root.kingdom + "-magatama") : ""
        width: 10
        height: 10 / sourceSize.width * sourceSize.height
        visible: !root.subkingdom
      }
      LinearGradient {
        id: mainMagatamaMask
        visible: false
        anchors.fill: mainMagatama
        gradient: Gradient {
          GradientStop { position: 0.2; color: "white" }
          GradientStop { position: 0.8; color: "transparent" }
        }
      }
      OpacityMask {
        anchors.fill: mainMagatama
        source: mainMagatama
        maskSource: mainMagatamaMask
        visible: !!root.subkingdom
      }

      Image {
        id: subkingdomMagatama
        visible: false
        width: 10
        height: 10 / sourceSize.width * sourceSize.height
        source: (root.subkingdom) ? safePath(SkinBank.getGeneralCardDir(root.subkingdom) + root.subkingdom + "-magatama") : ""
      }
      LinearGradient {
        id: subkingdomMask
        visible: false
        anchors.fill: subkingdomMagatama
        gradient: Gradient {
          GradientStop { position: 0.2; color: "transparent" }
          GradientStop { position: 0.8; color: "white" }
        }
      }
      OpacityMask {
        anchors.fill: subkingdomMagatama
        source: subkingdomMagatama
        maskSource: subkingdomMask
        visible: root.subkingdom
      }
    }
  }

  Component {
    id: singlekingdomMagatama
    Item {
      width: childrenRect.width
      height: childrenRect.height
      Image {
        id: singleMagatamaImg
        source: (root.kingdom) ? safePath(SkinBank.getGeneralCardDir(root.kingdom) + root.kingdom + "-magatama") : ""
        width: 10
        height: 10 / sourceSize.width * sourceSize.height
        visible: !!source && source !== ""
      }
    }
  }

  Row {
    id: magatamaRow
    x: 34; y: 4
    spacing: 1
    visible: parent.detailed && parent.known && !parent.heg
    Repeater {
      id: hpRepeater
      model: (!root.heg) ? ((root.hp > 5 || root.hp !== root.maxHp) ? 1 : root.hp) : 0
      delegate: root.subkingdom ? duelkingdomMagatama : singlekingdomMagatama
    }
  }

  Text {
    anchors.left: magatamaRow.right
    anchors.leftMargin: -1
    visible: root.hp > 5 || root.hp !== root.maxHp
    text: root.hp === root.maxHp ? (" x" + root.hp) : (" " + root.hp + "/" + root.maxHp)
    color: "white"
    font.family: Config.libianName
    font.pixelSize: 14
    font.bold: true
    style: Text.Outline
    y: 1
  }

  Row {
    x: 34
    y: 3
    spacing: 0
    visible: detailed && known && heg
    Repeater {
      id: hegHpRepeater
      model: heg ? ((hp > 7 || hp !== maxHp) ? 1 : Math.ceil(hp / 2)) : 0
      Item {
        width: childrenRect.width
        height: childrenRect.height
        Image {
          opacity: ((mainMaxHp < 0 || deputyMaxHp < 0) && (index * 2 + 1 === hp) && inPosition !== -1)
                    ? (inPosition === 0 ? 0.5 : 0) :1
          height: 12; fillMode: Image.PreserveAspectFit
          source: (kingdom) ? safePath(SkinBank.getGeneralCardDir(kingdom) + kingdom + "-magatama-l") : ""
          visible: !!source && source !== ""
        }
        Image {
          x: 4.4
          opacity: (index + 1) * 2 <= hp ? (((mainMaxHp < 0 || deputyMaxHp < 0) && inPosition !== -1 && ((index + 1) * 2 === hp))
                    ? (inPosition === 0 ? 0.5 : 0) : 1) : 0
          height: 12; fillMode: Image.PreserveAspectFit
          source: {
            const k = subkingdom ? subkingdom : kingdom;
            return (k) ? safePath(SkinBank.getGeneralCardDir(k) + k + "-magatama-r") : "";
          }
          visible: !!source && source !== ""
        }
      }
    }

    Text {
      visible: hp > 7 || hp !== maxHp
      text: hp === maxHp ? ("x" + hp / 2) : (" " + hp / 2 + "/" + maxHp / 2)
      color: "white"
      font.pixelSize: 14
      style: Text.Outline
      y: -4
    }
  }

  Shield {
    visible: shieldNum > 0 && detailed && known
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: hpRepeater.model > 4 ? 16 : 0
    scale: 0.8
    value: shieldNum
  }

  Image {
    id: companions
    width: parent.width
    fillMode: Image.PreserveAspectFit
    visible: false
    source: {
      if (!kingdom) return "";
      const f = SkinBank.getGeneralCardDir(kingdom) + kingdom + "-companions";
      if (Backend.exists(f + ".png")) return f;
      return "";
    }
    anchors.horizontalCenter: parent.horizontalCenter
    y: 80
  }
  
  Glow {
    source: generalName
    anchors.fill: generalName
    color: "black"
    spread: 0.3
    radius: 5
  }

  Text {
    id: generalName
    width: 20
    height: 80
    x: 3
    y: lineCount > 4 ? 28 : 30
    text: name !== "" ? Lua.tr(name) : "nil"
    visible: detailed && known
    color: "white"
    font.family: "LiSu"
    font.pixelSize: 18
    lineHeight: Math.max(1.25 - lineCount / 8, 0.8)
    style: Text.Outline
    wrapMode: Text.WrapAnywhere
  }

  Rectangle {
    visible: pkgName !== "" && detailed && known
    height: 16
    width: pkgNameText.width + 15
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    color: "transparent"

    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
      GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.5) }
      GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 1) }
    }
    Text {
      id: pkgNameText
      text: Lua.tr(pkgName)
      x: 13; y: 1
      font.family: Config.libianName
      font.pixelSize: 14
      color: "white"
      style: Text.Outline
      textFormat: Text.RichText
      width: implicitWidth
    }
  }

  Item {
    visible: Config.favoriteGenerals.includes(parent.name) && parent.showIsFavorite
    width: 15; height: 15
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.margins: 1
    Canvas {
      id: starCanvas
      anchors.fill: parent
      onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var cx = width/2;
        var cy = height/2;
        var spikes = 5;
        var outerRadius = Math.min(width, height) * 0.45;
        var innerRadius = outerRadius * 0.45;
        var rot = -Math.PI/2;
        ctx.beginPath();
        for (var i = 0; i < spikes; i++) {
          var x = cx + Math.cos(rot) * outerRadius;
          var y = cy + Math.sin(rot) * outerRadius;
          ctx.lineTo(x, y);
          rot += Math.PI / spikes;
          x = cx + Math.cos(rot) * innerRadius;
          y = cy + Math.sin(rot) * innerRadius;
          ctx.lineTo(x, y);
          rot += Math.PI / spikes;
        }
        ctx.closePath();
        ctx.fillStyle = "red";
        ctx.fill();
        ctx.lineWidth = 1;
        ctx.strokeStyle = "white";
        ctx.stroke();
      }
      Component.onCompleted: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
    }
  }

  // ========== 名称变更处理（修复版）==========
  onNameChanged: {
    console.log(">>> onNameChanged called with:", name);
    
    // 取消待处理的初始化Timer（防重复）
    if (pendingInitTimer) {
      pendingInitTimer.stop();
      pendingInitTimer.destroy();
      pendingInitTimer = null;
    }
    
    // 重置所有动画状态
    animationInfo = { hasAnimation: false, files: {}, types: {} };
    currentAnimType = "entry";
    initializing = false;
    
    // 停止所有视频和动画
    currentVideo.stop();
    nextVideo.stop();
    currentVideo.source = "";
    nextVideo.source = "";
    currentVideo.opacity = 1;
    nextVideo.opacity = 0;
    gifPlayer.source = "";
    gifPlayer.visible = false;
    gifPlayer.playing = false;
    firstFrameTimer.stop();
    videoFadeAnimation.stop();
    
    if (!name || name === "") {
      kingdom = "";
      subkingdom = "";
      return;
    }

    // 获取武将数据
    const data = Ltk.getGeneralData(name);
    console.log(">>> Got data:", JSON.stringify(data));
    
    kingdom = data.kingdom || "";
    subkingdom = (data.subkingdom !== kingdom && data.subkingdom) || "";
    hp = data.hp;
    maxHp = data.maxHp;
    shieldNum = data.shield;
    mainMaxHp = data.mainMaxHpAdjustedValue;
    deputyMaxHp = data.deputyMaxHpAdjustedValue;

    const splited = name.split("__");
    pkgName = (splited.length > 1) ? splited[0] : "";
    
    // 延迟50ms初始化，避免列表滚动时阻塞UI
    pendingInitTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 50; repeat: false; onTriggered: parent.initializeAnimation() }', root);
    pendingInitTimer.start();
  }

  // ========== 组件完成处理（防重复）==========
  Component.onCompleted: {
    console.log(">>> Component.onCompleted, current name:", name);
    if (name && name !== "" && !animationInfo.hasAnimation && !initializing) {
      // 延迟检查，让onNameChanged先处理
      Qt.callLater(function() {
        if (!animationInfo.hasAnimation && !initializing && name && name !== "") {
          initializeAnimation();
        }
      });
    }
  }
  
  // ========== 组件销毁清理（防内存泄漏）==========
  Component.onDestruction: {
    currentVideo.stop();
    nextVideo.stop();
    if (pendingInitTimer) {
      pendingInitTimer.stop();
      pendingInitTimer.destroy();
    }
  }
}