import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/db/db_helper.dart';
import 'package:photos/events/remote_sync_event.dart';
import 'package:photos/models/photo.dart';
import 'package:photos/photo_loader.dart';
import 'package:photos/ui/setup_page.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/utils/share_util.dart';

class GalleryAppBarWidget extends StatefulWidget
    implements PreferredSizeWidget {
  final String title;
  final Set<Photo> selectedPhotos;
  final Function() onSelectionClear;
  final Function(List<Photo>) onPhotosDeleted;

  GalleryAppBarWidget(this.title, this.selectedPhotos,
      {this.onSelectionClear, this.onPhotosDeleted});

  @override
  _GalleryAppBarWidgetState createState() => _GalleryAppBarWidgetState();

  @override
  Size get preferredSize => Size.fromHeight(60.0);
}

class _GalleryAppBarWidgetState extends State<GalleryAppBarWidget> {
  bool _hasSyncErrors = false;

  @override
  void initState() {
    Bus.instance.on<RemoteSyncEvent>().listen((event) {
      setState(() {
        _hasSyncErrors = !event.success;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedPhotos.isEmpty) {
      return AppBar(
        title: Text(widget.title),
        actions: _getDefaultActions(context),
      );
    }

    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.close),
        onPressed: () {
          _clearSelectedPhotos();
        },
      ),
      title: Text(widget.selectedPhotos.length.toString()),
      actions: _getPhotoActions(context),
    );
  }

  List<Widget> _getDefaultActions(BuildContext context) {
    List<Widget> actions = List<Widget>();
    if (_hasSyncErrors) {
      actions.add(IconButton(
        icon: Icon(Icons.sync_problem),
        onPressed: () {
          _openSyncConfiguration(context);
        },
      ));
    }
    return actions;
  }

  List<Widget> _getPhotoActions(BuildContext context) {
    List<Widget> actions = List<Widget>();
    if (widget.selectedPhotos.isNotEmpty) {
      actions.add(IconButton(
        icon: Icon(Icons.delete),
        onPressed: () {
          _showDeletePhotosSheet(context);
        },
      ));
      actions.add(IconButton(
        icon: Icon(Icons.share),
        onPressed: () {
          _shareSelectedPhotos(context);
        },
      ));
    }
    return actions;
  }

  void _shareSelectedPhotos(BuildContext context) {
    shareMultiple(widget.selectedPhotos.toList());
  }

  void _showDeletePhotosSheet(BuildContext context) {
    final action = CupertinoActionSheet(
      actions: <Widget>[
        CupertinoActionSheetAction(
          child: Text("Delete on device"),
          isDestructiveAction: true,
          onPressed: () async {
            await _deleteSelectedPhotos(context, false);
          },
        ),
        CupertinoActionSheetAction(
          child: Text("Delete everywhere [WiP]"),
          isDestructiveAction: true,
          onPressed: () async {
            await _deleteSelectedPhotos(context, true);
          },
        )
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text("Cancel"),
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (_) => action);
  }

  Future _deleteSelectedPhotos(
      BuildContext context, bool deleteEverywhere) async {
    await PhotoManager.editor
        .deleteWithIds(widget.selectedPhotos.map((p) => p.localId).toList());

    for (Photo photo in widget.selectedPhotos) {
      deleteEverywhere
          ? await DatabaseHelper.instance.markPhotoForDeletion(photo)
          : await DatabaseHelper.instance.deletePhoto(photo);
    }
    Navigator.of(context, rootNavigator: true).pop();
    PhotoLoader.instance.reloadPhotos();
    if (widget.onPhotosDeleted != null) {
      widget.onPhotosDeleted(widget.selectedPhotos.toList());
    }
    _clearSelectedPhotos();
  }

  void _clearSelectedPhotos() {
    setState(() {
      widget.selectedPhotos.clear();
    });
    if (widget.onSelectionClear != null) {
      widget.onSelectionClear();
    }
  }

  void _openSyncConfiguration(BuildContext context) {
    final page = SetupPage();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: "/setup"),
        builder: (BuildContext context) {
          return page;
        },
      ),
    );
  }
}
