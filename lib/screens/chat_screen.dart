import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/motion.dart';
import '../design/neon_tokens.dart';
import '../design/neon_widgets.dart';
import '../features/assistant/widgets/action_cards.dart'
    show DocumentGalleryScreen;
import '../models/user_document.dart';
import '../services/api_service.dart';
import '../widgets/document_tile.dart'
    show documentGlyph, documentTypeLabel, openDocumentFile;
import '../widgets/chat_bubble.dart';
import '../services/app_feedback.dart';

/* ====================================================================== */
/* One conversation                                                        */
/* ====================================================================== */

class _ChatItem {
  final int id;
  final bool mine, auto, deleted;
  final String text;
  final int at;
  final int? documentId;

  /// What the attached document IS, from the server (2026-09-27 on).
  final String? documentMime, documentTitle, media;
  _ChatItem(this.id, this.mine, this.text, this.at, this.auto, this.documentId,
      {this.deleted = false, this.documentMime, this.documentTitle, this.media});

  UserDocument? get document => documentId == null
      ? null
      : chatDocument(
          id: documentId!, mime: documentMime, title: documentTitle, media: media);
}

/// The document a chat message carries, shaped for the gallery and the
/// open path. Every attachment used to be built as a JPEG, so a PDF sent
/// by a contact showed "Couldn't load this document" and a video note sat
/// there as a broken picture. The server now says the type; a video note
/// is known by `media` even without it, and anything still unknown (an
/// older server) keeps the old guess, a photo.
@visibleForTesting
UserDocument chatDocument(
    {required int id, String? mime, String? title, String? media}) {
  final type = (mime ?? '').trim().isNotEmpty
      ? mime!.trim()
      : media == 'video'
          ? 'video/mp4'
          : 'image/jpeg';
  return UserDocument(
    id: id,
    filename: '',
    mime: type,
    title: (title ?? '').trim().isEmpty ? 'Document' : title!.trim(),
    category: 'other',
    docDate: '',
    summary: '',
    note: '',
    createdAt: 0,
  );
}

/// A chat attachment that is not a picture: the type's glyph, its title
/// and what it is ("PDF", "Video"). Tapping opens it.
class _AttachmentTile extends StatelessWidget {
  final UserDocument document;
  const _AttachmentTile({required this.document});

  @override
  Widget build(BuildContext context) {
    final g = documentGlyph(document);
    final type = documentTypeLabel(document);
    return Container(
      width: 190,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Neon.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Neon.lineBright),
      ),
      child: Row(
        children: [
          Icon(g.icon, color: g.color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(document.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Neon.textHi,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (type.isNotEmpty)
                  Text(type,
                      style: TextStyle(color: Neon.textLo, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatThreadScreen extends StatefulWidget {
  final String phone, name;
  const ChatThreadScreen({super.key, required this.phone, required this.name});

  /// The person whose chat is on screen (their pushes are not shown as
  /// banners; the chat refreshes instead).
  static String? openPhone;

  /// Set to the sender's phone whenever a direct message push arrives.
  static final ValueNotifier<String> pushed = ValueNotifier<String>('');

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  List<_ChatItem> _items = const [];
  bool _loading = true;

  /// Could not load (offline) and nothing to show: say so, don't show an
  /// empty conversation as if there were none.
  bool _failed = false;
  bool _muted = false;
  bool _sending = false;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    ChatThreadScreen.openPhone = widget.phone;
    ChatThreadScreen.pushed.addListener(_onPush);
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState !=
              AppLifecycleState.resumed) {
        return;
      }
      _load();
    });
  }

  /// A message from this person just arrived: show it now.
  void _onPush() {
    if (mounted && ChatThreadScreen.pushed.value == widget.phone) _load();
  }

  @override
  void dispose() {
    if (ChatThreadScreen.openPhone == widget.phone) ChatThreadScreen.openPhone = null;
    ChatThreadScreen.pushed.removeListener(_onPush);
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.getJson(
          '/chat/thread/${Uri.encodeComponent(widget.phone)}');
      if (!mounted) return;
      if (r == null) {
        // A failed refresh keeps what is on screen.
        setState(() {
          _loading = false;
          _failed = _items.isEmpty;
        });
        return;
      }
      final items = ((r['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => _ChatItem(
                (m['id'] as num?)?.toInt() ?? 0,
                m['mine'] == true,
                (m['text'] ?? '').toString(),
                (m['at'] as num?)?.toInt() ?? 0,
                m['auto'] == true,
                (m['documentId'] as num?)?.toInt(),
                deleted: m['deleted'] == true,
                documentMime: m['documentMime'] as String?,
                documentTitle: m['documentTitle'] as String?,
                media: m['media'] as String?,
              ))
          .toList();
      final grew = items.length != _items.length;
      setState(() {
        _items = items;
        // The server owns this; without reading it back the menu label
        // reset to "Mute notifications" on every reopen.
        _muted = r['muted'] == true;
        _loading = false;
        _failed = false;
      });
      if (grew) _jumpToEnd();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = _items.isEmpty;
        });
      }
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final r = await ApiService.sendJson('/chat/send',
          method: 'POST', body: {'phone': widget.phone, 'text': text});
      if (r?['ok'] == true && mounted) {
        _input.clear();
        // The message IS sent: an odd reply shape must not report it as
        // failed (the owner would retype it and send a duplicate).
        final m = r!['item'];
        final id = m is Map ? (m['id'] as num?)?.toInt() : null;
        final at = m is Map ? (m['at'] as num?)?.toInt() : null;
        if (id == null) {
          unawaited(_load());
        } else {
          setState(() => _items = [
                ..._items,
                _ChatItem(id, true, text,
                    at ?? DateTime.now().millisecondsSinceEpoch, false, null),
              ]);
        }
        _jumpToEnd();
      } else if (mounted) {
        AppFeedback.show("Unable to send. The recipient may not be on MyAssistant.", context: context);
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.show("Unable to send the message. Please try again.", context: context);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openDocument(UserDocument doc) async {
    // The id references OUR copy of the file, so the gallery's viewer and
    // share button work exactly like any owned document. A photo or a
    // video note opens in the gallery (the video plays there); a PDF or
    // an office file goes through the signed-in download to the phone's
    // own viewer, as it does from My documents.
    if (!doc.isImage && !doc.mime.startsWith('video/')) {
      await openDocumentFile(doc);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DocumentGalleryScreen(documents: [doc]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // 2026-09-30: under the app's sky (NeonScaffold); the menu takes the
    // theme's floating surface.
    return NeonScaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          ChatAvatar(name: widget.name, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            popUpAnimationStyle: appMenuAnimation(context),
            onSelected: _onMenu,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mute',
                child: Text(_muted ? 'Unmute' : 'Mute Notifications'),
              ),
              PopupMenuItem(
                value: 'clear',
                child:
                    Text('Clear Chat', style: TextStyle(color: Neon.errorInk)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const NeonLoader.page()
                : _failed
                    // Scrolls when the keyboard leaves little room.
                    ? NeonErrorState(
                        message: "Unable to load this conversation.",
                        onRetry: () {
                          setState(() => _loading = true);
                          _load();
                        },
                      )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _bubble(_items[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              // The keyboard's Send key sends, as in group chat; the rim
              // lights while typing, the send button glows (2026-09-30).
              child: ChatComposer(
                controller: _input,
                onSend: _send,
                sending: _sending,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2026-09-30: the shared bubble (lib/widgets/chat_bubble.dart) — yours
  /// in the brand gradient with its halo, theirs on the raised surface
  /// with a rim.
  Widget _bubble(_ChatItem m) {
    final ink = ChatBubble.ink(m.mine), quiet = ChatBubble.quietInk(m.mine);
    final doc = m.document;
    return ChatBubble(
      mine: m.mine,
      at: m.at,
      onLongPress: m.deleted || m.id == 0 ? null : () => _messageMenu(m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.auto)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('Assistant · automatic reply',
                  style: TextStyle(
                      color: m.mine
                          ? Neon.onAccent.withValues(alpha: 0.7)
                          : Neon.textDim,
                      fontSize: 12)),
            ),
          if (doc != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Tappable(
                onTap: () => _openDocument(doc),
                semanticLabel: doc.isImage ? 'Photo: ${doc.title}' : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: !doc.isImage
                      // Not a picture: its type's glyph and title, not
                      // an Image.network that can only fail.
                      ? _AttachmentTile(document: doc)
                      : Image.network(
                          ApiService.documentFileUrl(m.documentId!),
                          headers: ApiService.imageHeaders,
                          width: 190,
                          height: 140,
                          fit: BoxFit.cover,
                          // Decoded at the size it is drawn (2026-09-24):
                          // 400 px was upscaled about 1.25x on his phone
                          // (190 dp at 2.625) and looked soft. A tenth
                          // over, for the crop.
                          cacheWidth: (190 *
                                  MediaQuery.devicePixelRatioOf(context) *
                                  1.1)
                              .round(),
                          errorBuilder: (_, __, ___) => Container(
                            width: 190,
                            height: 60,
                            color: Neon.surfaceHigh,
                            child: Icon(Icons.description_rounded,
                                color: Neon.violet),
                          ),
                        ),
                ),
              ),
            ),
          m.deleted
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block_rounded, size: 13, color: quiet),
                    const SizedBox(width: 5),
                    Text('This message was deleted',
                        style: TextStyle(
                            color: quiet,
                            fontSize: 14,
                            fontStyle: FontStyle.italic)),
                  ],
                )
              : Text(m.text,
                  style: TextStyle(color: ink, fontSize: 14, height: 1.35)),
        ],
      ),
    );
  }

  /// Mute is reversible so it just happens; clearing is not, so it asks.
  Future<void> _onMenu(String v) async {
    if (v == 'mute') {
      final next = !_muted;
      setState(() => _muted = next);
      final r = await ApiService.postJson(
          '/chat/thread/${widget.phone}/mute', {'muted': next});
      if (mounted) setState(() => _muted = r?['muted'] == true);
      return;
    }
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear Chat'),
        content: Text(
          'This removes the messages from your copy only. '
          '${widget.name} retains theirs.',
          style: TextStyle(color: Neon.textLo, height: 1.4, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text('Cancel', style: TextStyle(color: Neon.textLo)),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: TextButton.styleFrom(foregroundColor: Neon.errorInk),
            child: const Text('Clear',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ApiService.postJson('/chat/thread/${widget.phone}/clear', const {});
    if (mounted) {
      setState(() => _items = []);
      _load();
    }
  }

  /// Long-press a message: copy it, or take it back. Same shape as the
  /// group screen's — one gesture, one sheet, no hidden swipe.
  Future<void> _messageMenu(_ChatItem m) async {
    if (m.deleted || m.id == 0) return;
    HapticFeedback.selectionClick();
    final choice = await showAppSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.copy_rounded, color: Neon.textHi),
              title: Text('Copy', style: TextStyle(color: Neon.textHi)),
              onTap: () => Navigator.of(c).pop('copy'),
            ),
            if (m.mine)
              ListTile(
                leading: Icon(Icons.undo_rounded, color: Neon.error),
                title: Text('Delete for Everyone',
                    style: TextStyle(color: Neon.errorInk)),
                onTap: () => Navigator.of(c).pop('everyone'),
              ),
            ListTile(
              leading: Icon(Icons.visibility_off_rounded, color: Neon.textHi),
              title:
                  Text('Delete for Me', style: TextStyle(color: Neon.textHi)),
              onTap: () => Navigator.of(c).pop('me'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.text));
      if (mounted) {
        AppFeedback.copied(context);
      }
      return;
    }
    await ApiService.deleteJson(
        '/chat/message/${m.id}${choice == 'everyone' ? '?everyone=1' : ''}');
    if (mounted) _load();
  }
}
