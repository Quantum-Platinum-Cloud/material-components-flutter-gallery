// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:gallery/l10n/gallery_localizations.dart';

enum DialogDemoType {
  alert,
  alertTitle,
  simple,
  fullscreen,
}

class DialogDemo extends StatelessWidget {
  DialogDemo({Key key, @required this.type}) : super(key: key);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DialogDemoType type;

  String _title(BuildContext context) {
    switch (type) {
      case DialogDemoType.alert:
        return GalleryLocalizations.of(context).demoAlertDialogTitle;
      case DialogDemoType.alertTitle:
        return GalleryLocalizations.of(context).demoAlertTitleDialogTitle;
      case DialogDemoType.simple:
        return GalleryLocalizations.of(context).demoSimpleDialogTitle;
      case DialogDemoType.fullscreen:
        return GalleryLocalizations.of(context).demoFullscreenDialogTitle;
    }
    return '';
  }

  Future<void> _showDemoDialog<T>({BuildContext context, Widget child}) async {
    child = Theme(
      data: Theme.of(context),
      child: child,
    );
    T value = await showDialog<T>(
      context: context,
      builder: (context) => child,
    );
    // The value passed to Navigator.pop() or null.
    if (value != null && value is String) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content:
            Text(GalleryLocalizations.of(context).dialogSelectedOption(value)),
      ));
    }
  }

  void _showAlertDialog(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle dialogTextStyle =
        theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);
    _showDemoDialog<String>(
      context: context,
      child: AlertDialog(
        content: Text(
          GalleryLocalizations.of(context).dialogDiscardTitle,
          style: dialogTextStyle,
        ),
        actions: [
          _DialogButton(text: GalleryLocalizations.of(context).dialogCancel),
          _DialogButton(text: GalleryLocalizations.of(context).dialogDiscard),
        ],
      ),
    );
  }

  void _showAlertDialogWithTitle(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle dialogTextStyle =
        theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);
    _showDemoDialog<String>(
      context: context,
      child: AlertDialog(
        title: Text(GalleryLocalizations.of(context).dialogLocationTitle),
        content: Text(
          GalleryLocalizations.of(context).dialogLocationDescription,
          style: dialogTextStyle,
        ),
        actions: [
          _DialogButton(text: GalleryLocalizations.of(context).dialogDisagree),
          _DialogButton(text: GalleryLocalizations.of(context).dialogAgree),
        ],
      ),
    );
  }

  void _showSimpleDialog(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    _showDemoDialog<String>(
      context: context,
      child: SimpleDialog(
        title: Text(GalleryLocalizations.of(context).dialogSetBackup),
        children: [
          _DialogDemoItem(
            icon: Icons.account_circle,
            color: theme.colorScheme.primary,
            text: 'username@gmail.com',
          ),
          _DialogDemoItem(
            icon: Icons.account_circle,
            color: theme.colorScheme.secondary,
            text: 'user02@gmail.com',
          ),
          _DialogDemoItem(
            icon: Icons.add_circle,
            text: GalleryLocalizations.of(context).dialogAddAccount,
            color: theme.disabledColor,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_title(context)),
      ),
      body: Center(
        child: RaisedButton(
          child: Text(GalleryLocalizations.of(context).dialogShow),
          onPressed: () {
            switch (type) {
              case DialogDemoType.alert:
                _showAlertDialog(context);
                break;
              case DialogDemoType.alertTitle:
                _showAlertDialogWithTitle(context);
                break;
              case DialogDemoType.simple:
                _showSimpleDialog(context);
                break;
              case DialogDemoType.fullscreen:
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _FullScreenDialogDemo(),
                    fullscreenDialog: true,
                  ),
                );
                break;
            }
          },
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({Key key, this.text}) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FlatButton(
      child: Text(text),
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop(text);
      },
    );
  }
}

class _DialogDemoItem extends StatelessWidget {
  const _DialogDemoItem({
    Key key,
    this.icon,
    this.color,
    this.text,
  }) : super(key: key);

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop(text);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: color),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: Text(text),
          ),
        ],
      ),
    );
  }
}

class _FullScreenDialogDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return MediaQuery(
      data: MediaQueryData(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(GalleryLocalizations.of(context).dialogFullscreenTitle),
          actions: [
            FlatButton(
              child: Text(
                GalleryLocalizations.of(context).dialogFullscreenSave,
                style: theme.textTheme.body1.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
        body: Center(
          child: Text(
            GalleryLocalizations.of(context).dialogFullscreenDescription,
          ),
        ),
      ),
    );
  }
}
