/**
*
* Filters available in the main [angular.dart](#angular/angular) library.
*
* This package is imported for you as part of [angular.dart](#angular/angular),
* and lists all of the basic filters that are part of Angular.
*
*
*/
library angular.filter;

import 'dart:convert' show JSON;
import 'package:intl/intl.dart';
import 'package:di/di.dart';
import 'package:angular/core/annotation.dart';
import 'package:angular/core/module_internal.dart';
import 'package:angular/core/parser/parser.dart';

part 'currency.dart';
part 'date.dart';
part 'filter.dart';
part 'json.dart';
part 'limit_to.dart';
part 'lowercase.dart';
part 'number.dart';
part 'order_by.dart';
part 'uppercase.dart';
part 'stringify.dart';

class NgFilterModule extends Module {
  NgFilterModule() {
    type(Currency);
    type(Date);
    type(Filter);
    type(Json);
    type(LimitTo);
    type(Lowercase);
    type(Number);
    type(OrderBy);
    type(Uppercase);
    type(Stringify);
  }
}
