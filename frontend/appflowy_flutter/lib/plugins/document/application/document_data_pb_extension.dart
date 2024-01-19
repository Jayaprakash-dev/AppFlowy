import 'dart:convert';

import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-document/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart'
    show
        Document,
        Node,
        Attributes,
        Delta,
        ParagraphBlockKeys,
        NodeIterator,
        NodeExternalValues;
import 'package:collection/collection.dart';
import 'package:nanoid/nanoid.dart';

class ExternalValues extends NodeExternalValues {
  const ExternalValues({
    required this.externalId,
    required this.externalType,
  });

  final String externalId;
  final String externalType;
}

extension DocumentDataPBFromTo on DocumentDataPB {
  static DocumentDataPB? fromDocument(Document document) {
    final startNode = document.first;
    final endNode = document.last;
    if (startNode == null || endNode == null) {
      return null;
    }
    final pageId = document.root.id;

    // generate the block
    final blocks = <String, BlockPB>{};
    final nodes = NodeIterator(
      document: document,
      startNode: startNode,
      endNode: endNode,
    ).toList();
    for (final node in nodes) {
      if (blocks.containsKey(node.id)) {
        assert(false, 'duplicate node id: ${node.id}');
      }
      final parentId = node.parent?.id;
      final childrenId = nanoid(10);
      blocks[node.id] = node.toBlock(
        parentId: parentId,
        childrenId: childrenId,
      );
    }
    // root
    blocks[pageId] = document.root.toBlock(
      parentId: '',
      childrenId: pageId,
    );

    // generate the meta
    final childrenMap = <String, ChildrenPB>{};
    blocks.forEach((key, value) {
      final parentId = value.parentId;
      if (parentId.isNotEmpty) {
        childrenMap[parentId] ??= ChildrenPB.create();
        childrenMap[parentId]!.children.add(value.id);
      }
    });
    final meta = MetaPB(childrenMap: childrenMap);

    return DocumentDataPB(
      blocks: blocks,
      pageId: pageId,
      meta: meta,
    );
  }

  Document? toDocument({String? viewId}) {
    final rootId = pageId;
    try {
      final root = buildNode(rootId);

      if (root != null) {
        return Document(root: root, id: viewId);
      }

      return null;
    } catch (e) {
      Log.error('create document error: $e');
      return null;
    }
  }

  Node? buildNode(String id) {
    final block = blocks[id];
    final childrenId = block?.childrenId;
    final childrenIds = meta.childrenMap[childrenId]?.children;

    final children = <Node>[];
    if (childrenIds != null && childrenIds.isNotEmpty) {
      children.addAll(childrenIds.map((e) => buildNode(e)).whereNotNull());
    }

    return block?.toNode(
      children: children,
      meta: meta,
    );
  }
}

extension BlockToNode on BlockPB {
  Node toNode({
    Iterable<Node>? children,
    required MetaPB meta,
  }) {
    final node = Node(
      id: id,
      type: ty,
      attributes: _dataAdapter(ty, data, meta),
      children: children ?? [],
    );
    node.externalValues = ExternalValues(
      externalId: externalId,
      externalType: externalType,
    );
    return node;
  }

  Attributes _dataAdapter(String ty, String data, MetaPB meta) {
    final map = Attributes.from(jsonDecode(data));

    // it used in the delta case now.
    final externalType = this.externalType;
    final externalId = this.externalId;
    if (externalType.isNotEmpty && externalId.isNotEmpty) {
      // the 'text' type is the only type that is supported now.
      if (externalType == 'text') {
        final deltaString = meta.textMap[externalId];
        if (deltaString != null) {
          final delta = jsonDecode(deltaString);
          map.putIfAbsent(
            'delta',
            () => delta,
          );
        }
      }
    }

    final adapter = {
      ParagraphBlockKeys.type: (Attributes map) => map
        ..putIfAbsent(
          'delta',
          () => Delta().toJson(),
        ),
    };
    return adapter[ty]?.call(map) ?? map;
  }
}

extension NodeToBlock on Node {
  BlockPB toBlock({
    String? parentId,
    String? childrenId,
    Attributes? attributes,
  }) {
    assert(id.isNotEmpty);
    final block = BlockPB.create()
      ..id = id
      ..ty = type
      ..data = _dataAdapter(type, attributes ?? this.attributes);
    if (childrenId != null && childrenId.isNotEmpty) {
      block.childrenId = childrenId;
    }
    if (parentId != null && parentId.isNotEmpty) {
      block.parentId = parentId;
    }
    return block;
  }

  String _dataAdapter(String type, Attributes attributes) {
    return jsonEncode(attributes);
  }
}
