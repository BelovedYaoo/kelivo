import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/models/chat_message.dart';

// ============================================================================
// Auto-follow ScrollController / ScrollPosition
// ============================================================================

/// ScrollController whose positions auto-pin to maxScrollExtent during layout.
///
/// When [shouldAutoFollow] returns true, the created [ScrollPosition] corrects
/// its pixel value to maxScrollExtent inside [applyContentDimensions] — i.e.
/// BEFORE paint — so there is zero visual lag between content growth and scroll
/// position update. This eliminates the 1-frame flicker that post-frame
/// `jumpTo(max)` cannot avoid.
class ChatAutoFollowScrollController extends ScrollController {
  /// Callback checked during layout to decide whether to auto-follow bottom.
  bool Function() shouldAutoFollow = () => false;

  /// 打开会话窗口时使用的单帧定位请求。
  ///
  /// 与帧后的 `jumpTo` 不同，该请求会在新列表布局过程中由滚动位置消费，
  /// 因而不会为新会话绘制旧会话偏移。
  bool _positionAtBottomDuringLayout = false;
  int _layoutBottomRequest = 0;
  bool _preserveDistanceFromEndDuringLayout = false;
  double _preservedDistanceFromEnd = 0;
  int _layoutDistanceRequest = 0;

  int requestPositionAtBottomDuringLayout() {
    _positionAtBottomDuringLayout = true;
    return ++_layoutBottomRequest;
  }

  void finishPositionAtBottomDuringLayout(int request) {
    if (request == _layoutBottomRequest) {
      _positionAtBottomDuringLayout = false;
    }
  }

  int? requestPreserveDistanceFromEndDuringLayout() {
    if (!hasClients || positions.length != 1) return null;
    final position = this.position;
    _preservedDistanceFromEnd = position.maxScrollExtent - position.pixels;
    _preserveDistanceFromEndDuringLayout = true;
    return ++_layoutDistanceRequest;
  }

  void finishPreserveDistanceFromEndDuringLayout(int request) {
    if (request == _layoutDistanceRequest) {
      _preserveDistanceFromEndDuringLayout = false;
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _AutoFollowScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      controller: this,
    );
  }
}

class _AutoFollowScrollPosition extends ScrollPositionWithSingleContext {
  _AutoFollowScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.controller,
  });

  final ChatAutoFollowScrollController controller;

  _IndexedScrollActivity beginIndexedAnimation(VoidCallback onCanceled) {
    final indexedActivity = _IndexedScrollActivity(this, onCanceled);
    beginActivity(indexedActivity);
    return indexedActivity;
  }

  bool updateIndexedAnimation(
    _IndexedScrollActivity indexedActivity,
    double value,
  ) {
    if (!identical(activity, indexedActivity)) return false;
    setPixels(value.clamp(minScrollExtent, maxScrollExtent));
    return true;
  }

  void finishIndexedAnimation(_IndexedScrollActivity indexedActivity) {
    if (identical(activity, indexedActivity)) indexedActivity.finish();
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final result = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    // Also guard on userScrollDirection here in the layout phase, because it
    // updates immediately via the scroll activity — earlier than the scroll-
    // controller listener that sets _isUserScrolling.  Without this check,
    // correctPixels would override the user's drag for one frame, causing a
    // "stuck / can't scroll up" feeling.
    final shouldPositionAtBottom =
        controller._positionAtBottomDuringLayout ||
        (controller.shouldAutoFollow() &&
            userScrollDirection == ScrollDirection.idle);
    if (shouldPositionAtBottom) {
      final gap = this.maxScrollExtent - pixels;
      if (gap > 0.5) {
        correctPixels(this.maxScrollExtent);
        return false; // Force viewport re-layout with corrected position
      }
    }
    if (controller._preserveDistanceFromEndDuringLayout &&
        userScrollDirection == ScrollDirection.idle) {
      final target =
          (this.maxScrollExtent - controller._preservedDistanceFromEnd).clamp(
            this.minScrollExtent,
            this.maxScrollExtent,
          );
      if ((target - pixels).abs() > 0.5) {
        correctPixels(target);
        return false;
      }
    }
    return result;
  }
}

/// 面向索引目标的单次连续滚动活动；目标进入 SuperListView 缓存区时，
/// 测得的偏移仍可能变化。
class _IndexedScrollActivity extends ScrollActivity {
  _IndexedScrollActivity(super.delegate, this._onCanceled);

  final VoidCallback _onCanceled;
  bool _finishing = false;

  void finish() {
    if (_finishing) return;
    _finishing = true;
    delegate.goIdle();
  }

  @override
  bool get shouldIgnorePointer => true;

  @override
  bool get isScrolling => true;

  @override
  double get velocity => 0;

  @override
  void dispose() {
    if (!_finishing) _onCanceled();
    super.dispose();
  }
}

// ============================================================================
// ChatScrollController
// ============================================================================

/// Controller for managing scroll behavior in the chat home page.
///
/// This controller handles:
/// - Auto-scroll to bottom during streaming (zero-lag via custom ScrollPosition)
/// - 跳转到相邻消息
/// - 通过可变尺寸索引滚动到指定消息 ID
/// - Scroll state monitoring (user scrolling detection)
/// - Visibility state for navigation buttons
class ChatScrollController {
  ChatScrollController({
    required this._scrollController,
    required this._onStateChanged,
    required this._getAutoScrollEnabled,
    required this._getAutoScrollIdleSeconds,
    this._getTopRevealInset,
    this.isGenerating,
  }) {
    final scrollController = _scrollController;
    _messageListController = ListController(
      onDetached: _cancelIndexedNavigationForDetach,
    );
    _scrollController.addListener(_onScrollControllerChanged);

    // Wire auto-follow callback for zero-lag bottom pinning
    if (scrollController is ChatAutoFollowScrollController) {
      scrollController.shouldAutoFollow = () =>
          _getAutoScrollEnabled() &&
          (isGenerating?.call() ?? false) &&
          _autoStickToBottom &&
          !_isUserScrolling &&
          !_explicitBottomAnimationInProgress;
    }
  }

  final ScrollController _scrollController;
  final VoidCallback _onStateChanged;
  final bool Function() _getAutoScrollEnabled;
  final int Function() _getAutoScrollIdleSeconds;
  final double Function()? _getTopRevealInset;
  final bool Function()? isGenerating;

  /// 与消息列表共享的索引和尺寸状态。
  late final ListController _messageListController;

  // ============================================================================
  // State Fields
  // ============================================================================

  /// Whether to show the jump-to-bottom button.
  bool _showJumpToBottom = false;
  bool get showJumpToBottom => _showJumpToBottom;

  /// Whether the navigation buttons should be visible (based on scroll activity).
  bool _showNavButtons = false;
  bool get showNavButtons => _showNavButtons;

  /// Timer for auto-hiding navigation buttons.
  Timer? _navButtonsHideTimer;
  static const int _navButtonsHideDelayMs = 2000;

  /// Whether the user is actively scrolling.
  bool _isUserScrolling = false;
  bool get isUserScrolling => _isUserScrolling;

  /// Whether auto-scroll should stick to bottom.
  bool _autoStickToBottom = true;
  bool get autoStickToBottom => _autoStickToBottom;

  /// Timer for detecting end of user scroll.
  Timer? _userScrollTimer;

  /// 当前排队等待下一帧滚动到底部的请求。
  int? _scheduledBottomScrollRequest;

  /// 驱动滚动与布局阶段的尾部固定不能在同一帧拥有像素控制权。
  bool _explicitBottomAnimationInProgress = false;
  bool get explicitBottomAnimationInProgress =>
      _explicitBottomAnimationInProgress;
  int _bottomScrollRequest = 0;
  int _deferredBottomRequest = 0;
  int _indexedNavigationRequest = 0;
  AnimationController? _indexedAnimationController;
  _IndexedScrollActivity? _indexedScrollActivity;

  /// 连续相邻消息导航使用的锚点。
  String? _lastJumpUserMessageId;
  String? get lastJumpUserMessageId => _lastJumpUserMessageId;

  /// Tolerance for "near bottom" detection.
  static const double _autoScrollSnapTolerance = 56.0;

  // ============================================================================
  // Public Getters
  // ============================================================================

  /// Get the underlying scroll controller.
  ScrollController get scrollController => _scrollController;

  /// 获取附加到消息列表的索引控制器。
  ListController get messageListController => _messageListController;

  /// Check if scroll controller has clients attached.
  bool get hasClients => _scrollController.hasClients;

  // ============================================================================
  // Scroll State Detection
  // ============================================================================

  /// Check if the scroll position is near the bottom.
  bool isNearBottom([double tolerance = _autoScrollSnapTolerance]) {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return (pos.maxScrollExtent - pos.pixels) <= tolerance;
  }

  /// 当视口收缩（例如软键盘打开）时，
  /// 让已与底部对齐的移动端时间线继续固定在底部。
  ///
  /// 必须在新视口尺寸开始布局前发出请求，
  /// 否则旧像素偏移会在新底部上方多绘制一帧。
  bool pinBottomDuringViewportResizeIfNeeded() {
    if (!isNearBottom(24)) return false;
    positionAtBottomOnNextLayout();
    return true;
  }

  /// Check if the scroll view has enough content to scroll.
  ///
  /// [minExtent] - Minimum scroll extent to consider scrollable (default: 56.0).
  bool hasEnoughContentToScroll([double minExtent = 56.0]) {
    if (!_scrollController.hasClients) return false;
    return _scrollController.position.maxScrollExtent >= minExtent;
  }

  /// Refresh auto-stick-to-bottom state based on current position.
  void refreshAutoStickToBottom() {
    try {
      final nearBottom = isNearBottom();
      if (!nearBottom) {
        _autoStickToBottom = false;
      } else if (!_isUserScrolling) {
        final enabled = _getAutoScrollEnabled();
        if (enabled || _autoStickToBottom) {
          _autoStickToBottom = true;
        }
      }
    } catch (_) {}
  }

  /// Handle scroll controller changes (called from scroll listener).
  void _onScrollControllerChanged() {
    try {
      if (!_scrollController.hasClients) return;
      final autoScrollEnabled = _getAutoScrollEnabled();

      // Only show when not near bottom
      final atBottom = isNearBottom(24);
      if (!atBottom) {
        _autoStickToBottom = false;
      } else if (_isUserScrolling) {
        // User actively scrolled back to bottom → re-engage auto-follow
        // immediately so streaming content keeps pinning without waiting
        // for the idle timer.
        _isUserScrolling = false;
        _userScrollTimer?.cancel();
        _autoStickToBottom = true;
      } else if (autoScrollEnabled || _autoStickToBottom) {
        _autoStickToBottom = true;
      }
      final shouldShow = !atBottom;
      if (_showJumpToBottom != shouldShow) {
        _showJumpToBottom = shouldShow;
        _onStateChanged();
      }
    } catch (_) {}
  }

  /// 记录来自真实指针、滚轮或键盘输入的滚动意图。
  /// 程序化位置变化绝不能调用此方法。
  void handleUserScrollIntent() {
    _cancelProgrammaticNavigation();
    _isUserScrolling = true;
    _autoStickToBottom = false;
    _lastJumpUserMessageId = null;
    if (!_showNavButtons) {
      _showNavButtons = true;
      _onStateChanged();
    }
    _resetNavButtonsHideTimer();
    _userScrollTimer?.cancel();
    final secs = _getAutoScrollIdleSeconds();
    _userScrollTimer = Timer(Duration(seconds: secs), () {
      _isUserScrolling = false;
      refreshAutoStickToBottom();
      _onStateChanged();
    });
  }

  /// Reset the auto-hide timer for navigation buttons.
  void _resetNavButtonsHideTimer() {
    _navButtonsHideTimer?.cancel();
    _navButtonsHideTimer = Timer(
      const Duration(milliseconds: _navButtonsHideDelayMs),
      () {
        if (_showNavButtons) {
          _showNavButtons = false;
          _onStateChanged();
        }
      },
    );
  }

  /// Show navigation buttons manually (e.g., when user taps a button).
  void revealNavButtons() {
    if (!_showNavButtons) {
      _showNavButtons = true;
      _onStateChanged();
    }
    _resetNavButtonsHideTimer();
  }

  /// Hide navigation buttons immediately.
  void hideNavButtons() {
    _navButtonsHideTimer?.cancel();
    if (_showNavButtons) {
      _showNavButtons = false;
      _onStateChanged();
    }
  }

  // ============================================================================
  // Scroll To Bottom Methods
  // ============================================================================

  /// 在下一次绘制前将新打开的会话定位到尾部。
  ///
  /// RikkaHub 使用等价的 `requestScrollToItem` 操作：初始位置直接参与布局，
  /// 而不是在可见帧出现后再纠正。该标记会在整帧内保持有效，
  /// 因为懒加载视口可能在布局期间多次修正最大范围。
  void positionAtBottomOnNextLayout() {
    _cancelProgrammaticNavigation(stopDrivenScroll: true);
    _lastJumpUserMessageId = null;
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    _autoStickToBottom = true;
    final controller = _scrollController;
    if (controller is! ChatAutoFollowScrollController) {
      _scheduleExplicitScrollToBottom(animate: false);
      return;
    }
    final request = controller.requestPositionAtBottomDuringLayout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.finishPositionAtBottomDuringLayout(request);
    });
  }

  /// 在显示已切换会话前解析真实的索引尾部。
  ///
  /// 懒加载列表首次得到的 maxScrollExtent 仍可能基于条目高度估算。
  /// RikkaHub 不会把该估算值当作目标，而是直接请求最后一个条目；
  /// 这等价于索引定位，并等待尾部范围成为确定值。
  Future<void> settleAtBottomBeforeReveal() async {
    _cancelProgrammaticNavigation(stopDrivenScroll: true);
    _lastJumpUserMessageId = null;
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    _autoStickToBottom = true;

    for (var pass = 0; pass < 3; pass++) {
      if (_scrollController.hasClients && _messageListController.isAttached) {
        break;
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!_scrollController.hasClients) return;

    final request = ++_bottomScrollRequest;
    await _animateToBottom(animate: false, request: request);
  }

  /// Scroll to the bottom of the list.
  ///
  /// [animate] - Whether to animate the scroll (default: true).
  void scrollToBottom({bool animate = true}) {
    _autoStickToBottom = true;
    final generating = isGenerating?.call() ?? false;
    _scheduleExplicitScrollToBottom(animate: animate && !generating);
  }

  /// Force scroll to bottom (used when user explicitly clicks the button).
  void forceScrollToBottom({bool animate = true}) {
    _cancelProgrammaticNavigation(stopDrivenScroll: true);
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    _lastJumpUserMessageId = null;
    revealNavButtons();
    scrollToBottom(animate: animate);
  }

  /// Force scroll after rebuilds when switching topics/conversations.
  void forceScrollToBottomSoon({
    bool animate = true,
    Duration postSwitchDelay = const Duration(milliseconds: 220),
  }) {
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    final request = ++_deferredBottomRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (request == _deferredBottomRequest) {
        scrollToBottom(animate: animate);
      }
    });
    Future.delayed(postSwitchDelay, () {
      if (request == _deferredBottomRequest) {
        scrollToBottom(animate: animate);
      }
    });
  }

  /// Ensure scroll reaches bottom even after widget tree transitions.
  void scrollToBottomSoon({bool animate = true}) {
    final request = ++_deferredBottomRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (request == _deferredBottomRequest) {
        scrollToBottom(animate: animate);
      }
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (request == _deferredBottomRequest) {
        scrollToBottom(animate: animate);
      }
    });
  }

  /// Auto-scroll to bottom if conditions are met (called from onStreamTick).
  ///
  /// With [ChatAutoFollowScrollController], the custom [ScrollPosition] handles
  /// bottom-pinning during layout automatically. This method is kept as a
  /// lightweight safety-net for edge cases (e.g. plain ScrollController).
  void autoScrollToBottomIfNeeded() {
    final enabled = _getAutoScrollEnabled();
    if (!enabled || !_autoStickToBottom) return;
    // With the custom ScrollPosition, bottom-pinning happens inside
    // applyContentDimensions (during layout, before paint). No post-frame
    // callback needed for the streaming path.
    // Only schedule an explicit jump as fallback for plain ScrollControllers.
    if (_scrollController is! ChatAutoFollowScrollController) {
      _scheduleExplicitScrollToBottom(animate: false);
    }
  }

  /// Schedule an explicit scroll to bottom (batched via post-frame callback).
  ///
  /// Used for user-triggered "go to bottom" and as fallback for streaming
  /// auto-scroll when the custom [ScrollPosition] is not available.
  void _scheduleExplicitScrollToBottom({bool animate = true}) {
    final request = ++_bottomScrollRequest;
    _scheduledBottomScrollRequest = request;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_scheduledBottomScrollRequest == request) {
        _scheduledBottomScrollRequest = null;
      }
      if (request != _bottomScrollRequest) return;
      await _animateToBottom(animate: animate, request: request);
    });
  }

  /// Animate or jump to the bottom of the scroll view.
  ///
  /// Used for explicit scroll-to-bottom requests (user-triggered button,
  /// conversation switch, etc.). Streaming auto-scroll is handled by the
  /// custom [ScrollPosition] instead.
  Future<void> _animateToBottom({
    bool animate = true,
    required int request,
  }) async {
    try {
      if (request != _bottomScrollRequest || !_scrollController.hasClients) {
        return;
      }
      _explicitBottomAnimationInProgress = false;

      // 控制器仍同时附加到旧会话和新会话时不得使用。
      // 保持此步骤可等待，以便在揭示界面前完成稳定。
      if (_scrollController.positions.length != 1) {
        await WidgetsBinding.instance.endOfFrame;
        if (request != _bottomScrollRequest ||
            _scrollController.positions.length != 1) {
          return;
        }
      }
      final pos = _scrollController.position;
      final hasIndexedTail =
          _messageListController.isAttached &&
          _messageListController.numberOfItems > 0;
      if (hasIndexedTail) {
        // 即使 [animate] 为 true，索引尾部解析也会有意直接跳转。
        // 若向懒加载估算偏移执行动画，就会在测得真实末项尺寸时
        // 产生可见修正。该参数只控制下方普通 ScrollController 回退。
        final lastIndex = _messageListController.numberOfItems - 1;
        for (var pass = 0; pass < 4; pass++) {
          if (request != _bottomScrollRequest ||
              !_scrollController.hasClients ||
              !_messageListController.isAttached ||
              lastIndex >= _messageListController.numberOfItems) {
            return;
          }
          _messageListController.jumpToItem(
            index: lastIndex,
            scrollController: _scrollController,
            alignment: 1,
          );
          await WidgetsBinding.instance.endOfFrame;
          if (request != _bottomScrollRequest) return;
          final visible = _messageListController.visibleRange;
          final extentIsEstimated = _messageListController
              .extentForIndex(lastIndex)
              .$2;
          if (!extentIsEstimated &&
              visible != null &&
              visible.$1 <= lastIndex &&
              visible.$2 >= lastIndex &&
              pass > 0) {
            break;
          }
        }
        if (request != _bottomScrollRequest) return;
        final tailPosition = _scrollController.position;
        if (tailPosition.maxScrollExtent - tailPosition.pixels > 0.5) {
          tailPosition.jumpTo(tailPosition.maxScrollExtent);
          await WidgetsBinding.instance.endOfFrame;
        }
        if (request != _bottomScrollRequest) return;
        _updateJumpToBottomVisibility(false);
        _autoStickToBottom = true;
        return;
      }

      final start = pos.pixels;
      final target = pos.maxScrollExtent;
      final distance = (target - start).abs();
      final animateNearby = animate && distance >= 0.5;

      if (animateNearby) {
        final durationMs = distance < 500
            ? 250
            : distance < 2000
            ? 350
            : 450;
        pos.jumpTo(start.clamp(pos.minScrollExtent, pos.maxScrollExtent));
        _explicitBottomAnimationInProgress = true;
        try {
          await pos.animateTo(
            target.clamp(pos.minScrollExtent, pos.maxScrollExtent),
            duration: Duration(milliseconds: durationMs),
            curve: Curves.easeOutCubic,
          );
        } finally {
          if (request == _bottomScrollRequest) {
            _explicitBottomAnimationInProgress = false;
          }
        }
      } else if (distance >= 0.5) {
        pos.jumpTo(target);
      }

      if (request != _bottomScrollRequest) return;
      _updateJumpToBottomVisibility(false);
      _autoStickToBottom = true;
    } catch (_) {}
  }

  void _updateJumpToBottomVisibility(bool show) {
    if (_showJumpToBottom != show) {
      _showJumpToBottom = show;
      _onStateChanged();
    }
  }

  // ============================================================================
  // Navigation Methods
  // ============================================================================

  double _currentTopRevealInset() {
    final inset = _getTopRevealInset?.call() ?? 0.0;
    if (!inset.isFinite || inset <= 0) return 0;
    if (!_scrollController.hasClients) return inset;
    return inset
        .clamp(0.0, _scrollController.position.viewportDimension)
        .toDouble();
  }

  double _messageRevealOffset(int index, double alignment) {
    // 与 jumpToItem 内部使用相同的偏移查询。
    // ignore: invalid_use_of_visible_for_testing_member
    final rawOffset = _messageListController.getOffsetToReveal(
      index,
      alignment,
    );
    final normalizedAlignment = alignment.clamp(0.0, 1.0).toDouble();
    return rawOffset - _currentTopRevealInset() * (1.0 - normalizedAlignment);
  }

  void _correctMessageReveal(int index, double alignment) {
    if (!_scrollController.hasClients ||
        !_messageListController.isAttached ||
        index < 0 ||
        index >= _messageListController.numberOfItems) {
      return;
    }
    final position = _scrollController.position;
    final target = _messageRevealOffset(
      index,
      alignment,
    ).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
    if ((position.pixels - target).abs() > 0.5) {
      position.jumpTo(target);
    }
  }

  int? _firstVisibleMessageBelowTopOverlay() {
    if (!_scrollController.hasClients || !_messageListController.isAttached) {
      return null;
    }
    final visible = _messageListController.visibleRange;
    if (visible == null) return null;
    final topBoundary =
        _scrollController.position.pixels + _currentTopRevealInset();
    for (var index = visible.$1; index <= visible.$2; index++) {
      if (index < 0 || index >= _messageListController.numberOfItems) continue;
      // ignore: invalid_use_of_visible_for_testing_member
      final leading = _messageListController.getOffsetToReveal(index, 0);
      final extent = _messageListController.extentForIndex(index).$1;
      if (leading + extent > topBoundary + 0.5) return index;
    }
    return visible.$2;
  }

  /// Scroll to the top of the list.
  void scrollToTop({bool animate = true}) {
    try {
      if (!_scrollController.hasClients) return;
      _cancelProgrammaticNavigation(stopDrivenScroll: true);
      _lastJumpUserMessageId = null;
      revealNavButtons();

      if (animate) {
        final pos = _scrollController.position;
        final distance = pos.pixels;
        final durationMs = distance < 200
            ? 150
            : distance < 800
            ? 220
            : 300;
        pos.animateTo(
          0.0,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(0.0);
      }
    } catch (_) {}
  }

  /// 跳转到当前索引锚点之前紧邻的消息。
  Future<bool> jumpToPreviousQuestion({
    required List<ChatMessage> messages,
    required int Function(String id) indexOfId,
  }) async {
    if (!_scrollController.hasClients || !_messageListController.isAttached) {
      return false;
    }
    if (messages.isEmpty) return false;

    revealNavButtons();

    final cursorIndex = _lastJumpUserMessageId == null
        ? -1
        : indexOfId(_lastJumpUserMessageId!);
    final anchor = cursorIndex >= 0
        ? cursorIndex
        : (_firstVisibleMessageBelowTopOverlay() ?? messages.length - 1);

    final target = anchor - 1;
    if (target < 0) {
      _lastJumpUserMessageId = null;
      return false;
    }

    _lastJumpUserMessageId = messages[target].id;
    await _animateToMessageIndex(index: target, alignment: 0);
    return true;
  }

  /// 跳转到当前索引锚点之后紧邻的消息。
  Future<bool> jumpToNextQuestion({
    required List<ChatMessage> messages,
    required int Function(String id) indexOfId,
  }) async {
    if (!_scrollController.hasClients || !_messageListController.isAttached) {
      return false;
    }
    if (messages.isEmpty) return false;

    revealNavButtons();

    final cursorIndex = _lastJumpUserMessageId == null
        ? -1
        : indexOfId(_lastJumpUserMessageId!);
    final anchor = cursorIndex >= 0
        ? cursorIndex
        : (_firstVisibleMessageBelowTopOverlay() ?? 0);

    final target = anchor + 1;
    if (target >= messages.length) {
      _lastJumpUserMessageId = null;
      return false;
    }

    _lastJumpUserMessageId = messages[target].id;
    await _animateToMessageIndex(index: target, alignment: 0);
    return true;
  }

  /// Scroll to a specific message by index (from mini map or search).
  ///
  /// 直接索引定位对应 RikkaHub 的 `scrollToItem`：远距离目标
  /// 无需构建或逐条播放所有中间消息的动画。
  Future<void> scrollToMessageId({
    required String targetId,
    required int targetIndex,
  }) async {
    try {
      if (!_scrollController.hasClients || !_messageListController.isAttached) {
        return;
      }
      if (targetIndex < 0) return;
      if (targetIndex >= _messageListController.numberOfItems) return;
      _cancelProgrammaticNavigation(stopDrivenScroll: true);
      final request = ++_indexedNavigationRequest;
      _messageListController.jumpToItem(
        index: targetIndex,
        scrollController: _scrollController,
        alignment: 0,
      );
      _correctMessageReveal(targetIndex, 0);
      for (var pass = 0; pass < 3; pass++) {
        await WidgetsBinding.instance.endOfFrame;
        if (request != _indexedNavigationRequest ||
            !_scrollController.hasClients ||
            !_messageListController.isAttached ||
            targetIndex >= _messageListController.numberOfItems) {
          return;
        }
        _correctMessageReveal(targetIndex, 0);
        final estimated = _messageListController.extentForIndex(targetIndex).$2;
        if (!estimated && pass > 0) break;
      }
      _lastJumpUserMessageId = targetId;
    } catch (_) {}
  }

  Future<void> _animateToMessageIndex({
    required int index,
    required double alignment,
  }) async {
    if (!_scrollController.hasClients ||
        !_messageListController.isAttached ||
        index < 0 ||
        index >= _messageListController.numberOfItems) {
      return;
    }
    _cancelProgrammaticNavigation(stopDrivenScroll: true);
    _autoStickToBottom = false;
    final request = ++_indexedNavigationRequest;
    final position = _scrollController.position;
    final estimatedDistance =
        (_messageRevealOffset(index, alignment) - position.pixels).abs();
    final duration = estimatedDistance < 320
        ? const Duration(milliseconds: 220)
        : estimatedDistance < 1000
        ? const Duration(milliseconds: 280)
        : const Duration(milliseconds: 360);
    final animationController = AnimationController(
      vsync: position.context.vsync,
      duration: duration,
    );
    _indexedAnimationController = animationController;
    _IndexedScrollActivity? indexedActivity;
    if (position is _AutoFollowScrollPosition) {
      late final _IndexedScrollActivity startedActivity;
      startedActivity = position.beginIndexedAnimation(
        () => _cancelIndexedAnimationFromActivity(startedActivity),
      );
      indexedActivity = startedActivity;
      _indexedScrollActivity = startedActivity;
    }
    final animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOutCubic,
    );
    var previousProgress = 0.0;
    bool movePosition(double value) {
      final activity = indexedActivity;
      if (position is _AutoFollowScrollPosition && activity != null) {
        return position.updateIndexedAnimation(activity, value);
      }
      position.jumpTo(value);
      position.isScrollingNotifier.value = true;
      return true;
    }

    void updatePosition() {
      if (request != _indexedNavigationRequest ||
          !_scrollController.hasClients ||
          !_messageListController.isAttached ||
          index >= _messageListController.numberOfItems) {
        animationController.stop(canceled: false);
        return;
      }

      // 目标进入缓存区时，SuperListView 可能用真实范围替换估算范围。
      // 每个 tick 重新读取索引偏移，让修正被这一次连续动画吸收，
      // 避免动画结束后出现可见跳变。
      final target = _messageRevealOffset(
        index,
        alignment,
      ).clamp(position.minScrollExtent, position.maxScrollExtent);
      final progress = animation.value;
      final remainingProgress = 1.0 - previousProgress;
      final stepProgress = remainingProgress <= 0.0001
          ? 1.0
          : ((progress - previousProgress) / remainingProgress).clamp(0.0, 1.0);
      // 仅在剩余进度内从当前像素位置插值。若懒加载范围发生变化，
      // 修正会分散到动画剩余阶段，而不是在一帧内将全部已用进度
      // 应用到新目标。
      final next = position.pixels + (target - position.pixels) * stepProgress;
      previousProgress = progress;
      if ((next - position.pixels).abs() > 0.01) {
        if (!movePosition(next)) {
          animationController.stop(canceled: false);
        }
      }
    }

    animation.addListener(updatePosition);
    if (indexedActivity == null) position.isScrollingNotifier.value = true;
    try {
      await animationController.forward().orCancel;
    } on TickerCanceled {
      // 新导航请求、用户手势或已分离时间线将接管下一位置；
      // 取消属于预期终态。
    } finally {
      animation.removeListener(updatePosition);
      animation.dispose();
      if (identical(_indexedAnimationController, animationController)) {
        _indexedAnimationController = null;
        final activity = indexedActivity;
        if (identical(_indexedScrollActivity, activity)) {
          _indexedScrollActivity = null;
          if (position is _AutoFollowScrollPosition && activity != null) {
            position.finishIndexedAnimation(activity);
          }
        } else if (activity == null) {
          position.isScrollingNotifier.value = false;
        }
        animationController.dispose();
      }
    }
  }

  void _cancelIndexedAnimationFromActivity(
    _IndexedScrollActivity indexedActivity,
  ) {
    if (!identical(_indexedScrollActivity, indexedActivity)) return;
    _indexedScrollActivity = null;
    _indexedNavigationRequest++;
    final animationController = _indexedAnimationController;
    _indexedAnimationController = null;
    animationController?.stop();
    animationController?.dispose();
  }

  void _cancelIndexedNavigationForDetach() {
    _indexedNavigationRequest++;
    // 此时滚动活动由 ScrollPosition 的释放流程负责。
    // 若从 ListController.onDetached 调用 goIdle，
    // 会向已停用的 widget 树发送滚动结束通知。
    _indexedScrollActivity = null;
    final animationController = _indexedAnimationController;
    _indexedAnimationController = null;
    animationController?.stop();
    animationController?.dispose();
  }

  void _cancelIndexedNavigation() {
    _indexedNavigationRequest++;
    final indexedActivity = _indexedScrollActivity;
    _indexedScrollActivity = null;
    if (indexedActivity != null &&
        _scrollController.hasClients &&
        _scrollController.position is _AutoFollowScrollPosition) {
      (_scrollController.position as _AutoFollowScrollPosition)
          .finishIndexedAnimation(indexedActivity);
    }
    final animationController = _indexedAnimationController;
    _indexedAnimationController = null;
    if (animationController == null) return;
    if (_scrollController.hasClients && indexedActivity == null) {
      _scrollController.position.isScrollingNotifier.value = false;
    }
    animationController.stop();
    animationController.dispose();
  }

  void _cancelProgrammaticNavigation({bool stopDrivenScroll = false}) {
    _bottomScrollRequest++;
    _deferredBottomRequest++;
    _scheduledBottomScrollRequest = null;
    _cancelIndexedNavigation();
    _explicitBottomAnimationInProgress = false;
    if (!stopDrivenScroll || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position is ScrollPositionWithSingleContext) {
      position.goIdle();
    }
  }

  // ============================================================================
  // State Modifiers
  // ============================================================================

  /// Reset the last jump user message ID (e.g., when starting new navigation).
  void resetLastJumpUserMessageId() {
    _cancelIndexedNavigation();
    _lastJumpUserMessageId = null;
  }

  /// Set auto-stick-to-bottom state.
  void setAutoStickToBottom(bool value) {
    _autoStickToBottom = value;
  }

  /// Reset user scrolling state (e.g., when force scrolling).
  void resetUserScrolling() {
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Dispose of resources.
  void dispose() {
    _scrollController.removeListener(_onScrollControllerChanged);
    _userScrollTimer?.cancel();
    _navButtonsHideTimer?.cancel();
    _cancelIndexedNavigation();
    _messageListController.dispose();
  }
}
