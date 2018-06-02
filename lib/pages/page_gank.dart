/*
 * Author: Jpeng
 * Email: peng8350@gmail.com
 * Time: 2018/5/21 下午11:03
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gank/App.dart';
import 'package:flutter_gank/bean/info_gank.dart';
import 'package:flutter_gank/constant/colors.dart';
import 'package:flutter_gank/constant/strings.dart';
import 'package:flutter_gank/utils/utils_db.dart';
import 'package:flutter_gank/utils/utils_indicator.dart';
import 'package:flutter_gank/widget/CircleClipper.dart';
import 'package:flutter_gank/widget/item_gank.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_gank/utils/utils_http.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GankPage extends StatefulWidget {
  final String title;

  final bool isSeaching;

  GankPage({this.title, Key key, this.isSeaching}) : super(key: key);

  @override
  GankPageState createState() => new GankPageState();
}

class GankPageState extends State<GankPage>
    with HttpUtils, IndicatorFactory, DbUtils {
  List<GankInfo> _dataList = [];
  List<GankInfo> _searchList = [];
  RefreshController _refreshController;
  int _pageIndex = 1;
  final ValueNotifier<double> offsetLis = new ValueNotifier(0.0);

  void _fetchMoreData() {
    getGankfromNet(URL_GANK_FETCH + widget.title + "/20/$_pageIndex")
        .then((List<GankInfo> data) {
          print(data);
      if (data.isEmpty) {
        //空数据
        _refreshController.sendBack(false, RefreshStatus.noMore);
      } else {
        for (GankInfo item in data) {
          _dataList.add(item);
          insert("Gank", item.toMap()).then((val) {}).catchError((error) {});
        }
        _pageIndex++;

        _refreshController.sendBack(false, RefreshStatus.idle);
        setState(() {});
      }
      return false;
    }).catchError((error) {
      print(error);
      _refreshController.sendBack(false, 4);
      return false;
    });
  }

  void _onOffsetCall(bool up, double offset) {
    if (up) {
      offsetLis.value = offset;
    }
  }

  void _onClickLike(GankInfo item) {
    item.like = !item.like;

    update("Gank", item.toMap(), "id = ? ", [item.id]);
    setState(() {});
  }

  void _onRefresh(bool up) {
    if (!up) {
      //上拉加载
      _fetchMoreData();
    } else {
      new Future.delayed(const Duration(milliseconds: 1000)).then((val) {
        _refreshController.sendBack(true, RefreshStatus.completed);
      });
    }
  }

  void searchGank(String searchText) {
    _searchList.clear();
    for (GankInfo item in _dataList) {
      if (item.isAvailableSearch(searchText)) {
        _searchList.add(item);
      }
    }
    setState(() {});
  }

  Widget _buildContent() {
    if (!widget.isSeaching)
      return new Stack(
        children: <Widget>[
          new ArcIndicator(
            offsetLis: offsetLis,
          ),
          new SmartRefresher(
            controller: _refreshController,
            child: new ListView.builder(
              itemBuilder: (context, index) => new GankItem(
                info: _dataList[index],
                onChange: () {
                  _onClickLike(_dataList[index]);
                },
              ),
              itemCount: _dataList.length,
            ),
            headerBuilder: buildDefaultHeader,
            footerBuilder: (context,mode) => buildDefaultFooter(context,mode,(){
              _refreshController.sendBack(false, RefreshStatus.refreshing);
            }),
            onRefresh: _onRefresh,
            enablePullUp: true,
            onOffsetChange: _onOffsetCall,
          )
        ],
      );
    else
      return new ListView.builder(
        itemBuilder: (context, index) => new GankItem(
              info: _searchList[index],
              onChange: () {
                _onClickLike(_searchList[index]);
              },
            ),
        itemCount: _searchList.length,
      );
  }

  @override
  Widget build(BuildContext context) {
    return new RepaintBoundary(
      child: _buildContent(),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  void didUpdateWidget(GankPage oldWidget) {
    // TODO: implement didUpdateWidget
    getList("Gank", "type = ?", [widget.title]).then((maps) {
      _dataList.clear();
      for (Map map in maps) {
        _dataList.add(new GankInfo.fromMap(map));
      }
      int aa = maps.length ~/ 20;
      _pageIndex = aa + 1;
      setState(() {});
    });

    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _refreshController = new RefreshController();
    getList("Gank", "type = ?", [widget.title]).then((List<dynamic> list) {
      if (list.isEmpty) {
        SharedPreferences.getInstance().then((SharedPreferences preferences) {
          if (preferences.getBool("autoRefresh") ?? false) {
            _refreshController.sendBack(false, RefreshStatus.refreshing);
          }
        });
      } else {
        for (Map map in list) {
          _dataList.add(new GankInfo.fromMap(map));
        }
        int aa = list.length ~/ 20;
        _pageIndex = aa + 1;
      }
    });
  }
}
