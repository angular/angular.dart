library angular.core.parser.eval;

import 'package:angular/core/parser/syntax.dart' as syntax;
import 'package:angular/core/parser/utils.dart';

export 'package:angular/core/parser/eval_access.dart';
export 'package:angular/core/parser/eval_calls.dart';

class Chain extends syntax.Chain {
  Chain(expressions) : super(expressions);
  eval(scope) {
    var result;
    for (int i = 0, length = expressions.length; i < length; i++) {
      var last = expressions[i].eval(scope);
      if (last != null) result = last;
    }
    return result;
  }
}

class Filter extends syntax.Filter {
  final Function function;
  final List allArguments;
  Filter(expression, name, arguments, this.function, this.allArguments)
      : super(expression, name, arguments);
  eval(scope) => Function.apply(function, evalList(scope, allArguments));
}

class Assign extends syntax.Assign {
  Assign(target, value) : super(target, value);
  eval(scope) => target.assign(scope, value.eval(scope));
}

class Conditional extends syntax.Conditional {
  Conditional(condition, yes, no) : super(condition, yes, no);
  eval(scope) => toBool(condition.eval(scope))
      ? yes.eval(scope)
      : no.eval(scope);
}

class PrefixNot extends syntax.Prefix {
  PrefixNot(expression) : super('!', expression);
  eval(scope) => !toBool(expression.eval(scope));
}

class Binary extends syntax.Binary {
  Binary(operation, left, right) : super(operation, left, right);
  eval(scope) {
    var left = this.left.eval(scope);
    switch (operation) {
      case '&&': return toBool(left) && toBool(this.right.eval(scope));
      case '||': return toBool(left) || toBool(this.right.eval(scope));
    }
    var right = this.right.eval(scope);
    switch (operation) {
      case '+'  : return autoConvertAdd(left, right);
      case '-'  : return left - right;
      case '*'  : return left * right;
      case '/'  : return left / right;
      case '~/' : return left ~/ right;
      case '%'  : return left % right;
      case '==' : return left == right;
      case '!=' : return left != right;
      case '<'  : return left < right;
      case '>'  : return left > right;
      case '<=' : return left <= right;
      case '>=' : return left >= right;
      case '^'  : return left ^ right;
      case '&'  : return left & right;
    }
    throw new EvalError('Internal error [$operation] not handled');
  }
}

class LiteralPrimitive extends syntax.LiteralPrimitive {
  LiteralPrimitive(value) : super(value);
  eval(scope) => value;
}

class LiteralString extends syntax.LiteralString {
  LiteralString(value) : super(value);
  eval(scope) => value;
}

class LiteralArray extends syntax.LiteralArray {
  LiteralArray(elements) : super(elements);
  eval(scope) => elements.map((e) => e.eval(scope)).toList();
}

class LiteralObject extends syntax.LiteralObject {
  LiteralObject(keys, values) : super(keys, values);
  eval(scope) => new Map.fromIterables(keys, values.map((e) => e.eval(scope)));
}
