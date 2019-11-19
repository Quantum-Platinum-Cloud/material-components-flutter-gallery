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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:gallery/layout/adaptive.dart';
import 'package:gallery/studies/shrine/colors.dart';
import 'package:gallery/studies/shrine/model/app_state_model.dart';
import 'package:gallery/studies/shrine/model/product.dart';
import 'package:gallery/studies/shrine/shopping_cart.dart';

// These curves define the emphasized easing curve.
const Cubic _accelerateCurve = Cubic(0.548, 0, 0.757, 0.464);
const Cubic _decelerateCurve = Cubic(0.23, 0.94, 0.41, 1);
// The time at which the accelerate and decelerate curves switch off
const _peakVelocityTime = 0.248210;
// Percent (as a decimal) of animation that should be completed at _peakVelocityTime
const _peakVelocityProgress = 0.379146;
const _cartHeight = 56.0;
// Radius of the shape on the top left of the sheet for mobile layouts.
const _mobileCornerRadius = 24.0;
// Radius of the shape on the top left and bottom left of the sheet for mobile layouts.
const _desktopCornerRadius = 12.0;
// Width for just the cart icon and no thumbnails.
const _widthForCartIcon = 64.0;
// Height of a thumbnail.
const _thumbnailHeight = 40.0;
// Gap between thumbnails.
const _thumbnailGap = 16.0;

class ExpandingBottomSheet extends StatefulWidget {
  const ExpandingBottomSheet(
      {Key key,
      @required this.hideController,
      @required this.expandingController})
      : assert(hideController != null),
        assert(expandingController != null),
        super(key: key);

  final AnimationController hideController;
  final AnimationController expandingController;

  @override
  _ExpandingBottomSheetState createState() => _ExpandingBottomSheetState();

  static _ExpandingBottomSheetState of(BuildContext context,
      {bool isNullOk = false}) {
    assert(isNullOk != null);
    assert(context != null);
    final _ExpandingBottomSheetState result = context.ancestorStateOfType(
            const TypeMatcher<_ExpandingBottomSheetState>())
        as _ExpandingBottomSheetState;
    if (isNullOk || result != null) {
      return result;
    }
    throw FlutterError(
        'ExpandingBottomSheet.of() called with a context that does not contain a ExpandingBottomSheet.\n');
  }
}

// Emphasized Easing is a motion curve that has an organic, exciting feeling.
// It's very fast to begin with and then very slow to finish. Unlike standard
// curves, like [Curves.fastOutSlowIn], it can't be expressed in a cubic bezier
// curve formula. It's quintic, not cubic. But it _can_ be expressed as one
// curve followed by another, which we do here.
Animation<T> _getEmphasizedEasingAnimation<T>({
  @required T begin,
  @required T peak,
  @required T end,
  @required bool isForward,
  @required Animation<double> parent,
}) {
  Curve firstCurve;
  Curve secondCurve;
  double firstWeight;
  double secondWeight;

  if (isForward) {
    firstCurve = _accelerateCurve;
    secondCurve = _decelerateCurve;
    firstWeight = _peakVelocityTime;
    secondWeight = 1 - _peakVelocityTime;
  } else {
    firstCurve = _decelerateCurve.flipped;
    secondCurve = _accelerateCurve.flipped;
    firstWeight = 1 - _peakVelocityTime;
    secondWeight = _peakVelocityTime;
  }

  return TweenSequence<T>(
    [
      TweenSequenceItem<T>(
        weight: firstWeight,
        tween: Tween<T>(
          begin: begin,
          end: peak,
        ).chain(CurveTween(curve: firstCurve)),
      ),
      TweenSequenceItem<T>(
        weight: secondWeight,
        tween: Tween<T>(
          begin: peak,
          end: end,
        ).chain(CurveTween(curve: secondCurve)),
      ),
    ],
  ).animate(parent);
}

// Calculates the value where two double Animations should be joined. Used by
// callers of _getEmphasisedEasing<double>().
double _getPeakPoint({double begin, double end}) {
  return begin + (end - begin) * _peakVelocityProgress;
}

class _ExpandingBottomSheetState extends State<ExpandingBottomSheet>
    with TickerProviderStateMixin {
  final GlobalKey _expandingBottomSheetKey =
      GlobalKey(debugLabel: 'Expanding bottom sheet');

  // The width of the Material, calculated by _widthFor() & based on the number
  // of products in the cart. 64.0 is the width when there are 0 products
  // (_kWidthForZeroProducts)
  double _width = _widthForCartIcon;
  double _height = _cartHeight;

  // Controller for the opening and closing of the ExpandingBottomSheet
  AnimationController get _controller => widget.expandingController;

  // Animations for the opening and closing of the ExpandingBottomSheet
  Animation<double> _widthAnimation;
  Animation<double> _heightAnimation;
  Animation<double> _thumbnailOpacityAnimation;
  Animation<double> _cartOpacityAnimation;
  Animation<double> _topLeftShapeAnimation;
  Animation<double> _bottomLeftShapeAnimation;
  Animation<Offset> _slideAnimation;
  Animation<double> _gapAnimation;

  Animation<double> _getWidthAnimation(double screenWidth) {
    if (_controller.status == AnimationStatus.forward) {
      // Opening animation
      return Tween<double>(begin: _width, end: screenWidth).animate(
        CurvedAnimation(
          parent: _controller.view,
          curve: const Interval(0, 0.3, curve: Curves.fastOutSlowIn),
        ),
      );
    } else {
      // Closing animation
      return _getEmphasizedEasingAnimation(
        begin: _width,
        peak: _getPeakPoint(begin: _width, end: screenWidth),
        end: screenWidth,
        isForward: false,
        parent: CurvedAnimation(
            parent: _controller.view, curve: const Interval(0, 0.87)),
      );
    }
  }

  Animation<double> _getHeightAnimation(double screenHeight) {
    if (_controller.status == AnimationStatus.forward) {
      // Opening animation

      return _getEmphasizedEasingAnimation(
        begin: _height,
        peak: _getPeakPoint(begin: _height, end: screenHeight),
        end: screenHeight,
        isForward: true,
        parent: _controller.view,
      );
    } else {
      // Closing animation
      return Tween<double>(
        begin: _height,
        end: screenHeight,
      ).animate(
        CurvedAnimation(
          parent: _controller.view,
          curve: const Interval(0.434, 1, curve: Curves.linear), // not used
          // only the reverseCurve will be used
          reverseCurve: Interval(0.434, 1, curve: Curves.fastOutSlowIn.flipped),
        ),
      );
    }
  }

  Animation<double> _getDesktopGapAnimation(double gapHeight) {
    final double _collapsedGapHeight = gapHeight;
    final double _expandedGapHeight = 0;

    if (_controller.status == AnimationStatus.forward) {
      // Opening animation

      return _getEmphasizedEasingAnimation(
        begin: _collapsedGapHeight,
        peak: _collapsedGapHeight +
            (_expandedGapHeight - _collapsedGapHeight) * _peakVelocityProgress,
        end: _expandedGapHeight,
        isForward: true,
        parent: _controller.view,
      );
    } else {
      // Closing animation
      return Tween<double>(
        begin: _collapsedGapHeight,
        end: _expandedGapHeight,
      ).animate(
        CurvedAnimation(
          parent: _controller.view,
          curve: const Interval(0.434, 1), // not used
          // only the reverseCurve will be used
          reverseCurve: Interval(0.434, 1, curve: Curves.fastOutSlowIn.flipped),
        ),
      );
    }
  }

  // Animation of the top-left cut corner. It's cut when closed and not cut when open.
  Animation<double> _getShapeTopLeftAnimation(BuildContext context) {
    final bool isDesktop = isDisplayDesktop(context);

    final double cornerRadius =
        isDesktop ? _desktopCornerRadius : _mobileCornerRadius;

    if (_controller.status == AnimationStatus.forward) {
      return Tween<double>(begin: cornerRadius, end: 0).animate(
        CurvedAnimation(
          parent: _controller.view,
          curve: const Interval(0, 0.3, curve: Curves.fastOutSlowIn),
        ),
      );
    } else {
      return _getEmphasizedEasingAnimation(
        begin: cornerRadius,
        peak: _getPeakPoint(begin: cornerRadius, end: 0),
        end: 0,
        isForward: false,
        parent: _controller.view,
      );
    }
  }

  // Animation of the bottom-left cut corner. It's cut when closed and not cut when open.
  Animation<double> _getShapeBottomLeftAnimation(BuildContext context) {
    final bool isDesktop = isDisplayDesktop(context);

    final double cornerRadius = isDesktop ? _desktopCornerRadius : 0;

    if (_controller.status == AnimationStatus.forward) {
      return Tween<double>(begin: cornerRadius, end: 0).animate(
        CurvedAnimation(
          parent: _controller.view,
          curve: const Interval(0, 0.3, curve: Curves.fastOutSlowIn),
        ),
      );
    } else {
      return _getEmphasizedEasingAnimation(
        begin: cornerRadius,
        peak: _getPeakPoint(begin: cornerRadius, end: 0),
        end: 0,
        isForward: false,
        parent: _controller.view,
      );
    }
  }

  Animation<double> _getThumbnailOpacityAnimation() {
    return Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller.view,
        curve: _controller.status == AnimationStatus.forward
            ? const Interval(0, 0.3)
            : const Interval(0.532, 0.766),
      ),
    );
  }

  Animation<double> _getCartOpacityAnimation() {
    return CurvedAnimation(
      parent: _controller.view,
      curve: _controller.status == AnimationStatus.forward
          ? const Interval(0.3, 0.6)
          : const Interval(0.766, 1),
    );
  }

  // Returns the correct width of the ExpandingBottomSheet based on the number of
  // products in the cart.
  double _widthFor(int numProducts) {
    final widths = <double>[_widthForCartIcon, 136, 192, 248];
    return numProducts >= widths.length ? 278 : widths[numProducts];
  }

  // Returns the correct height of the ExpandingBottomSheet based on the number of
  // products in the cart.
  double _heightFor(int numProducts) {
    final heights = <double>[_cartHeight, 120, 176, 232];
    return numProducts >= heights.length ? 260 : heights[numProducts];
  }

  // Returns true if the cart is open or opening and false otherwise.
  bool get _isOpen {
    final AnimationStatus status = _controller.status;
    return status == AnimationStatus.completed ||
        status == AnimationStatus.forward;
  }

  // Opens the ExpandingBottomSheet if it's closed, otherwise does nothing.
  void open() {
    if (!_isOpen) {
      _controller.forward();
    }
  }

  // Closes the ExpandingBottomSheet if it's open or opening, otherwise does nothing.
  void close() {
    if (_isOpen) {
      _controller.reverse();
    }
  }

  // Changes the padding between the start edge of the Material and the cart icon
  // based on the number of products in the cart (padding increases when > 0
  // products.)
  EdgeInsetsDirectional _horizontalCartPaddingFor(int numProducts) {
    return (numProducts == 0)
        ? const EdgeInsetsDirectional.only(start: 20, end: 8)
        : const EdgeInsetsDirectional.only(start: 32, end: 8);
  }

  // Changes the padding above and below the cart icon
  // based on the number of products in the cart (padding increases when > 0
  // products.)
  EdgeInsets _verticalCartPaddingFor(int numProducts) {
    return (numProducts == 0)
        ? const EdgeInsets.only(top: 16, bottom: 16)
        : const EdgeInsets.only(top: 16, bottom: 24);
  }

  bool get _cartIsVisible => _thumbnailOpacityAnimation.value == 0;

  Widget _buildThumbnails(BuildContext context, int numProducts) {
    final bool isDesktop = isDisplayDesktop(context);

    Widget thumbnails;

    if (isDesktop) {
      thumbnails = Column(
        children: [
          AnimatedPadding(
            padding: _verticalCartPaddingFor(numProducts),
            child: const Icon(Icons.shopping_cart),
            duration: const Duration(milliseconds: 225),
          ),
          Container(
            width: _width,
            height: (numProducts >= 3 ? 3 : numProducts) *
                (_thumbnailHeight + _thumbnailGap),
            child: ProductThumbnailRow(),
          ),
          ExtraProductsNumber(),
        ],
      );
    } else {
      thumbnails = Column(
        children: [
          Row(
            children: [
              AnimatedPadding(
                padding: _horizontalCartPaddingFor(numProducts),
                child: const Icon(Icons.shopping_cart),
                duration: const Duration(milliseconds: 225),
              ),
              Container(
                // Accounts for the overflow number
                width: numProducts > 3 ? _width - 94 : _width - 64,
                height: _cartHeight,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ProductThumbnailRow(),
              ),
              ExtraProductsNumber(),
            ],
          ),
        ],
      );
    }

    return ExcludeSemantics(
      child: Opacity(
        opacity: _thumbnailOpacityAnimation.value,
        child: thumbnails,
      ),
    );
  }

  Widget _buildShoppingCartPage() {
    return Opacity(
      opacity: _cartOpacityAnimation.value,
      child: ShoppingCartPage(),
    );
  }

  Widget _buildCart(BuildContext context, Widget child) {
    // numProducts is the number of different products in the cart (does not
    // include multiples of the same product).
    final bool isDesktop = isDisplayDesktop(context);

    final AppStateModel model = ScopedModel.of<AppStateModel>(context);
    final int numProducts = model.productsInCart.keys.length;
    final int totalCartQuantity = model.totalCartQuantity;
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    final double expandedCartWidth = isDesktop ? 360 : screenWidth;

    _width = isDesktop ? _widthForCartIcon : _widthFor(numProducts);
    _widthAnimation = _getWidthAnimation(expandedCartWidth);
    _height = isDesktop ? _heightFor(numProducts) : _cartHeight;
    _heightAnimation = _getHeightAnimation(screenHeight);
    _topLeftShapeAnimation = _getShapeTopLeftAnimation(context);
    _bottomLeftShapeAnimation = _getShapeBottomLeftAnimation(context);
    _thumbnailOpacityAnimation = _getThumbnailOpacityAnimation();
    _cartOpacityAnimation = _getCartOpacityAnimation();
    _gapAnimation =
        isDesktop ? _getDesktopGapAnimation(116) : AlwaysStoppedAnimation(0);

    return Padding(
      padding: EdgeInsets.only(top: _gapAnimation.value),
      child: Semantics(
        button: true,
        value: 'Shopping cart, $totalCartQuantity items',
        child: Container(
          width: _widthAnimation.value,
          height: _heightAnimation.value,
          child: Material(
            animationDuration: const Duration(milliseconds: 0),
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(_topLeftShapeAnimation.value),
                bottomLeft: Radius.circular(_bottomLeftShapeAnimation.value),
              ),
            ),
            elevation: 4,
            color: shrinePink50,
            child: _cartIsVisible
                ? _buildShoppingCartPage()
                : _buildThumbnails(context, numProducts),
          ),
        ),
      ),
    );
  }

  // Builder for the hide and reveal animation when the backdrop opens and closes
  Widget _buildSlideAnimation(BuildContext context, Widget child) {
    final bool isDesktop = isDisplayDesktop(context);

    if (isDesktop) {
      return child;
    } else {
      _slideAnimation = _getEmphasizedEasingAnimation(
        begin: const Offset(1, 0),
        peak: const Offset(_peakVelocityProgress, 0),
        end: const Offset(0, 0),
        isForward: widget.hideController.status == AnimationStatus.forward,
        parent: widget.hideController,
      );

      return SlideTransition(
        position: _slideAnimation,
        child: child,
      );
    }
  }

  // Closes the cart if the cart is open, otherwise exits the app (this should
  // only be relevant for Android).
  Future<bool> _onWillPop() async {
    if (!_isOpen) {
      await SystemNavigator.pop();
      return true;
    }

    close();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      key: _expandingBottomSheetKey,
      duration: const Duration(milliseconds: 225),
      curve: Curves.easeInOut,
      vsync: this,
      alignment: FractionalOffset.topLeft,
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: AnimatedBuilder(
          animation: widget.hideController,
          builder: _buildSlideAnimation,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: open,
            child: ScopedModelDescendant<AppStateModel>(
              builder: (context, child, model) {
                return AnimatedBuilder(
                  builder: _buildCart,
                  animation: _controller,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ProductThumbnailRow extends StatefulWidget {
  @override
  _ProductThumbnailRowState createState() => _ProductThumbnailRowState();
}

class _ProductThumbnailRowState extends State<ProductThumbnailRow> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // _list represents what's currently on screen. If _internalList updates,
  // it will need to be updated to match it.
  _ListModel _list;

  // _internalList represents the list as it is updated by the AppStateModel.
  List<int> _internalList;

  @override
  void initState() {
    super.initState();
    _list = _ListModel(
      listKey: _listKey,
      initialItems:
          ScopedModel.of<AppStateModel>(context).productsInCart.keys.toList(),
      removedItemBuilder: _buildRemovedThumbnail,
    );
    _internalList = List<int>.from(_list.list);
  }

  Product _productWithId(int productId) {
    final AppStateModel model = ScopedModel.of<AppStateModel>(context);
    final Product product = model.getProductById(productId);
    assert(product != null);
    return product;
  }

  Widget _buildRemovedThumbnail(
      int item, BuildContext context, Animation<double> animation) {
    return ProductThumbnail(animation, animation, _productWithId(item));
  }

  Widget _buildThumbnail(
      BuildContext context, int index, Animation<double> animation) {
    final Animation<double> thumbnailSize =
        Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        curve: const Interval(0.33, 1, curve: Curves.easeIn),
        parent: animation,
      ),
    );

    final Animation<double> opacity = CurvedAnimation(
      curve: const Interval(0.33, 1, curve: Curves.linear),
      parent: animation,
    );

    return ProductThumbnail(
        thumbnailSize, opacity, _productWithId(_list[index]));
  }

  // If the lists are the same length, assume nothing has changed.
  // If the internalList is shorter than the ListModel, an item has been removed.
  // If the internalList is longer, then an item has been added.
  void _updateLists() {
    // Update _internalList based on the model
    _internalList =
        ScopedModel.of<AppStateModel>(context).productsInCart.keys.toList();
    final Set<int> internalSet = Set<int>.from(_internalList);
    final Set<int> listSet = Set<int>.from(_list.list);

    final Set<int> difference = internalSet.difference(listSet);
    if (difference.isEmpty) {
      return;
    }

    for (int product in difference) {
      if (_internalList.length < _list.length) {
        _list.remove(product);
      } else if (_internalList.length > _list.length) {
        _list.add(product);
      }
    }

    while (_internalList.length != _list.length) {
      int index = 0;
      // Check bounds and that the list elements are the same
      while (_internalList.isNotEmpty &&
          _list.length > 0 &&
          index < _internalList.length &&
          index < _list.length &&
          _internalList[index] == _list[index]) {
        index++;
      }
    }
  }

  Widget _buildAnimatedList(BuildContext context) {
    final bool isDesktop = isDisplayDesktop(context);

    return AnimatedList(
      key: _listKey,
      shrinkWrap: true,
      itemBuilder: _buildThumbnail,
      initialItemCount: _list.length,
      scrollDirection: isDesktop ? Axis.vertical : Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), // Cart shouldn't scroll
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateLists();
    return ScopedModelDescendant<AppStateModel>(
      builder: (context, child, model) => _buildAnimatedList(context),
    );
  }
}

class ExtraProductsNumber extends StatelessWidget {
  // Calculates the number to be displayed at the end of the row if there are
  // more than three products in the cart. This calculates overflow products,
  // including their duplicates (but not duplicates of products shown as
  // thumbnails).
  int _calculateOverflow(AppStateModel model) {
    final Map<int, int> productMap = model.productsInCart;
    // List created to be able to access products by index instead of ID.
    // Order is guaranteed because productsInCart returns a LinkedHashMap.
    final List<int> products = productMap.keys.toList();
    int overflow = 0;
    final int numProducts = products.length;
    if (numProducts > 3) {
      for (int i = 3; i < numProducts; i++) {
        overflow += productMap[products[i]];
      }
    }
    return overflow;
  }

  Widget _buildOverflow(AppStateModel model, BuildContext context) {
    if (model.productsInCart.length <= 3) {
      return Container();
    }

    final int numOverflowProducts = _calculateOverflow(model);
    // Maximum of 99 so padding doesn't get messy.
    final int displayedOverflowProducts =
        numOverflowProducts <= 99 ? numOverflowProducts : 99;
    return Container(
      child: Text(
        '+$displayedOverflowProducts',
        style: Theme.of(context).primaryTextTheme.button,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<AppStateModel>(
      builder: (builder, child, model) => _buildOverflow(model, context),
    );
  }
}

class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail(this.animation, this.opacityAnimation, this.product);

  final Animation<double> animation;
  final Animation<double> opacityAnimation;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = isDisplayDesktop(context);

    return FadeTransition(
      opacity: opacityAnimation,
      child: ScaleTransition(
        scale: animation,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: ExactAssetImage(
                product.assetName, // asset name
                package: product.assetPackage, // asset package
              ),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          margin: isDesktop
              ? const EdgeInsets.only(left: 12, right: 12, bottom: 16)
              : const EdgeInsets.only(left: 16),
        ),
      ),
    );
  }
}

// _ListModel manipulates an internal list and an AnimatedList
class _ListModel {
  _ListModel({
    @required this.listKey,
    @required this.removedItemBuilder,
    Iterable<int> initialItems,
  })  : assert(listKey != null),
        assert(removedItemBuilder != null),
        _items = initialItems?.toList() ?? [];

  final GlobalKey<AnimatedListState> listKey;
  final Widget Function(int, BuildContext, Animation<double>)
      removedItemBuilder;
  final List<int> _items;

  AnimatedListState get _animatedList => listKey.currentState;

  void add(int product) {
    _insert(_items.length, product);
  }

  void _insert(int index, int item) {
    _items.insert(index, item);
    _animatedList.insertItem(index,
        duration: const Duration(milliseconds: 225));
  }

  void remove(int product) {
    final int index = _items.indexOf(product);
    if (index >= 0) {
      _removeAt(index);
    }
  }

  void _removeAt(int index) {
    final int removedItem = _items.removeAt(index);
    if (removedItem != null) {
      _animatedList.removeItem(index, (context, animation) {
        return removedItemBuilder(removedItem, context, animation);
      });
    }
  }

  int get length => _items.length;

  int operator [](int index) => _items[index];

  int indexOf(int item) => _items.indexOf(item);

  List<int> get list => _items;
}
