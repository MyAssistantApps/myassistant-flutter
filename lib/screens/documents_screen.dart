import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../design/apple_kit.dart';
import '../design/motion.dart' show StateSwitch, Tappable, showAppSheet;
import '../design/neon_tokens.dart';
import '../design/neon_widgets.dart';
import '../models/user_document.dart';
import '../services/api_service.dart';
import '../services/document_events.dart';
import '../widgets/document_tile.dart';
import '../widgets/my_photo_card.dart';
import '../services/app_feedback.dart';
import 'pro_assistant_screen.dart';
import '../ai/assistant_role.dart';
import '../widgets/role_mic_orb.dart';

/// True while [uploadMyDocument] is sending; its buttons show it and a
/// second tap is ignored, so one file is never saved twice.
final documentUploading = ValueNotifier<bool>(false);

/// Picks a photo or file and saves it to My documents (the same flow a case
/// file uses, without the client). Shared by Home's documents section and
/// the assistant chats. Returns the saved document, or null if nothing was.
Future<UserDocument?> uploadMyDocument(BuildContext context,
    {bool photosOnly = false}) async {
  if (documentUploading.value) return null;
  final source = await showAppSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GroupedCard(
          dividerInset: 60,
          children: [
            AppleRow(
              leading: IconTile(Icons.photo_camera_rounded, AppleColors.blue),
              title: 'Take a Photo',
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            AppleRow(
              leading: IconTile(Icons.photo_library_rounded, AppleColors.blue),
              title: 'Select from Gallery',
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (!photosOnly)
              AppleRow(
                leading: IconTile(Icons.description_rounded, AppleColors.red),
                title: 'Select a File (PDF, Word, Excel…)',
                onTap: () => Navigator.pop(ctx, 'file'),
              ),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return null;

  List<int> bytes;
  String filename;
  String mime = 'image/jpeg';
  try {
    if (source == 'file') {
      final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const [
            'pdf', 'docx', 'xlsx', 'pptx', 'csv', 'txt', 'md', 'rtf'
          ],
          withData: true);
      final f = (picked != null && picked.files.isNotEmpty)
          ? picked.files.first
          : null;
      if (f?.bytes == null) return null;
      bytes = f!.bytes!;
      filename = f.name;
      mime = mimeForFilename(f.name);
    } else {
      final shot = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 82,
      );
      if (shot == null) return null;
      bytes = await shot.readAsBytes();
      filename = 'doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
  } catch (_) {
    if (context.mounted) {
      AppFeedback.show("Unable to open the item. Check the app's permissions.",
          context: context, tone: FeedbackTone.error);
    }
    return null;
  }

  if (!context.mounted || documentUploading.value) return null;
  documentUploading.value = true;
  try {
    // DocumentEvents.bump() inside refreshes any open My documents list.
    final r = await ApiService.uploadDocumentDetailed(
        bytes: bytes, filename: filename, mimeType: mime);
    if (context.mounted) {
      AppFeedback.show(
          r.notice ?? '"${r.document.title}" saved. Ask your assistant about it at any time.',
          context: context);
    }
    return r.document;
  } on DocumentUploadException catch (e) {
    if (context.mounted) {
      AppFeedback.show(
          e.message.isNotEmpty
              ? "Unable to upload the document: ${e.message}"
              : "Unable to upload the document. Nothing was saved.",
          context: context,
          tone: FeedbackTone.error);
    }
  } catch (_) {
    if (context.mounted) {
      AppFeedback.show(
          "Unable to upload the document. Check your connection and try again.",
          context: context,
          tone: FeedbackTone.error);
    }
  } finally {
    documentUploading.value = false;
  }
  return null;
}

/// A chat for questions about saved documents, answered by the Documents
/// Assistant, which knows every file in [docs] (owner, 2026-11-17).
void askAboutDocuments(BuildContext context, {List<UserDocument>? docs}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProChatScreen(
            // kind only picks a banner photo, which the chat never shows.
            profile: const ProProfile(
                ProKind.business,
                'Documents',
                Icons.description_rounded,
                'Ask any question about your saved documents.',
                []),
            role: documentsRoleFor(docs),
          )));
}

/// MY DOCUMENTS — the user's OWN documents: scans, shared-in files, IDs,
/// receipts. Strictly the personal area: anything filed under a client or
/// patient lives in that case file (Clients & patients) and is never
/// listed here. Reads straight from the account, so it is identical after
/// a reinstall; the only way something leaves is an explicit delete.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<UserDocument>? _docs; // null = loading
  String? _error;
  int _seenVersion = DocumentEvents.version.value;

  @override
  void initState() {
    super.initState();
    DocumentEvents.version.addListener(_onDocumentsChanged);
    _load();
  }

  @override
  void dispose() {
    DocumentEvents.version.removeListener(_onDocumentsChanged);
    super.dispose();
  }

  void _onDocumentsChanged() {
    if (DocumentEvents.version.value == _seenVersion) return;
    _seenVersion = DocumentEvents.version.value;
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.fetchDocuments();
      if (!mounted) return;
      setState(() {
        _docs = d;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      // Already loaded: keep the list and say the refresh missed.
      if (_docs != null) {
        AppFeedback.show("Unable to refresh. Please try again.",
            context: context, tone: FeedbackTone.error);
        return;
      }
      setState(() => _error = "Unable to load your documents.");
    }
  }

  /// Deletes on the server first; the list only changes once it confirmed.
  Future<bool> _delete(UserDocument d) async {
    final ok = await confirmDeleteDocument(context, d, where: 'My Documents');
    if (!ok || !mounted) return false;
    try {
      await ApiService.deleteDocument(d.id);
      if (!mounted) return true;
      setState(() =>
          _docs = _docs?.where((x) => x.id != d.id).toList(growable: false));
      _seenVersion = DocumentEvents.version.value; // our own bump
      return true;
    } catch (_) {
      if (mounted) {
        AppFeedback.show("Unable to delete. Check your connection and try again.", context: context);
      }
      return false;
    }
  }

  void _open(UserDocument d) =>
      openDocument(context, d, within: _docs, onDelete: _delete);

  @override
  Widget build(BuildContext context) {
    final docs = _docs;
    // 2026-09-30: under the app's sky; loading, empty and the grid
    // replace one another softly.
    return NeonScaffold(
      // The mic and chat moved down beside Upload, as one dock
      // (owner, 2026-11-17).
      appBar: appleAppBar(context, 'My Documents'),
      body: StateSwitch.of(_body(docs)),
      bottomNavigationBar: _DocumentsDock(docs: docs),
    );
  }

  /// Policies, licences and passports running out within two months (or
  /// already lapsed), soonest first. Their reminders are already set.
  List<UserDocument> _renewals(List<UserDocument> docs) {
    final due = docs
        .where((d) => (d.daysToExpiry() ?? 999) <= 60)
        .toList()
      ..sort((a, b) => a.daysToExpiry()!.compareTo(b.daysToExpiry()!));
    return due;
  }

  /// What is running out: the screen's one lit card, in the warning tone
  /// (2026-09-30). Each line opens its document.
  Widget _renewalsCard(List<UserDocument> docs) {
    final due = _renewals(docs);
    return GlowCard(
      tone: NeonTone.warning,
      radius: Neon.rMd,
      rimWidth: 1.6,
      halo: 0.5,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.autorenew_rounded, size: 18, color: Neon.warning),
            const SizedBox(width: 8),
            Text(due.length == 1 ? '1 renewal due soon' : '${due.length} renewals due soon',
                style: TextStyle(
                    color: Neon.textHi,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 2),
          Text("You will be reminded 30 days and 7 days before, and on the day.",
              style: TextStyle(color: Neon.textLo, fontSize: 12)),
          const SizedBox(height: 6),
          for (final d in due.take(4))
            Tappable(
              onTap: () => _open(d),
              scale: 0.985,
              // 48 dp to the finger: a 13 sp line was a 30 dp target.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(children: [
                  Expanded(
                    child: Text(d.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Neon.textHi, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  // Bounded (2026-09-30): the badge's own Row flexes its
                  // words, which an unbounded slot here cannot allow.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: IntrinsicWidth(child: ExpiryBadge(document: d)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(List<UserDocument>? docs) {
    if (_error != null) {
      return NeonErrorState(
        message: _error!,
        onRetry: () {
          setState(() {
            _error = null;
            _docs = null;
          });
          _load();
        },
      );
    }
    if (docs == null) return const NeonLoader.page();
    if (docs.isEmpty) {
      return RefreshIndicator(
        color: Neon.violet,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // The user's own photo, used across the app (2026-11-16).
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: MyPhotoCard(),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: const NeonEmptyState(
                icon: Icons.description_outlined,
                title: 'No files uploaded yet',
                body: 'Keep your important files in one secure place. Tap '
                    'Add a Document, share a file into the app, or ask your '
                    'assistant to save one. Files filed under a client or '
                    'patient appear in their case file.',
              ),
            ),
          ],
        ),
      );
    }
    final width = MediaQuery.of(context).size.width;
    // 2026-09-30 visual QA: two across on a phone. At three (≈114 dp a
    // tile) the neon type cut every date and expiry to "12 Sep 20…" and
    // "Expires in 3…", and a two-line title shrank its thumbnail out of
    // line with its neighbours.
    final columns = width >= 900 ? 5 : width >= 600 ? 4 : width >= 440 ? 3 : 2;
    return RefreshIndicator(
      color: Neon.violet,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // The user's own photo, used across the app (2026-11-16).
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
            sliver: SliverToBoxAdapter(child: MyPhotoCard()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            sliver: SliverToBoxAdapter(
              child: Text(
                docs.length == 1 ? '1 document' : '${docs.length} documents',
                style: TextStyle(color: Neon.textLo, fontSize: 13),
              ),
            ),
          ),
          if (_renewals(docs).isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              sliver: SliverToBoxAdapter(child: _renewalsCard(docs)),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: columns == 2 ? 0.95 : 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final d = docs[i];
                  return DocumentGridTile(
                    document: d,
                    onOpen: () => _open(d),
                    onLongPress: () => showDocumentActions(
                      context,
                      d,
                      onOpen: () => _open(d),
                      onDelete: () => _delete(d),
                    ),
                  );
                },
                childCount: docs.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Who the mic orb on My documents talks as, before the list has loaded.
const documentsRole = AssistantRole(
    'the Documents Assistant',
    'You help the owner with their saved documents: finding, reading and '
        'explaining them, and the renewals coming up.');

/// THE DOCUMENTS ASSISTANT, WITH THE WHOLE SHELF IN MIND (owner,
/// 2026-11-17: "should have full context about the documents stored and
/// when asked to show them immediately"). Every saved file, with its type,
/// dates and summary, goes into the role, so the assistant answers what is
/// stored without searching first, and opens a file the moment it is asked
/// to show one. The files themselves stay on the server; only this
/// description travels with the conversation.
AssistantRole documentsRoleFor(List<UserDocument>? docs) {
  if (docs == null) return documentsRole;
  final b = StringBuffer(
      'You help the owner with their saved documents: finding, reading and '
      'explaining them, and the renewals coming up. ');
  if (docs.isEmpty) {
    b.write('No documents were saved when this conversation started. If the '
        'owner asks for one, call find_document first (it may have just been '
        'added); only if nothing is found, say so and tell them to tap Add a '
        'Document at the bottom of this page.');
    return AssistantRole('the Documents Assistant', b.toString());
  }
  // A SNAPSHOT, NOT THE TRUTH (owner, 2026-11-21: "open my PAN card" was
  // refused because the PAN card was uploaded after this list was taken).
  // The list answers "what do I have?" quickly; whether a named document
  // exists is always settled by find_document, which reads the account.
  b.write("These are the ${docs.length} documents that were saved on the "
      "owner's account when this conversation started, newest first. Answer "
      'general questions about what is stored from this list. The owner may '
      'have added files since, so this list may be incomplete. ');
  b.write('When the owner asks to see, show, open or pull up a document, '
      'call find_document AT ONCE with its exact title as the query and '
      'show true, so it opens on their screen immediately. Do not ask which '
      'one unless two documents match equally. To answer a question about '
      'what a document SAYS, call find_document with show false and read '
      'it. If the owner names a document that is NOT on this list, call '
      'find_document anyway before answering: it may have just been added. '
      'Only say a document is not saved after find_document found nothing.\n');
  var budget = 7000;
  for (final d in docs) {
    final parts = <String>[
      if (d.category.isNotEmpty) d.category,
      if (d.docDate.isNotEmpty) 'dated ${d.docDate}',
      if (d.expiresOn.isNotEmpty) 'expires ${d.expiresOn}',
      'saved ${_ymd(d.createdAt)}',
    ];
    var summary = d.summary.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (summary.length > 180) summary = '${summary.substring(0, 177)}...';
    final note = d.note.trim();
    final line = '- "${d.title}" (${parts.join(', ')})'
        '${summary.isEmpty ? '' : ': $summary'}'
        "${note.isEmpty ? '' : " Owner's note: $note"}\n";
    if (line.length > budget) {
      b.write('- ...and ${docs.length - docs.indexOf(d)} more; use '
          'search_documents for those.\n');
      break;
    }
    budget -= line.length;
    b.write(line);
  }
  return AssistantRole('the Documents Assistant', b.toString());
}

String _ymd(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// THE DOCUMENTS DOCK (owner, 2026-11-17: "bring them to bottom, make them
/// as one group"): the Documents Assistant's mic, the chat about your files
/// and Add a Document, together on one glass card at the foot of
/// the page.
class _DocumentsDock extends StatelessWidget {
  const _DocumentsDock({required this.docs});

  /// What is saved, so the mic and the chat know every file.
  final List<UserDocument>? docs;

  @override
  Widget build(BuildContext context) {
    final c = Neon.violet;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: Color.alphaBlend(c.withValues(alpha: 0.10),
                Color.lerp(Neon.bg, Colors.black, Neon.isDark ? 0.3 : 0)!)
                .withValues(alpha: 0.94),
            border: Border.all(color: c.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
              BoxShadow(
                  color: c.withValues(alpha: 0.18),
                  blurRadius: 30,
                  spreadRadius: -6),
            ],
          ),
          child: Row(
            children: [
              RoleMicOrb(
                  role: documentsRoleFor(docs),
                  tint: c,
                  size: 44,
                  labelColor: Neon.textLo),
              const SizedBox(width: 12),
              _ChatButton(tint: c, docs: docs),
              Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Neon.textHi.withValues(alpha: 0.10),
              ),
              const Expanded(child: _UploadButton()),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Type to ask": the chat about your files, a pair to the mic beside it.
class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.tint, required this.docs});
  final Color tint;
  final List<UserDocument>? docs;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: () => askAboutDocuments(context, docs: docs),
      semanticLabel: 'Ask About Your Documents in chat',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.35),
              border: Border.all(
                  color: tint.withValues(alpha: 0.7), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: tint.withValues(alpha: 0.35), blurRadius: 14),
              ],
            ),
            child: Icon(Icons.forum_rounded, size: 20, color: Neon.textHi),
          ),
          const SizedBox(height: 6),
          Text('Type to ask',
              style: TextStyle(
                  color: Neon.textLo,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// The page's main action: a standard filled button, one line, icon and
/// label (owner, 2026-11-17: "very standard" design).
class _UploadButton extends StatelessWidget {
  const _UploadButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: documentUploading,
      builder: (context, busy, _) => SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: busy ? null : () => uploadMyDocument(context),
          style: FilledButton.styleFrom(
            backgroundColor: Neon.accentFill,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Neon.accentFill.withValues(alpha: 0.55),
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            textStyle: NeonType.manrope(14.5, FontWeight.w700),
          ),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.add_rounded, size: 22),
          label: Text(busy ? 'Uploading…' : 'Add a Document',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
