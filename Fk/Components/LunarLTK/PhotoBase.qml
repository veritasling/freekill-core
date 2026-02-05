// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects
import QtMultimedia

import Fk
import Fk.Components.Common
import Fk.Components.GameCommon as Game
import Fk.Widgets as W
import Fk.Components.LunarLTK.Photo

Game.BasicItem {
  id: root
  width: 131
  height: 174

  property int playerid: 0
  property string avatar: ""
  property string screenName: ""
  property string general: ""
  property string deputyGeneral: ""
  property string kingdom: "qun"
  property int seatNumber: 1
  property alias skinSource: skin.source
  property alias deputySkinSource: deputySkin.source
  property alias changeSkinTimer: cooldownTimer
  property bool enableChangeSkin: false
  property bool dead: false
  property bool surrendered: false
  property alias photoMask: photoMask

  // 动态皮肤属性（V10.8 无缝切换版）
  property var animationFiles: ({ hasAnimation: false, files: {}, types: {} })
  property string currentAnimationType: "entry"
  property bool isPlayingEntry: false
  property bool entryCooldown: false
  
  // [V10.8] 视频状态追踪
  property string currentVideoSource: ""
  property string nextVideoSource: ""
  property int lastVideoPosition: 0
  property int stuckCheckCount: 0

  // 简化安全路径检查
  function safePath(path) {
    if (!path || path === "") {
      console.log(">>> PhotoBase safePath: empty path");
      return "";
    }
    if (path.endsWith("/") || path.endsWith("\\")) {
      console.log(">>> PhotoBase safePath: blocked directory path:", path);
      return "";
    }
    return path;
  }

  // 检查是否启用了动态包（使用函数静态属性保存结果）
  function checkHasDynamicPack() {
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
    return hasDynamic
  }

  // 视频结束处理函数
  function handleVideoEnded() {
    console.log(">>> PhotoBase handleVideoEnded, current type:", currentAnimationType);
    
    lastVideoPosition = 0;
    stuckCheckCount = 0;
    
    if (currentAnimationType === "entry") {
      isPlayingEntry = false;
      entryCooldown = true;
      entryCooldownTimer.start();
      
      if (specialAnimationTimer.running) {
        specialAnimationTimer.stop();
        specialAnimationTimer.start();
      }
      
      currentAnimationType = "idle";
      loadAnimationForCurrentType();
    } else if (currentAnimationType === "special") {
      specialToIdleTimer.start();
    }
  }

  // [V10.8] 智能视频加载 - 避免重复加载相同视频
  function loadAnimationForCurrentType() {
    console.log(">>> PhotoBase loadAnimationForCurrentType:", currentAnimationType);
    
    if (!animationFiles.hasAnimation) {
      updateAnimationVisibility();
      return;
    }
    
    const rawSource = animationFiles.files[currentAnimationType];
    const source = safePath(rawSource);
    
    if (!source) {
      updateAnimationVisibility();
      return;
    }
    
    updateAnimationVisibility();
    
    const isVideo = animationFiles.types[currentAnimationType] === "video";
    
    if (isVideo) {
      // [V10.8] 决定使用哪个视频槽
      var targetVideo = (currentVideoItem.opacity > 0.5) ? nextVideoItem : currentVideoItem;
      var visibleVideo = (targetVideo === currentVideoItem) ? nextVideoItem : currentVideoItem;
      
      // [V10.8 关键优化] 检查目标视频是否已经加载了相同的源
      if (targetVideo.source === source && targetVideo.playbackState === MediaPlayer.PlayingState) {
        console.log(">>> PhotoBase Video already loaded and playing, reusing");
        // 只需要确保它在正确的透明度
        if (targetVideo.opacity < 0.5) {
          crossfadeAnimation.targetVideo = targetVideo;
          crossfadeAnimation.otherVideo = visibleVideo;
          crossfadeAnimation.start();
        }
        return;
      }
      
      // [V10.8] 如果目标视频正在播放但源不同，先停止
      if (targetVideo.source !== "" && targetVideo.source !== source) {
        targetVideo.stop();
        targetVideo.source = "";
      }
      
      // 设置新源
      targetVideo.source = source;
      targetVideo.opacity = 0; // 开始是隐藏的
      
      // 设置循环
      if (currentAnimationType === "idle") {
        targetVideo.loops = MediaPlayer.Infinite;
      } else {
        targetVideo.loops = 1;
      }
      
      // 隐藏GIF播放器
      gifPlayer.visible = false;
      gifPlayer.playing = false;
      gifPlayer.source = "";
      
      // [V10.8] 关键：先播放，不要停止可见视频！
      console.log(">>> PhotoBase starting video playback:", source);
      targetVideo.play();
      
      // 启动首帧检测
      firstFrameTimer.targetVideo = targetVideo;
      firstFrameTimer.visibleVideo = visibleVideo; // [V10.8] 记住当前可见视频，延迟停止
      firstFrameTimer.start();
    } else {
      // GIF处理
      currentVideoItem.stop();
      nextVideoItem.stop();
      currentVideoItem.opacity = 0;
      nextVideoItem.opacity = 0;
      
      gifPlayer.source = source;
      gifPlayer.visible = true;
      gifPlayer.playing = true;
    }
  }

  // Entry 冷却 Timer
  Timer {
    id: entryCooldownTimer
    interval: 5000
    running: false
    repeat: false
    onTriggered: {
      entryCooldown = false;
      console.log(">>> PhotoBase Entry cooldown ended");
    }
  }

  // 特殊动画播放间隔
  Timer {
    id: specialAnimationTimer
    interval: 8000 + Math.random() * 7000
    running: root.animationFiles.hasAnimation && 
             !root.isPlayingEntry && 
             root.currentAnimationType === "idle" &&
             root.visible &&
             !root.entryCooldown
    repeat: true
    onTriggered: {
      const rand = Math.random();
      if (rand < 0.35 && root.animationFiles.files.special) {
        root.currentAnimationType = "special";
        root.loadAnimationForCurrentType();
      } else if (rand < 0.5 && root.animationFiles.files.entry && !root.entryCooldown) {
        root.currentAnimationType = "entry";
        root.isPlayingEntry = true;
        root.loadAnimationForCurrentType();
      }
    }
  }

  // 特殊动画结束回到待机
  Timer {
    id: specialToIdleTimer
    interval: 300
    running: false
    repeat: false
    onTriggered: {
      if (root.animationFiles.files.idle) {
        root.currentAnimationType = "idle";
        root.loadAnimationForCurrentType();
      } else if (root.animationFiles.files.entry) {
        root.currentAnimationType = "entry";
        root.isPlayingEntry = true;
        root.loadAnimationForCurrentType();
      } else {
        root.animationFiles = { hasAnimation: false, files: {}, types: {} };
        root.updateAnimationVisibility();
      }
    }
  }

  state: "normal"

  Image {
    id: back
    source: SkinBank.getPhotoBack(root.kingdom)
    scale: 0.75
    anchors.centerIn: parent
  }

  Text {
    id: generalName
    x: 5
    y: 21
    font.family: Config.libianName
    font.pixelSize: 16
    opacity: 0.9
    horizontalAlignment: Text.AlignHCenter
    lineHeight: 14
    lineHeightMode: Text.FixedHeight
    color: "white"
    width: 18
    wrapMode: Text.WrapAnywhere
    text: Lua.tr(root.general)
  }

  Item {
    id: generalImgItem
    x: photoMask.x
    y: photoMask.y
    width: photoMask.width
    height: photoMask.height
    visible: true
    clip: true

    Rectangle {
      id: animContainer
      width: deputyGeneral ? parent.width / 2 : parent.width
      height: parent.height
      visible: false
      color: "black"
      clip: true
      z: 10
      
      // [V10.8] 当前显示的视频槽
      Video {
        id: currentVideoItem
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        autoPlay: false
        opacity: 1
        
        onStopped: {
          console.log(">>> Video stopped, type:", root.currentAnimationType, "opacity:", opacity);
          if (opacity > 0.5) {
            if (root.currentAnimationType === "idle") {
              console.log(">>> Idle video stopped unexpectedly, restarting");
              seek(0);
              play();
            } else {
              root.handleVideoEnded();
            }
          }
        }
        
        onErrorOccurred: function(error, errorString) {
          console.error(">>> Video ERROR:", errorString);
          root.animationFiles = { hasAnimation: false, files: {}, types: {} };
          root.updateAnimationVisibility();
        }
        
        // [V10.8] 增强型视频守护
        Timer {
          id: videoGuardian
          interval: 1000
          running: parent.opacity > 0.5 && root.animationFiles.hasAnimation && root.visible
          repeat: true
          onTriggered: {
            // 检查1: 是否停止
            if (parent.playbackState !== MediaPlayer.PlayingState) {
              console.log(">>> Guardian: video not playing, type:", root.currentAnimationType);
              if (root.currentAnimationType === "idle") {
                parent.seek(0);
                parent.play();
              } else if (root.currentAnimationType !== "") {
                root.handleVideoEnded();
              }
              return;
            }
            
            // 检查2: 卡滞检测
            if (parent.playbackState === MediaPlayer.PlayingState) {
              const currentPos = parent.position;
              if (currentPos === root.lastVideoPosition) {
                root.stuckCheckCount++;
                if (root.stuckCheckCount >= 3) {
                  console.error(">>> Guardian: VIDEO STUCK, restarting");
                  if (root.currentAnimationType === "idle") {
                    parent.seek(0);
                    parent.play();
                    root.stuckCheckCount = 0;
                  } else {
                    root.stuckCheckCount = 0;
                    root.handleVideoEnded();
                  }
                }
              } else {
                root.lastVideoPosition = currentPos;
                root.stuckCheckCount = 0;
              }
            }
          }
        }
      }
      
      // [V10.8] 后台预加载视频槽
      Video {
        id: nextVideoItem
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        autoPlay: false
        opacity: 0
        
        onStopped: {
          console.log(">>> NextVideo stopped, type:", root.currentAnimationType, "opacity:", opacity);
          if (opacity > 0.5) {
            if (root.currentAnimationType === "idle") {
              seek(0);
              play();
            } else {
              root.handleVideoEnded();
            }
          }
        }
        
        onErrorOccurred: function(error, errorString) {
          console.error(">>> NextVideo ERROR:", errorString);
        }
        
        Timer {
          id: nextVideoGuardian
          interval: 1000
          running: parent.opacity > 0.5 && root.animationFiles.hasAnimation && root.visible
          repeat: true
          onTriggered: {
            if (parent.playbackState !== MediaPlayer.PlayingState) {
              if (root.currentAnimationType === "idle") {
                parent.seek(0);
                parent.play();
              } else if (root.currentAnimationType !== "") {
                root.handleVideoEnded();
              }
            }
          }
        }
      }
      
      AnimatedImage {
        id: gifPlayer
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: false
        playing: false
        
        onCurrentFrameChanged: {
          if (frameCount > 0 && currentFrame === frameCount - 1) {
            Qt.callLater(function() {
              root.handleVideoEnded();
            });
          }
        }
      }
      
      // [V10.8] 首帧检测 Timer - 关键改进
      Timer {
        id: firstFrameTimer
        property var targetVideo: null
        property var visibleVideo: null // [V10.8] 当前可见的视频（延迟停止）
        property int retryCount: 0
        
        interval: 100 // [V10.8] 缩短检查间隔，更灵敏
        repeat: false
        
        onTriggered: {
          if (!targetVideo) return;
          
          // [V10.8] 更严格的首帧检测：必须正在播放且有时间进度
          const isPlaying = targetVideo.playbackState === MediaPlayer.PlayingState;
          const hasPosition = targetVideo.position > 0;
          const isBuffered = targetVideo.status === MediaPlayer.Buffered;
          
          if ((isPlaying && hasPosition) || isBuffered) {
            console.log(">>> PhotoBase First frame confirmed, pos:", targetVideo.position);
            
            // 重置卡滞检测
            root.lastVideoPosition = targetVideo.position;
            root.stuckCheckCount = 0;
            
            // 执行交叉淡化
            crossfadeAnimation.targetVideo = targetVideo;
            crossfadeAnimation.otherVideo = visibleVideo;
            crossfadeAnimation.start();
            
            // [V10.8] 延迟停止旧视频，避免黑屏
            stopOldVideoTimer.oldVideo = visibleVideo;
            stopOldVideoTimer.start();
            
            retryCount = 0;
          } else if (targetVideo.status === MediaPlayer.Error) {
            console.error(">>> PhotoBase Video load error");
            retryCount = 0;
            root.animationFiles = { hasAnimation: false, files: {}, types: {} };
            root.updateAnimationVisibility();
          } else if (retryCount < 15) { // [V10.8] 增加重试次数（1.5秒）
            retryCount++;
            start(); // 继续等待
          } else {
            // [V10.8] 超时处理：强制显示
            console.warn(">>> PhotoBase First frame timeout, forcing display");
            targetVideo.opacity = 1;
            if (visibleVideo) visibleVideo.opacity = 0;
            retryCount = 0;
          }
        }
      }
      
      // [V10.8 新增] 延迟停止旧视频 Timer
      Timer {
        id: stopOldVideoTimer
        property var oldVideo: null
        interval: 500 // 交叉淡化完成后再等500ms停止
        repeat: false
        onTriggered: {
          if (oldVideo && oldVideo !== crossfadeAnimation.targetVideo) {
            console.log(">>> PhotoBase Stopping old video");
            oldVideo.stop();
            oldVideo.source = "";
          }
        }
      }
      
      ParallelAnimation {
        id: crossfadeAnimation
        property var targetVideo: null
        property var otherVideo: null
        
        NumberAnimation { 
          target: crossfadeAnimation.targetVideo; 
          property: "opacity"; 
          to: 1; 
          duration: 300 
        }
        NumberAnimation { 
          target: crossfadeAnimation.otherVideo; 
          property: "opacity"; 
          to: 0; 
          duration: 300 
        }
        
        onStopped: {
          console.log(">>> PhotoBase Crossfade completed");
        }
      }
    }

    Image {
      id: generalImage
      width: deputyGeneral ? parent.width / 2 : parent.width
      height: parent.height
      smooth: true
      fillMode: Image.PreserveAspectCrop
      visible: true
      z: 5
      
      source: {
        if (general === "") return "";
        if (deputyGeneral) {
          return SkinBank.getGeneralExtraPic(general, "dual/")
              ?? SkinBank.getGeneralPicture(general);
        } else {
          return SkinBank.getGeneralPicture(general);
        }
      }

      onSourceChanged: {
        if (playerid === roomScene.dashboardId) {
          const changed_source = root.getConfigSkin(root.general);
          if (changed_source !== "") {
            Cpp.notifyServer("PushRequest", "changeskin," + changed_source);
          }
        }
      }
    }

    SkinArea {
      id: skin
      width: deputyGeneral ? parent.width / 2 : parent.width
      height: parent.height
      hasDeputy: !!deputyGeneral
    }

    Image {
      id: deputyGeneralImage
      anchors.left: generalImage.right
      width: parent.width / 2
      height: parent.height
      smooth: true
      fillMode: Image.PreserveAspectCrop
      source: {
        if (deputyGeneral != "") {
          return SkinBank.getGeneralExtraPic(deputyGeneral, "dual/")
              ?? SkinBank.getGeneralPicture(deputyGeneral);
        } else {
          return "";
        }
      }

      onSourceChanged: {
        if (playerid === roomScene.dashboardId) {
          const changed_source = root.getConfigSkin(root.deputyGeneral);
          if (changed_source !== "") {
            Cpp.notifyServer("PushRequest", "changeskin,," + changed_source);
          }
        }
      }
    }

    SkinArea {
      id: deputySkin
      anchors.left: generalImage.right
      width: parent.width / 2
      height: parent.height
      hasDeputy: !!deputyGeneral
    }

    Image {
      id: deputySplit
      source: SkinBank.photoDir + "deputy-split"
      opacity: deputyGeneral ? 1 : 0
      scale: 0.75
      anchors.centerIn: parent
    }

    Text {
      id: deputyGeneralName
      anchors.left: generalImage.right
      anchors.leftMargin: -10
      y: 21
      font.family: Config.libianName
      font.pixelSize: 16
      opacity: 0.9
      horizontalAlignment: Text.AlignHCenter
      lineHeight: 14
      lineHeightMode: Text.FixedHeight
      color: "white"
      width: 18
      wrapMode: Text.WrapAnywhere
      text: Lua.tr(root.deputyGeneral)
      style: Text.Outline
    }
  }

  Rectangle {
    id: photoMask
    x: 31 * 0.75
    y: 5 * 0.75
    width: 103
    height: 166
    radius: 6
    visible: false
  }

  OpacityMask {
    id: photoMaskEffect
    anchors.fill: photoMask
    source: generalImgItem
    maskSource: photoMask
  }

  Colorize {
    anchors.fill: photoMaskEffect
    source: photoMaskEffect
    saturation: 0
    opacity: (root.dead || root.surrendered) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 300 } }
  }

  Behavior on x {
    NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
  }

  Behavior on y {
    NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
  }

  GlowText {
    id: playerName
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 2
    width: parent.width
    font.pixelSize: 12
    text: {
      let ret = screenName;
      if (Config.blockedUsers?.includes(screenName))
        ret = Lua.tr("<Blocked> ") + ret;
      return ret;
    }
    elide: root.playerid === Self.id ? Text.ElideNone : Text.ElideMiddle
    horizontalAlignment: Qt.AlignHCenter
    glow.radius: 6
  }

  Game.ChatBubble {
    id: chat
    width: parent.width
    z: 9
  }

  Image {
    id: skinIcon
    width: 22
    height: 22
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 10
    anchors.topMargin: 100
    source: "https://images.icon-icons.com/1526/PNG/512/dress_106586.png      "
    visible: false

    W.TapHandler {
      onTapped: {
        roomScene.startCheat("SkinsDetail", {
          skins: root.getSkinsByName(root.general),
          deputy_skins: root.getSkinsByName(root.deputyGeneral),
          orig_general: root.general,
          orig_deputy: root.deputyGeneral,
        });
      }
    }

    HoverHandler {
      cursorShape: Qt.PointingHandCursor
    }

    Timer {
      id: cooldownTimer
      interval: 5000
      running: false
    }
  }

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (hovered && root.enableChangeSkin && !Config.observing && !cooldownTimer.running && (root.getSkinsByName(root.general).length > 0 || root.getSkinsByName(root.deputyGeneral).length > 0)) {
        skinIcon.visible = true;
      } else {
        skinIcon.visible = false;
      }
    }
  }

  // 初始化动态皮肤
  function initializeAnimation() {
    console.log(">>> PhotoBase initializeAnimation:", general)
    
    lastVideoPosition = 0;
    stuckCheckCount = 0;
    
    if (!general || general === "") {
      animationFiles = { hasAnimation: false, files: {}, types: {} }
      updateAnimationVisibility()
      return
    }
    
    if (!checkHasDynamicPack()) {
      animationFiles = { hasAnimation: false, files: {}, types: {} }
      updateAnimationVisibility()
      return
    }
    
    if (!initializeAnimation.cache) {
      initializeAnimation.cache = {}
    }
    
    if (initializeAnimation.cache[general] !== undefined) {
      console.log(">>> PhotoBase global cache hit:", general)
      const cached = initializeAnimation.cache[general]
      animationFiles = cached
      
      if (cached.hasAnimation && cached.files) {
        currentAnimationType = cached.files.entry ? "entry" : "idle"
        isPlayingEntry = !!cached.files.entry
        updateAnimationVisibility()
        Qt.callLater(function() {
          loadAnimationForCurrentType()
        })
      } else {
        updateAnimationVisibility()
      }
      return
    }
    
    Qt.callLater(function() {
      try {
        const result = SkinBank.getGeneralAnimationFiles(general)
        console.log(">>> PhotoBase SkinBank result:", JSON.stringify(result))
        
        const processedResult = result || { hasAnimation: false, files: {}, types: {} }
        initializeAnimation.cache[general] = processedResult
        animationFiles = processedResult
        
        if (processedResult.hasAnimation) {
          currentAnimationType = processedResult.files.entry ? "entry" : "idle"
          isPlayingEntry = !!processedResult.files.entry
          updateAnimationVisibility()
          Qt.callLater(function() {
            loadAnimationForCurrentType()
          })
        } else {
          updateAnimationVisibility()
        }
      } catch (e) {
        console.error(">>> PhotoBase Error calling SkinBank:", e)
        const fallback = { hasAnimation: false, files: {}, types: {} }
        animationFiles = fallback
        initializeAnimation.cache[general] = fallback
        updateAnimationVisibility()
      }
    })
  }

  // 统一更新可见性状态
  function updateAnimationVisibility() {
    const hasAnim = root.animationFiles.hasAnimation && 
                    !!root.animationFiles.files[root.currentAnimationType];
    
    animContainer.visible = hasAnim;
    generalImage.visible = !hasAnim;
    
    console.log(">>> PhotoBase updateVisibility: animContainer=", hasAnim, 
                "generalImage=", !hasAnim, "type=", root.currentAnimationType);
  }

  Component.onCompleted: {
    console.log(">>> PhotoBase onCompleted, general:", general);
    if (general !== "") {
      initializeAnimation();
    }
  }

  onGeneralChanged: {
    console.log(">>> PhotoBase onGeneralChanged:", general);
    lastVideoPosition = 0;
    stuckCheckCount = 0;
    
    // [V10.8] 清理旧视频状态
    currentVideoItem.stop();
    nextVideoItem.stop();
    currentVideoItem.source = "";
    nextVideoItem.source = "";
    currentVideoItem.opacity = 0;
    nextVideoItem.opacity = 0;
    
    if (general !== "") {
      Qt.callLater(function() {
        initializeAnimation();
      });
    } else {
      animationFiles = { hasAnimation: false, files: {}, types: {} };
      updateAnimationVisibility();
    }
  }

  function chat(msg) {
    chat.text = msg;
    chat.visible = true;
    chat.show();
  }

  function getSkinsByName(general) {
    let arr = Lua.evaluate(`(function()
      return Fk:getSkinsByGeneral("${general}") or {}
    end)()`);
    return arr;
  }

  function getConfigSkin(general) {
    const enabledSkins = Config.enabledSkins ?? {};
    if (enabledSkins[general] !== undefined) {
      return enabledSkins[general];
    }
    return "";
  }
}