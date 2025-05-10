import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/common/image_preview_type.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;

Widget htmlRender({
  required BuildContext context,
  dom.Element? element,
  String? html,
  int? imgCount,
  List<String>? imgList,
  required double maxWidth,
  Function(List<String>, int)? callback,
}) {
  debugPrint('htmlRender');
  final extensions = [
    TagExtension(
      tagsToExtend: <String>{'img'},
      builder: (ExtensionContext extensionContext) {
        try {
          final Map<String, dynamic> attributes = extensionContext.attributes;
          final List<dynamic> key = attributes.keys.toList();
          String imgUrl = key.contains('src')
              ? attributes['src'] as String
              : attributes['data-src'] as String;
          imgUrl = imgUrl.contains('@') ? imgUrl.split('@').first : imgUrl;
          final bool isEmote = imgUrl.contains('/emote/');
          final bool isMall = imgUrl.contains('/mall/');
          if (isMall) {
            return const SizedBox.shrink();
          }

          String? clazz = attributes['class'];
          String? height = RegExp(r'max-height:(\d+)px')
              .firstMatch('${attributes['style']}')
              ?.group(1);
          if (clazz?.contains('cut-off') == true || height != null) {
            return CachedNetworkImage(
              width: maxWidth,
              height: height != null ? double.parse(height) : null,
              imageUrl: Utils.thumbnailImgUrl(imgUrl),
              fit: BoxFit.contain,
            );
          }
          return Hero(
            tag: imgUrl,
            child: GestureDetector(
              onTap: () {
                if (callback != null) {
                  callback([imgUrl], 0);
                } else {
                  context.imageView(
                    imgList: [SourceModel(url: imgUrl)],
                  );
                }
              },
              child: NetworkImgLayer(
                width: isEmote ? 22 : maxWidth,
                height: isEmote ? 22 : null,
                src: imgUrl,
              ),
            ),
          );
        } catch (err) {
          debugPrint('错误的HTML: $element');
          return const SizedBox.shrink();
        }
      },
    },
    TagExtension(
      tagsToExtend: <String>{'ol'},
      builder: (ExtensionContext extensionContext) {
        final children = extensionContext.innerHtml;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .split('</li>') // 按 <li> 标签分割内容
                .where((item) => item.trim().isNotEmpty)
                .map((item) {
            final index = children.split('</li>').indexOf(item) + 1; // 计算序号
            final content = item.replaceFirst('<li>', '').trim();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(extensionContext.buildContext).primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(content),
                ),
              ],
            );
          }).toList(),
        }
      },
    ),
  ];
  final style = {
    'html': Style(
      fontSize: FontSize(16),
      lineHeight: LineHeight.percent(160),
      letterSpacing: 0.3,
    ),
    'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
    'a': Style(
      color: Theme.of(context).colorScheme.primary,
      textDecoration: TextDecoration.none,
    ),
    'br': Style(
      lineHeight: LineHeight.percent(-1),
    ),
    'p': Style(
      margin: Margins.only(bottom: 4,left: 20),
      textAlign: TextAlign.start,
    ),
    'span': Style(
      fontSize: FontSize.large,
      height: Height(1.8),
    ),
    'div': Style(
      height: Height.auto()
    ),
    'li > p': Style(
      display: Display.inline,
    ),
    'li': Style(
      padding: HtmlPaddings.only(bottom: 4),
      listStylePosition: ListStylePosition.inside,
      textAlign: TextAlign.start,
    ),
    'img': Style(
      margin: Margins.only(top: 4, bottom: 4)
    ),
    'h1,h2': Style(
      fontSize: FontSize.xLarge,
      fontWeight: FontWeight.bold,
      margin: Margins.only(bottom: 8),
    ),
    'h3,h4,h5': Style(
      fontSize: FontSize(16),
      fontWeight: FontWeight.bold,
      margin: Margins.only(bottom: 4),
    ),
    'figcaption': Style(
      fontSize: FontSize.large,
      textAlign: TextAlign.center,
    ),
    'strong': Style(fontWeight: FontWeight.bold),
    'figure': Style(
      margin: Margins.zero,
    ),
  };
  return SelectionArea(
    child: element != null
        ? Html.fromElement(
            documentElement: element,
            extensions: extensions,
            style: style,
          )
        : Html(
            data: html,
            extensions: extensions,
            style: style,
          ),
  );
}
