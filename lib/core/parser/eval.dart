library angular.core.parser.eval;

import 'package:angular/core/parser/syntax.dart' as syntax;
import 'package:angular/core/parser/utils.dart';
import 'package:angular/core/module.dart';

export 'package:angular/core/parser/eval_access.dart';
export 'package:angular/core/parser/eval_calls.dart';

class Chain extends syntax.Chain {
  Chain(List<syntax.Expression> expressions) : super(expressions);
  eval(scope, FilterMap filters) {
    var result;
    for (int i = 0; i < expressions.length; i++) {
      var last = expressions[i].eval(scope, filters);
      if (last != null) result = last;
    }
    return result;
  }
}

class Filter extends syntax.Filter {
  final List<syntax.Expression> allArguments;
  Filter(syntax.Expression expression, String name, List<syntax.Expression> arguments,
         this.allArguments)
      : super(expression, name, arguments);

  eval(scope, FilterMap filters) {
    if (filters == null) {
      throw 'No NgFilter: $name found!';
    }
    return Function.apply(filters(name), evalList(scope, allArguments, filters));
  }
}

class Assign extends syntax.Assign {
  Assign(syntax.Expression target, value) : super(target, value);
  eval(scope, FilterMap filters) =>
      target.assign(scope, value.eval(scope, filters));
}

class Conditional extends syntax.Conditional {
  Conditional(syntax.Expression condition,
              syntax.Expression yes, syntax.Expression no)
      : super(condition, yes, no);
  eval(scope, FilterMap filters) => toBool(condition.eval(scope, filters))
      ? yes.eval(scope, filters)
      : no.eval(scope, filters);
}

class PrefixNot extends syntax.Prefix {
  PrefixNot(syntax.Expression expression) : super('!', expression);
  eval(scope, FilterMap filters) => !toBool(expression.eval(scope, filters));
}

class Binary extends syntax.Binary {
  Binary(String operation, syntax.Expression left, syntax.Expression right):
      super(operation, left, right);
  eval(scope, FilterMap filters) {
    var lValue = left.eval(scope, filters);
    switch (operation) {
      // evaluates the rValue only if required
      case '&&': return toBool(lValue) && toBool(right.eval(scope, filters));
      case '||': return toBool(lValue) || toBool(right.eval(scope, filters));
    }

    var rValue = right.eval(scope, filters);

    // Null check for the operations.
    if (lValue == null || rValue == null) {
      switch (operation) {
        case '+':
          if (lValue != null) return lValue;
          if (rValue != null) return rValue;
          return 0;
        case '-':
          if (lValue != null) return lValue;
          if (rValue != null) return 0 - rValue;
          return 0;
      }
      return null;
    }

    switch (operation) {
      case '+'  : return autoConvertAdd(lValue, rValue);
      case '-'  : return lValue - rValue;
      case '*'  : return lValue * rValue;
      case '/'  : return lValue / rValue;
      case '~/' : return lValue ~/ rValue;
      case '%'  : return lValue % rValue;
      case '==' : return lValue == rValue;
      case '!=' : return lValue != rValue;
      case '<'  : return lValue < rValue;
      case '>'  : return lValue > rValue;
      case '<=' : return lValue <= rValue;
      case '>=' : return lValue >= rValue;
      case '^'  : return lValue ^ rValue;
      case '&'  : return lValue & rValue;
    }
    throw new EvalError('Internal error [$operation] not handled');
  }
}

class LiteralPrimitive extends syntax.LiteralPrimitive {
  LiteralPrimitive(dynamic value) : super(value);
  eval(scope, FilterMap filters) => value;
}

class LiteralString extends syntax.LiteralString {
  LiteralString(String value) : super(value);
  eval(scope, FilterMap filters) => value;
}

class LiteralArray extends syntax.LiteralArray {
  LiteralArray(List<syntax.Expression> elements) : super(elements);
  eval(scope, FilterMap filters) =>
      elements.map((e) => e.eval(scope, filters)).toList();
}

class LiteralObject extends syntax.LiteralObject {
  LiteralObject(List<String> keys, List<syntax.Expression>values)
      : super(keys, values);
  eval(scope, FilterMap filters) =>
      new Map.fromIterables(keys, values.map((e) => e.eval(scope, filters)));
}
