library angular_spec;

import '_specs.dart';
import 'package:angular/utils.dart';
import 'dart:mirrors';

main() {
  describe('angular.dart unittests', () {
    it('should run in checked moded only', () {
      expect(() {
        dynamic v = 6;
        String s = v;
      }).toThrow();
    });
  });

  describe('relaxFnApply', () {
    it('should work with 6 arguments', () {
      var sixArgs = [1, 1, 2, 3, 5, 8];
      expect(relaxFnApply(() => "none", sixArgs)).toEqual("none");
      expect(relaxFnApply((a) => a, sixArgs)).toEqual(1);
      expect(relaxFnApply((a, b) => a + b, sixArgs)).toEqual(2);
      expect(relaxFnApply((a, b, c) => a + b + c, sixArgs)).toEqual(4);
      expect(relaxFnApply((a, b, c, d) => a + b + c + d, sixArgs)).toEqual(7);
      expect(relaxFnApply((a, b, c, d, e) => a + b + c + d + e, sixArgs)).toEqual(12);
    });

    it('should work with 0 arguments', () {
      var noArgs = [];
      expect(relaxFnApply(() => "none", noArgs)).toEqual("none");
      expect(relaxFnApply(([a]) => a, noArgs)).toEqual(null);
      expect(relaxFnApply(([a, b]) => b, noArgs)).toEqual(null);
      expect(relaxFnApply(([a, b, c]) => c, noArgs)).toEqual(null);
      expect(relaxFnApply(([a, b, c, d]) => d, noArgs)).toEqual(null);
      expect(relaxFnApply(([a, b, c, d, e]) => e, noArgs)).toEqual(null);
    });

    it('should fail with not enough arguments', () {
      expect(() {
        relaxFnApply((required, alsoRequired) => "happy", [1]);
      }).toThrow('Unknown function type, expecting 0 to 5 args.');
    });
  });

  describe('angular symbols', () {
    it('should not export symbols that we do not know about', () {
      // Test is failing? Add new symbols to the "ALLOWED_NAMES" list below.
      // But make sure that you intend to export the symbol!
      // Questions?  Talk to @jbdeboer

      _getSymbolsFromLibrary(String libraryName) {
        var names = [];
        var SYMBOL_NAME = new RegExp('"(.*)"');
        _unwrapSymbol(sym) => SYMBOL_NAME.firstMatch(sym.toString()).group(1);

        var seen = {};

        // Set this to true to see how symbols are exported from angular.
        var SHOULD_PRINT_SYMBOL_TREE = false;

        // TODO(deboer): Add types once Dart VM 1.2 is deprecated.
        extractSymbols(/* LibraryMirror */ lib, [List showSymbols = const[], List hideSymbols = const[], String printPrefix = ""]) {
          if (SHOULD_PRINT_SYMBOL_TREE) print(printPrefix + _unwrapSymbol(lib.qualifiedName));
          printPrefix += "  ";
          lib.declarations.forEach((symbol, _) {
            if (!showSymbols.isEmpty && !showSymbols.contains(symbol)) return;
            if (!hideSymbols.isEmpty && hideSymbols.contains(symbol)) return;
            if (SHOULD_PRINT_SYMBOL_TREE) print(printPrefix + _unwrapSymbol(symbol));
            names.add([_unwrapSymbol(symbol), _unwrapSymbol(lib.qualifiedName)]);
          });

          lib.libraryDependencies.forEach((/* LibraryDependencyMirror */ libDep) {
            LibraryMirror target = libDep.targetLibrary;
            if (!libDep.isExport) return;

            List showSymbols = [];
            List hideSymbols = [];
            libDep.combinators.forEach((/* CombinatorMirror */ c) {
              if (c.isShow) {
                showSymbols.addAll(c.identifiers);
              }
              if (c.isHide) {
                hideSymbols.addAll(c.identifiers);
              }
            });

            if (!seen.containsKey(target)) {
              seen[target] = true;
              extractSymbols(target, showSymbols, hideSymbols, printPrefix);
            }
          });
        };

        var lib = currentMirrorSystem().findLibrary(new Symbol(libraryName));

        extractSymbols(lib);
        return names;
      }

      var names;
      try {  // Not impleneted in Dart VM 1.2
        names = _getSymbolsFromLibrary("angular");
      } on UnimplementedError catch (e) {
        return; // Not implemented, quietly skip.
      } catch (e) {
        print("Error: $e");
        return; // On VMes <1.2, quietly skip.
      }

      var ALLOWED_PREFIXS = [
        "Ng",
        "ng",
        "Angular",
        "_"
      ];

      // NOTE(deboer): There are a number of symbols that should not be
      // exported in the list.  We are working on un-export the symbols.
      // Comments on each symbols below.
      var ALLOWED_NAMES = [
        "di.FactoryFn",
        "di.Injector",
        "di.InvalidBindingError",
        "di.Key",  // common name, should be removed.
        "di.TypeFactory",
        "di.Visibility",
        "di.NoProviderError",
        "di.CircularDependencyError",
        "di.ObjectFactory",
        "di.Module",
        "angular.core.AnnotationMap",
        "angular.core.LruCache",  // internal?
        "angular.core.ScopeStats",
        "angular.core.ArrayFn",  // internal?
        "angular.core.Interpolation",
        "angular.core.LongStackTrace",  // internal?
        "angular.core.Cache",  // internal?
        "angular.core.ExpressionVisitor",  // internal?
        "angular.core.ScopeEvent",
        "angular.core.MapFn",  // internal?
        "angular.core.EvalFunction1",  // internal?
        "angular.core.MetadataExtractor",  // internal?
        "angular.core.ExceptionHandler",
        "angular.core.ZoneOnTurn",  // internal?
        "angular.core.ZoneOnError",  // internal?
        "angular.core.ScopeDigestTTL",
        "angular.core.EvalFunction0",  // internal?
        "angular.core.AnnotationsMap",  // internal?
        "angular.core.RootScope",
        "angular.core.CacheStats",
        "angular.core.ScopeLocals",
        "angular.core.ScopeStreamSubscription",
        "angular.core.Interpolate",
        "angular.core.NOT_IMPLEMENTED",  // internal?
        "angular.core.Scope",
        "angular.core.AttrFieldAnnotation",
        "angular.core.UnboundedCache",  // internal?
        "angular.core.ScopeStream",  // internal?
        "angular.core.FilterMap",  // internal?
        "angular.core.AstParser",  // internal?
        "angular.watch_group.FunctionApply",  // internal?
        "angular.watch_group.WatchGroup",  // internal?
        "angular.watch_group.ContextReferenceAST",  // internal?
        "angular.watch_group.ConstantAST",  // internal?
        "angular.watch_group.Watch",
        "angular.watch_group.ReactionFn",  // internal?
        "angular.watch_group.ChangeLog",
        "angular.watch_group.FieldReadAST",  // internal?
        "angular.watch_group.PureFunctionAST",  // internal?
        "angular.watch_group.PrototypeMap",  // internal?
        "angular.watch_group.CollectionAST",  // internal?
        "angular.watch_group.MethodAST",  // internal?
        "angular.watch_group.AST",  // internal?
        "angular.watch_group.RootWatchGroup",
        "angular.core.dom.AnimationResult",
        "angular.core.dom.WalkingViewFactory",  // internal?
        "angular.core.dom.ResponseError",
        "angular.core.dom.View",
        "angular.core.dom.ElementBinder",  // internal?
        "angular.core.dom.NoOpAnimation",
        "angular.core.dom.AttributeChanged",
        "angular.core.dom.HttpBackend",
        "angular.core.dom.HttpDefaults",
        "angular.core.dom.TaggedElementBinder",  // internal?
        "angular.core.dom.LocationWrapper",
        "angular.core.dom.Cookies",
        "angular.core.dom.ElementBinderTreeRef",  // internal?
        "angular.core.dom.EventHandler",
        "angular.core.dom.Response",
        "angular.core.dom.HttpDefaultHeaders",
        "angular.core.dom.Animation",
        "angular.core.dom.ViewPort",
        "angular.core.dom.TemplateLoader",
        "angular.core.dom.RequestErrorInterceptor",
        "angular.core.dom.TaggedTextBinder",  // internal?
        "angular.core.dom.Http",
        "angular.core.dom.BoundViewFactory",  // internal?
        "angular.core.dom.ElementBinderFactory",  // internal?
        "angular.core.dom.DirectiveMap",  // internal?
        "angular.core.dom.BrowserCookies",
        "angular.core.dom.HttpInterceptor",
        "angular.core.dom.cloneElements",  // internal?
        "angular.core.dom.EventFunction",  // internal?
        "angular.core.dom.RequestInterceptor",
        "angular.core.dom.DefaultTransformDataHttpInterceptor",
        "angular.core.dom.HttpResponseConfig",
        "angular.core.dom.ElementProbe",
        "angular.core.dom.ApplyMapping",  // internal?
        "angular.core.dom.ViewCache",  // internal?
        "angular.core.dom.FieldMetadataExtractor",  // internal?
        "angular.core.dom.Compiler",
        "angular.core.dom.HttpResponse",
        "angular.core.dom.UrlRewriter",
        "angular.core.dom.DirectiveRef",
        "angular.core.dom.HttpInterceptors",
        "angular.core.dom.forceNewDirectivesAndFilters",  // internal?
        "angular.core.dom.DirectiveSelectorFactory",  // internal?
        "angular.core.dom.Mustache",
        "angular.core.dom.TaggingViewFactory",  // internal?
        "angular.core.dom.NodeCursor",  // internal?
        "angular.core.dom.TemplateCache",  // internal?
        "angular.core.dom.ViewFactory",
        "angular.core.dom.NullTreeSanitizer",
        "angular.core.dom.NodeAttrs",
        "angular.core.dom.ElementBinderTree",  // internal?
        "angular.core.dom.WalkingCompiler",  // internal?
        "angular.core.dom.TaggingCompiler",  // internal?
        "angular.core.dom.DirectiveSelector",  // internal?
        "angular.core.parser.BoundGetter",  // internal?
        "angular.core.parser.LocalsWrapper",  // internal?
        "angular.core.parser.Getter",  // common name
        "angular.core.parser.Parser",
        "angular.core.parser.ParserBackend",
        "angular.core.parser.BoundSetter",
        "angular.core.parser.Setter",  // common name
        "angular.core.parser.syntax.BoundExpression", // evenything in syntax should be private
        "angular.core.parser.syntax.Expression",
        "angular.core.parser.syntax.CallArguments",
        "angular.core.parser.syntax.Visitor",
        "angular.core.parser.dynamic_parser.ClosureMap",
        "angular.core.parser.dynamic_parser.DynamicParser",
        "angular.core.parser.dynamic_parser.DynamicParserBackend",
        "angular.core.parser.static_parser.StaticParserFunctions",
        "angular.core.parser.static_parser.StaticParser",
        "angular.core.parser.lexer.Scanner",  // everything in lexer should be private
        "angular.core.parser.lexer.OPERATORS",
        "angular.core.parser.lexer.NumberToken",
        "angular.core.parser.lexer.Token",
        "angular.core.parser.lexer.IdentifierToken",
        "angular.core.parser.lexer.StringToken",
        "angular.core.parser.lexer.CharacterToken",
        "angular.core.parser.lexer.Lexer",
        "angular.core.parser.lexer.KEYWORDS",
        "angular.core.parser.lexer.OperatorToken",
        "angular.directive.ItemEval",
        "angular.directive.OptionValueDirective",
        "angular.directive.InputSelectDirective",
        "angular.directive.InputTextLikeDirective",
        "angular.directive.InputNumberLikeDirective",
        "angular.directive.ContentEditableDirective",
        "angular.directive.InputCheckboxDirective",
        "angular.directive.InputRadioDirective",
        "angular.filter.JsonFilter",
        "angular.filter.Equals",
        "angular.filter.Mapper",
        "angular.filter.FilterFilter",
        "angular.filter.NumberFilter",
        "angular.filter.DateFilter",
        "angular.filter.LowercaseFilter",
        "angular.filter.UppercaseFilter",
        "angular.filter.OrderByFilter",
        "angular.filter.CurrencyFilter",
        "angular.filter.LimitToFilter",
        "angular.filter.Predicate",
        "angular.routing.RouteInitializerFn",
        "angular.routing.RouteProvider",
        "angular.routing.RouteInitializer",
        "angular.routing.RouteViewFactory",
        "route.client.RouteHandle",
        "route.client.RouteEnterEvent",
        "route.client.RouteStartEvent",
        "route.client.Router",
        "route.client.RouteEvent",
        "route.client.RouteLeaveEventHandler",
        "route.client.Route",
        "route.client.RouteImpl",
        "route.client.RouteLeaveEvent",
        "route.client.RoutePreEnterEventHandler",
        "route.client.RoutePreEnterEvent",
        "route.client.Routable",
        "route.client.RouteEnterEventHandler",
        "url_matcher.UrlMatcher",
        "url_matcher.UrlMatch",
        "dirty_checking_change_detector.FieldGetter",  // everything in change detector should be private
        "dirty_checking_change_detector.GetterCache",
      ];

      var _nameMap = {};
      ALLOWED_NAMES.forEach((x) => _nameMap[x] = true);

      assertSymbolNameIsOk(List nameInfo) {
        String name = nameInfo[0];
        String libName = nameInfo[1];

        if (ALLOWED_PREFIXS.any((prefix) => name.startsWith(prefix))) return;

        var key = "$libName.$name";
        if (_nameMap.containsKey(key)) {
          _nameMap[key] = false;
          return;
        }

        throw "Symbol $key is exported thru the angular library, but it shouldn't be";
      };

      names.forEach(assertSymbolNameIsOk);

      // If there are keys that no longer need to be in the ALLOWED_NAMES list, complain.
      _nameMap.forEach((k,v) {
        if (v) print("angular_spec.dart: Unused ALLOWED_NAMES key $k");
      });
    });
  });
}
