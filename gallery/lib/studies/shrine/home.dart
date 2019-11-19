// Copyright 2018-present the Flutter authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:gallery/layout/adaptive.dart';
import 'package:gallery/studies/shrine/expanding_bottom_sheet.dart';
import 'package:gallery/studies/shrine/model/app_state_model.dart';
import 'package:gallery/studies/shrine/supplemental/asymmetric_view.dart';

class ProductPage extends StatelessWidget {
  const ProductPage();

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = isDisplayDesktop(context);

    return ScopedModelDescendant<AppStateModel>(
        builder: (context, child, model) {
      return isDesktop
          ? DesktopAsymmetricView(products: model.getProducts())
          : MobileAsymmetricView(products: model.getProducts());
    });
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    this.expandingBottomSheet,
    this.scrim,
    this.backdrop,
    Key key,
  }) : super(key: key);

  final ExpandingBottomSheet expandingBottomSheet;
  final Widget scrim;
  final Widget backdrop;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = isDisplayDesktop(context);

    return Stack(
      children: [
        backdrop,
        scrim,
        Align(
          child: expandingBottomSheet,
          alignment: isDesktop ? Alignment.topRight : Alignment.bottomRight,
        ),
      ],
    );
  }
}
