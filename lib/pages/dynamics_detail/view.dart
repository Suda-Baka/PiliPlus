import 'dart:math';

import 'package:PiliPlus/common/skeleton/video_reply.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/custom_sliver_persistent_header_delegate.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/refresh_indicator.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/reply/reply_sort_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/dynamics/widgets/author_panel.dart';
import 'package:PiliPlus/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:PiliPlus/pages/dynamics_detail/controller.dart';
import 'package:PiliPlus/pages/dynamics_repost/view.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/pages/video/reply_reply/view.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class DynamicDetailPage extends StatefulWidget {
  const DynamicDetailPage({super.key});

  @override
  State<DynamicDetailPage> createState() => _DynamicDetailPageState();
}

class _DynamicDetailPageState extends State<DynamicDetailPage>
    with TickerProviderStateMixin {
  final _controller =
      Get.put(DynamicDetailController(), tag: Utils.generateRandomString(8));
  late final AnimationController _fabAnimationCtr;
  late final Animation<Offset> _anim;

  final RxBool _visibleTitle = false.obs;
  bool _isFabVisible = true;
  bool? _imageStatus;

  late final List<double> _ratio = GStorage.dynamicDetailRatio;

  bool get _horizontalPreview =>
      context.orientation == Orientation.landscape &&
      _controller.horizontalPreview;

  late final _key = GlobalKey<ScaffoldState>();

  final GlobalKey _commentHeaderKey = GlobalKey();

  Function(dynamic imgList, dynamic index)? get _getImageCallback =>
      _horizontalPreview
          ? (imgList, index) {
              _imageStatus = true;
              bool isFabVisible = _isFabVisible;
              if (isFabVisible) {
                _hideFab();
              }
              final ctr = AnimationController(
                vsync: this,
                duration: const Duration(milliseconds: 200),
              )..forward();
              PageUtils.onHorizontalPreview(
                _key,
                AnimationController(
                  vsync: this,
                  duration: Duration.zero,
                ),
                ctr,
                imgList,
                index,
                (value) async {
                  _imageStatus = null;
                  if (isFabVisible) {
                    isFabVisible = false;
                    _showFab();
                  }
                  if (value == false) {
                    await ctr.reverse();
                  }
                  try {
                    ctr.dispose();
                  } catch (_) {}
                  if (value == false) {
                    Get.back();
                  }
                },
              );
            }
          : null;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args != null && args['action'] == 'comment') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToComment();
      });
    }
    _fabAnimationCtr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fabAnimationCtr,
      curve: Curves.easeInOut,
    ));
    _fabAnimationCtr.forward();
    _controller.scrollController.addListener(listener);
  }

  // 查看二级评论
  void replyReply(BuildContext context, ReplyInfo replyItem, int? id) {
    EasyThrottle.throttle('replyReply', const Duration(milliseconds: 500), () {
      int oid = replyItem.oid.toInt();
      int rpid = replyItem.id.toInt();
      Widget replyReplyPage({
        bool automaticallyImplyLeading = true,
        VoidCallback? onDispose,
      }) =>
          Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              title: const Text('评论详情'),
              titleSpacing: automaticallyImplyLeading ? null : 12,
              automaticallyImplyLeading: automaticallyImplyLeading,
            ),
            body: SafeArea(
              top: false,
              bottom: false,
              child: VideoReplyReplyPanel(
                enableSlide: false,
                id: id,
                oid: oid,
                rpid: rpid,
                source: 'dynamic',
                replyType: _controller.replyType,
                firstFloor: replyItem,
                onDispose: onDispose,
              ),
            ),
          );
      if (this.context.orientation == Orientation.portrait) {
        Get.to(
          replyReplyPage,
          routeName: 'dynamicDetail-Copy',
          arguments: {
            'item': _controller.dynItem,
          },
        );
      } else {
        ScaffoldState? scaffoldState = Scaffold.maybeOf(context);
        if (scaffoldState != null) {
          bool isFabVisible = _isFabVisible;
          if (isFabVisible) {
            _hideFab();
          }
          scaffoldState.showBottomSheet(
            backgroundColor: Colors.transparent,
            (context) => MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              child: replyReplyPage(
                automaticallyImplyLeading: false,
                onDispose: () {
                  if (isFabVisible && _imageStatus != true) {
                    _showFab();
                  }
                },
              ),
            ),
          );
        } else {
          Get.to(
            replyReplyPage,
            routeName: 'dynamicDetail-Copy',
            arguments: {
              'item': _controller.dynItem,
            },
          );
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.scrollController.hasClients) {
        _visibleTitle.value =
            _controller.scrollController.positions.first.pixels > 55;
      }
    });
  }

  void listener() {
    // 标题
    _visibleTitle.value =
        _controller.scrollController.positions.first.pixels > 55;

    // fab按钮
    final ScrollDirection direction1 =
        _controller.scrollController.positions.first.userScrollDirection;
    late final ScrollDirection direction2 =
        _controller.scrollController.positions.last.userScrollDirection;
    if (direction1 == ScrollDirection.forward ||
        direction2 == ScrollDirection.forward) {
      _showFab();
    } else if (direction1 == ScrollDirection.reverse ||
        direction2 == ScrollDirection.reverse) {
      _hideFab();
    }
  }

  void _showFab() {
    if (!_isFabVisible) {
      _isFabVisible = true;
      _fabAnimationCtr.forward();
    }
  }

  void _hideFab() {
    if (_isFabVisible) {
      _isFabVisible = false;
      _fabAnimationCtr.reverse();
    }
  }

  void _scrollToComment() {
    final ctx = _commentHeaderKey.currentContext;
    if (ctx != null) {
      final double topPadding =
          kToolbarHeight + MediaQuery.of(context).padding.top;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        alignment: 0,
        curve: Curves.easeInOut,
      );

      Future.delayed(const Duration(milliseconds: 350), () {
        final scrollController = _controller.scrollController;
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.offset - topPadding,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _fabAnimationCtr.dispose();
    _controller.scrollController.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Obx(
            () {
              return AnimatedOpacity(
                opacity: _visibleTitle.value ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: AuthorPanel(
                  item: _controller.dynItem,
                  source: 'detail', //to remove tag
                ),
              );
            },
          ),
        ),
        actions: context.orientation == Orientation.landscape
            ? [
                IconButton(
                  tooltip: '页面比例调节',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.only(
                          top: 56,
                          right: 16,
                        ),
                        width: context.width / 4,
                        height: 32,
                        child: Builder(
                          builder: (context) => Slider(
                            min: 1,
                            max: 100,
                            value: _ratio.first,
                            onChanged: (value) {
                              if (value >= 10 && value <= 90) {
                                _ratio[0] = value;
                                _ratio[1] = 100 - value;
                                GStorage.setting.put(
                                  SettingBoxKey.dynamicDetailRatio,
                                  _ratio,
                                );
                                (context as Element).markNeedsBuild();
                                setState(() {});
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  icon: Transform.rotate(
                    angle: pi / 2,
                    child: const Icon(Icons.splitscreen, size: 19),
                  ),
                ),
                const SizedBox(width: 16),
              ]
            : null,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: context.orientation == Orientation.portrait
            ? refreshIndicator(
                onRefresh: _controller.onRefresh,
                child: _buildBody(context.orientation, theme),
              )
            : _buildBody(context.orientation, theme),
      ),
    );
  }

  Widget _buildBody(Orientation orientation, ThemeData theme) => Stack(
        clipBehavior: Clip.none,
        children: [
          Builder(
            builder: (context) {
              double padding = max(context.width / 2 - Grid.smallCardWidth, 0);
              if (orientation == Orientation.portrait) {
                return CustomScrollView(
                  controller: _controller.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: DynamicPanel(
                        item: _controller.dynItem,
                        source: 'detail',
                        callback: _getImageCallback,
                      ),
                    ),
                    replyPersistentHeader(theme),
                    Obx(
                      () => replyList(theme, _controller.loadingState.value),
                    ),
                  ]
                      .map<Widget>((e) => SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: padding),
                          sliver: e))
                      .toList(),
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      flex: _ratio[0].toInt(),
                      child: CustomScrollView(
                        controller: _controller.scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.only(
                              left: padding / 4,
                              bottom: MediaQuery.paddingOf(context).bottom + 80,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: DynamicPanel(
                                item: _controller.dynItem,
                                source: 'detail',
                                callback: _getImageCallback,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: _ratio[1].toInt(),
                      child: Scaffold(
                        key: _key,
                        backgroundColor: Colors.transparent,
                        body: refreshIndicator(
                          onRefresh: _controller.onRefresh,
                          child: CustomScrollView(
                            controller: _controller.scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.only(right: padding / 4),
                                sliver: replyPersistentHeader(theme),
                              ),
                              SliverPadding(
                                padding: EdgeInsets.only(right: padding / 4),
                                sliver: Obx(
                                  () => replyList(
                                      theme, _controller.loadingState.value),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _anim,
              child: Builder(
                builder: (context) {
                  Widget button() => FloatingActionButton(
                        heroTag: null,
                        onPressed: () {
                          feedBack();
                          _controller.onReply(
                            context,
                            oid: _controller.oid,
                            replyType: _controller.replyType,
                          );
                        },
                        tooltip: '评论动态',
                        child: const Icon(Icons.reply),
                      );
                  return _controller.showDynActionBar.not
                      ? Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: 14,
                              bottom: MediaQuery.paddingOf(context).bottom + 14,
                            ),
                            child: button(),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 14, bottom: 14),
                              child: button(),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                border: Border(
                                  top: BorderSide(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                              padding: EdgeInsets.only(
                                  bottom: MediaQuery.paddingOf(context).bottom),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Expanded(
                                    child: Builder(
                                      builder: (btnContext) => TextButton.icon(
                                        onPressed: () => showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          builder: (context) => RepostPanel(
                                            item: _controller.dynItem,
                                            callback: () {
                                              int count = _controller
                                                      .dynItem
                                                      .modules
                                                      .moduleStat
                                                      ?.forward
                                                      ?.count ??
                                                  0;
                                              _controller.dynItem.modules
                                                      .moduleStat ??=
                                                  ModuleStatModel();
                                              _controller
                                                  .dynItem
                                                  .modules
                                                  .moduleStat
                                                  ?.forward ??= DynamicStat();
                                              _controller
                                                  .dynItem
                                                  .modules
                                                  .moduleStat!
                                                  .forward!
                                                  .count = count + 1;
                                              if (btnContext.mounted) {
                                                (btnContext as Element?)
                                                    ?.markNeedsBuild();
                                              }
                                            },
                                          ),
                                        ),
                                        icon: Icon(
                                          FontAwesomeIcons.shareFromSquare,
                                          size: 16,
                                          color: theme.colorScheme.outline,
                                          semanticLabel: "转发",
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.fromLTRB(
                                              15, 0, 15, 0),
                                          foregroundColor:
                                              theme.colorScheme.outline,
                                        ),
                                        label: Text(
                                          _controller.dynItem.modules.moduleStat
                                                      ?.forward?.count !=
                                                  null
                                              ? Utils.numFormat(_controller
                                                  .dynItem
                                                  .modules
                                                  .moduleStat!
                                                  .forward!
                                                  .count)
                                              : '转发',
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => Utils.shareText(
                                          '${HttpString.dynamicShareBaseUrl}/${_controller.dynItem.idStr}'),
                                      icon: Icon(
                                        CustomIcon.share_node,
                                        size: 16,
                                        color: theme.colorScheme.outline,
                                        semanticLabel: "分享",
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.fromLTRB(
                                            15, 0, 15, 0),
                                        foregroundColor:
                                            theme.colorScheme.outline,
                                      ),
                                      label: const Text('分享'),
                                    ),
                                  ),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) => TextButton.icon(
                                        onPressed: () =>
                                            RequestUtils.onLikeDynamic(
                                          _controller.dynItem,
                                          () {
                                            if (context.mounted) {
                                              (context as Element?)
                                                  ?.markNeedsBuild();
                                            }
                                          },
                                        ),
                                        icon: Icon(
                                          _controller.dynItem.modules.moduleStat
                                                      ?.like?.status ==
                                                  true
                                              ? FontAwesomeIcons.solidThumbsUp
                                              : FontAwesomeIcons.thumbsUp,
                                          size: 16,
                                          color: _controller
                                                      .dynItem
                                                      .modules
                                                      .moduleStat
                                                      ?.like
                                                      ?.status ==
                                                  true
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.outline,
                                          semanticLabel: _controller
                                                      .dynItem
                                                      .modules
                                                      .moduleStat
                                                      ?.like
                                                      ?.status ==
                                                  true
                                              ? "已赞"
                                              : "点赞",
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.fromLTRB(
                                              15, 0, 15, 0),
                                          foregroundColor:
                                              theme.colorScheme.outline,
                                        ),
                                        label: AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 400),
                                          transitionBuilder: (Widget child,
                                              Animation<double> animation) {
                                            return ScaleTransition(
                                                scale: animation, child: child);
                                          },
                                          child: Text(
                                            _controller
                                                        .dynItem
                                                        .modules
                                                        .moduleStat
                                                        ?.like
                                                        ?.count !=
                                                    null
                                                ? Utils.numFormat(_controller
                                                    .dynItem
                                                    .modules
                                                    .moduleStat!
                                                    .like!
                                                    .count)
                                                : '点赞',
                                            style: TextStyle(
                                              color: _controller
                                                          .dynItem
                                                          .modules
                                                          .moduleStat
                                                          ?.like
                                                          ?.status ==
                                                      true
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.outline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                },
              ),
            ),
          ),
        ],
      );

  SliverPersistentHeader replyPersistentHeader(ThemeData theme) {
    return SliverPersistentHeader(
      key: _commentHeaderKey,
      delegate: CustomSliverPersistentHeaderDelegate(
        bgColor: theme.colorScheme.surface,
        child: Container(
          height: 45,
          padding: const EdgeInsets.only(left: 12, right: 6),
          child: Row(
            children: [
              Obx(
                () => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    '${_controller.count.value == -1 ? 0 : Utils.numFormat(_controller.count.value)}条回复',
                    key: ValueKey<int>(_controller.count.value),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 35,
                child: TextButton.icon(
                  onPressed: () => _controller.queryBySort(),
                  icon: Icon(
                    Icons.sort,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  label: Obx(() => Text(
                        _controller.sortType.value.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.secondary,
                        ),
                      )),
                ),
              )
            ],
          ),
        ),
      ),
      pinned: true,
    );
  }

  Widget replyList(
      ThemeData theme, LoadingState<List<ReplyInfo>?> loadingState) {
    return switch (loadingState) {
      Loading() => SliverList.builder(
          itemBuilder: (context, index) {
            return const VideoReplySkeleton();
          },
          itemCount: 8,
        ),
      Success(:var response) => response?.isNotEmpty == true
          ? SliverList.builder(
              itemBuilder: (context, index) {
                if (index == response.length) {
                  _controller.onLoadMore();
                  return Container(
                    alignment: Alignment.center,
                    margin: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom),
                    height: 125,
                    child: Text(
                      _controller.isEnd ? '没有更多了' : '加载中...',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  );
                } else {
                  return ReplyItemGrpc(
                    replyItem: response[index],
                    replyLevel: '1',
                    replyReply: (replyItem, id) =>
                        replyReply(context, replyItem, id),
                    onReply: () => _controller.onReply(
                      context,
                      replyItem: response[index],
                      index: index,
                    ),
                    onDelete: (subIndex) =>
                        _controller.onRemove(index, subIndex),
                    upMid: _controller.upMid,
                    callback: _getImageCallback,
                    onCheckReply: (item) =>
                        _controller.onCheckReply(context, item),
                    onToggleTop: (isUpTop, rpid) => _controller.onToggleTop(
                      index,
                      _controller.oid,
                      _controller.replyType,
                      isUpTop,
                      rpid,
                    ),
                  );
                }
              },
              itemCount: response!.length + 1,
            )
          : HttpError(
              onReload: _controller.onReload,
            ),
      Error(:var errMsg) => HttpError(
          errMsg: errMsg,
          onReload: _controller.onReload,
        ),
    };
  }
}
