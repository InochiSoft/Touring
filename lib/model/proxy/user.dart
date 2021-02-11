
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:touring/model/config/user.dart';
import 'package:touring/model/vo/user.dart';

class UserProxy {
  Future<UserVO> login(BuildContext context, UserVO _user) async {
    Map<String, String> headers = {"Content-type": "application/x-www-form-urlencoded"};
    UserConfig _configVO = UserConfig();

    UserVO _result; // await _configVO.getUser();

    return _result;
  }

  Future<UserVO> connect(BuildContext context, UserVO _user) async {
    Map<String, String> headers = {"Content-type": "application/x-www-form-urlencoded"};
    UserVO _result;

    return _result;
  }

  Future<List<UserVO>> search(BuildContext context, String query, int page) async {
    Map<String, String> headers = {"Content-type": "application/x-www-form-urlencoded"};
    List<UserVO> _result = new List();

    return _result;
  }

  Future<UserVO> logout(BuildContext context, UserVO _user) async {
    Map<String, String> headers = {"Content-type": "application/x-www-form-urlencoded"};
    UserConfig _configVO = UserConfig();
    UserVO _result = await _configVO.getUser();

    return _result;
  }

  Future<UserVO> register(BuildContext context, UserVO _user) async {
    Map<String, String> headers = {"Content-type": "application/x-www-form-urlencoded"};
    UserVO _result;

    return _result;
  }

  Future<UserVO> update(BuildContext context, UserVO _user) async {
    Map<String, String> headers = {"Content-type": "application/x-www-form-urlencoded"};
    UserVO _result;

    return _result;
  }

  Future<UserVO> getById(BuildContext context, String session, String id) async {
    Map<String, String> headers = {"Content-type": "application/x-www-form-urlencoded"};
    UserVO _result; // await _configVO.getUser();

    return _result;
  }

  Future<UserVO> getSaved(BuildContext context) async {
    UserConfig _configVO = UserConfig();
    UserVO _user = await _configVO.getUser();
    if (_user != null){
      _configVO.setUser(_user);
    }
    return _user;
  }

}
