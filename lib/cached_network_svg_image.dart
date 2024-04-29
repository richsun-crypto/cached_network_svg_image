//去除了所有动画;
library cached_network_svg_image;

import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// afterInitRead是组件初始化的时候根据url去缓存读取文件,读取不到就去下载;
/// beforeDownload,afterDownload,beforeReadCache,afterReadCache分别是下载前后触发,读取缓存前后触发
///beforeShowImage,svg无论是读内存还是下载,反正成功且将要显示前;
class CachedNetworkSVGImage extends StatefulWidget {
  CachedNetworkSVGImage(
    String url, {
    Key? key,
    Widget? placeholder,
    Widget? errorWidget,
    double? width,
    double? height,
    Map<String, String>? headers,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    bool matchTextDirection = false,
    bool allowDrawingOutsideViewBox = false,
    @deprecated Color? color,
    @deprecated BlendMode colorBlendMode = BlendMode.srcIn,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    SvgTheme theme = const SvgTheme(),
    Duration fadeDuration = const Duration(milliseconds: 300),
    ColorFilter? colorFilter,
    WidgetBuilder? placeholderBuilder,
    BaseCacheManager? cacheManager,
    this.afterLoadImage,
    this.beforeReadCache,
    this.afterReadCache,
    this.beforeShowImage,
  })  : _url = url,
        _placeholder = placeholder,
        _errorWidget = errorWidget,
        _width = width,
        _height = height,
        _headers = headers,
        _fit = fit,
        _alignment = alignment,
        _matchTextDirection = matchTextDirection,
        _allowDrawingOutsideViewBox = allowDrawingOutsideViewBox,
        _color = color,
        _colorBlendMode = colorBlendMode,
        _semanticsLabel = semanticsLabel,
        _excludeFromSemantics = excludeFromSemantics,
        _theme = theme,
        _fadeDuration = fadeDuration,
        _colorFilter = colorFilter,
        _placeholderBuilder = placeholderBuilder,
        _cacheManager = cacheManager ?? DefaultCacheManager(),
        super(key: key ?? ValueKey(url));

  final String _url;
  final Widget? _placeholder;
  final Widget? _errorWidget;
  final double? _width;
  final double? _height;
  final Map<String, String>? _headers;
  final BoxFit _fit;
  final AlignmentGeometry _alignment;
  final bool _matchTextDirection;
  final bool _allowDrawingOutsideViewBox;
  final Color? _color;
  final BlendMode _colorBlendMode;
  final String? _semanticsLabel;
  final bool _excludeFromSemantics;
  final SvgTheme _theme;
  final Duration _fadeDuration;
  final ColorFilter? _colorFilter;
  final WidgetBuilder? _placeholderBuilder;
  final BaseCacheManager _cacheManager;
  final Function(String)? afterLoadImage; // 新增回调参数
  final Function(String cacheKey, String imageUrl)? beforeReadCache;

  final Function(String cacheKey, String imageUrl, bool isReadSuccess, String svgString)? afterReadCache;

  final Function(String svgString)? beforeShowImage;

  @override
  State<CachedNetworkSVGImage> createState() => _CachedNetworkSVGImageState();

  /// 直接缓存指定文件
  static Future<void> preCache(String imageUrl, {BaseCacheManager? cacheManager}) {
    final key = _generateKeyFromUrl(imageUrl);
    cacheManager ??= DefaultCacheManager();
    return cacheManager.downloadFile(key);
  }

  /// 清理指定缓存
  static Future<void> clearCacheForUrl(String imageUrl, {BaseCacheManager? cacheManager}) {
    final key = _generateKeyFromUrl(imageUrl);
    cacheManager ??= DefaultCacheManager();
    return cacheManager.removeFile(key);
  }

  ///清理所有缓存
  static Future<void> clearCache({BaseCacheManager? cacheManager}) {
    cacheManager ??= DefaultCacheManager();
    return cacheManager.emptyCache();
  }

  static String _generateKeyFromUrl(String url) => url.split('?').first;
}

class _CachedNetworkSVGImageState extends State<CachedNetworkSVGImage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isError = false;
  File? _imageFile;
  late String _cacheKey;

/*  late final AnimationController _controller;
  late final Animation<double> _animation;*/

  @override
  void initState() {
    super.initState();
    _cacheKey = CachedNetworkSVGImage._generateKeyFromUrl(widget._url);
    /*_controller = AnimationController(
      vsync: this,
      duration: widget._fadeDuration,
    );*/
    // _animation = Tween(begin: 0.0, end: 1.0).animate(_controller);
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      _setToLoadingAfter15MsIfNeeded();
      //读取缓存前;
      if (widget.beforeReadCache != null) {
        widget.beforeReadCache!(_cacheKey, widget._url);
      }
      var file = (await widget._cacheManager.getFileFromMemory(_cacheKey))?.file;
      //如果file不为空则返回文件内容;
      if (widget.afterReadCache != null) {
        widget.afterReadCache!(_cacheKey, widget._url, file == null ? false : true, file != null ? await file.readAsString() : "");
      }

      file ??= await widget._cacheManager.getSingleFile(
        widget._url,
        key: _cacheKey,
        headers: widget._headers ?? {},
      );

      _imageFile = file;
      _isLoading = false;

      // 这里触发回调函数
      if (widget.afterLoadImage != null) {
        widget.afterLoadImage!(await file.readAsString()); // 调用回调并传递SVG数据
      }
      //---------完成触发
      _setState();

      // _controller.forward();
    } catch (e) {
      log('CachedNetworkSVGImage: $e');

      _isError = true;
      _isLoading = false;

      _setState();
    }
  }

  void _setToLoadingAfter15MsIfNeeded() => Future.delayed(
        const Duration(milliseconds: 15),
        () {
          if (!_isLoading && _imageFile == null && !_isError) {
            _isLoading = true;
            _setState();
          }
        },
      );

  void _setState() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    // _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget._width,
      height: widget._height,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    if (_isLoading) return _buildPlaceholderWidget();

    if (_isError) return _buildErrorWidget();

    return _buildSVGImage();
  }

  Widget _buildPlaceholderWidget() => Center(child: widget._placeholder ?? const SizedBox());

  Widget _buildErrorWidget() => Center(child: widget._errorWidget ?? const SizedBox());

  Widget _buildSVGImage() {
    if (_imageFile == null) return const SizedBox();

    _imageFile!.readAsString().then((svgData) {
      if (widget.beforeShowImage != null) {
        widget.beforeShowImage!(svgData);
      }
    });

    return SvgPicture.file(
      _imageFile!,
      fit: widget._fit,
      width: widget._width,
      height: widget._height,
      alignment: widget._alignment,
      matchTextDirection: widget._matchTextDirection,
      allowDrawingOutsideViewBox: widget._allowDrawingOutsideViewBox,
      color: widget._color,
      colorBlendMode: widget._colorBlendMode,
      semanticsLabel: widget._semanticsLabel,
      excludeFromSemantics: widget._excludeFromSemantics,
      colorFilter: widget._colorFilter,
      placeholderBuilder: widget._placeholderBuilder,
      theme: widget._theme,
    );
  }
}
