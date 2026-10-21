import 'package:flutter/material.dart';

final GlobalKey<ScaffoldState> homeScaffoldKey = GlobalKey<ScaffoldState>();

void openHomeDrawer() => homeScaffoldKey.currentState?.openDrawer();
