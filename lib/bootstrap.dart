/**
 * Bootstrapping for Angular applications via [app:dynamic](#angular-app-dynamic) for development,
 * or
 * [app:static](#angular-app-static) for production.
 *
 */
library angular.app;

import 'dart:html' as dom;

import 'package:intl/date_symbol_data_local.dart';
import 'package:di/di.dart';
import 'package:angular/angular.dart';
import 'package:angular/perf/module.dart';
import 'package:angular/core/module_internal.dart';
import 'package:angular/core/registry.dart';
import 'package:angular/core_dom/module_internal.dart';
import 'package:angular/directive/module.dart';
import 'package:angular/filter/module.dart';
import 'package:angular/routing/module.dart';
import 'package:angular/introspection_js.dart';

/**
 * This is the top level module which describes the core angular of angular including filters and
 * directives. The module is automatically included with [Application]
 *
 * The Module is made up of
 *
 * - [NgCoreModule]
 * - [NgCoreDomModule]
 * - [NgDirectiveModule]
 * - [NgFilterModule]
 * - [NgPerfModule]
 * - [NgRoutingModule]
 */
class AngularModule extends Module {
  AngularModule() {
    install(new NgCoreModule());
    install(new NgCoreDomModule());
    install(new NgDirectiveModule());
    install(new NgFilterModule());
    install(new NgPerfModule());
    install(new NgRoutingModule());

    type(MetadataExtractor);
    value(Expando, elementExpando);
  }
}

/**
 * Application is how you configure and run an Angular application. Application is abstract. There are two
 * implementations: one is dynamic, using Mirrors; the other is static, using code generation.
 *
 * To create an Application, import angular_dynamic.dart and call dynamicApplication like so:
 *
 *     import 'package:angular/angular.dart';
 *     import 'package:angular/angular_dynamic.dart';
 *
 *     class HelloWorldController {
 *       ...
 *       }
 *
 *     main() {
 *      dynamicApplication()
 *        .addModule(new Module()..type(HelloWorldController))
 *        .run();
 *     }
 *
 * On `pub build`, dynamicApplication becomes staticApplication, as pub generates the getters,
 * setters, annotations, and factories for the root Injector that [ngApp] creates. This
 *
 *
 */

abstract class Application {
  static _find(String selector, [dom.Element defaultElement]) {
    var element = dom.window.document.querySelector(selector);
    if (element == null) element = defaultElement;
    if (element == null) {
      throw "Could not find application element '$selector'.";
    }
    return element;
  }

  final zone = new NgZone();
  final ngModule = new AngularModule();
  final modules = <Module>[];
  dom.Element element;

  dom.Element selector(String selector) => element = _find(selector);

  Application(): element = _find('[ng-app]', dom.window.document.documentElement) {
    modules.add(ngModule);
    ngModule..value(NgZone, zone)
            ..value(Application, this)
            ..factory(dom.Node, (i) => i.get(Application).element);
  }

  Injector injector;

  Application addModule(Module module) {
    modules.add(module);
    return this;
  }

  Injector run() {
    publishToJavaScript();
    return zone.run(() {
      var rootElements = [element];
      Injector injector = createInjector();
      ExceptionHandler exceptionHandler = injector.get(ExceptionHandler);
      initializeDateFormatting(null, null).then((_) {
        try {
          var compiler = injector.get(Compiler);
          var viewFactory = compiler(rootElements, injector.get(DirectiveMap));
          viewFactory(injector, rootElements);
        } catch (e, s) {
          exceptionHandler(e, s);
        }
      });
      return injector;
    });
  }

  Injector createInjector();
}
