library angular.service.directive;

import "dart:mirrors";

class NgAnnotationBase {
  /**
   * CSS selector which will trigger this component/directive.
   * CSS Selectors are limited to a single element and can contain:
   *
   * * `element-name` limit to a given element name.
   * * `.class` limit to an element with a given class.
   * * `[attribute]` limit to an element with a given attribute name.
   * * `[attribute=value]` limit to an element with a given attribute and value.
   *
   *
   * Example: `input[type=checkbox][ng-model]`
   */
  final String selector;

  /**
   * A directive/component controller class can be injected into other
   * directives/components. This attribute controls whether the
   * controller is available to others.
   *
   * * `local` [NgDirective.LOCAL_VISIBILITY] - the controller can be injected
   *   into other directives / components on the same DOM element.
   * * `children` [NgDirective.CHILDREN_VISIBILITY] - the controller can be
   *   injected into other directives / components on the same or child DOM
   *   elements.
   * * `direct_children` [NgDirective.DIRECT_CHILDREN_VISIBILITY] - the
   *   controller can be injected into other directives / components on the
   *   direct children of the current DOM element.
   */
  final String visibility;
  final List<Type> publishTypes;

  /**
   * Use map to define the mapping of component's DOM attributes into
   * the component instance or scope. The map's key is the DOM attribute name
   * to map in camelCase (DOM attribute is in dash-case). The Map's value
   * consists of a mode character, and an expression. If expression is not
   * specified, it maps to the same scope parameter as is the DOM attribute.
   *
   * * `@` - Map the DOM attribute string. The attribute string will be taken
   *   literally or interpolated if it contains binding {{}} systax.
   *
   * * `=` - Treat the DOM attribute value as an expression. Set up a watch
   *   on both outside as well as component scope to keep the src and
   *   destination in sync.
   *
   * * `!` - Treat the DOM attribute value as an expression. Set up a one time
   *   watch on expression. Once the expression turns truthy it will no longer
   *   update.
   *
   * * `&` - Treat the DOM attribute value as an expression. Assign a closure
   *   function into the component. This allows the component to control
   *   the invocation of the closure. This is useful for passing
   *   expressions into controllers which act like callbacks.
   *
   * NOTE: an expression may start with `.` which evaluates the expression
   * against the current controller rather then current scope.
   *
   * Example:
   *
   *     <my-component title="Hello {{username}}"
   *                   selection="selectedItem"
   *                   on-selection-change="doSomething()">
   *
   *     @NgComponent(
   *       selector: 'my-component'
   *       map: const {
   *         'title': '@.title',
   *         'selection': '=.currentItem',
   *         'onSelectionChange': '&.onChange'
   *       }
   *     )
   *     class MyComponent {
   *       String title;
   *       var currentItem;
   *       ParsedFn onChange;
   *     }
   *
   *  The above example shows how all three mapping modes are used.
   *
   *  * `@.title` maps the title DOM attribute to the controller `title`
   *    field. Notice that this maps the content of the attribute, which
   *    means that it can be used with `{{}}` interpolation.
   *
   *  * `=.currentItem` maps the expression (in this case the `selectedItem`
   *    in the current scope into the `currentItem` in the controller. Notice
   *    that mapping is bi-directional. A change either in controller or on
   *    parent scope will result in change of the other.
   *
   *  * `&.onChange` maps the expression into tho controllers `onChange`
   *    field. The result of mapping is a callable function which can be
   *    invoked at any time by the controller. The invocation of the
   *    callable function will result in the expression `doSomething()` to
   *    be executed in the parent context.
   */
  final Map<String, String> map;

  /**
   * Use the list to specify expression containing attributes which are not
   * included under [map] with '=' or '@' specification.
   */
  final List<String> exportExpressionAttrs;

  /**
   * Use the list to specify a expressions which are evaluated dynamically
   * (ex. via [Scope.$eval]) and are otherwise not statically discoverable.
   */
  final List<String> exportExpressions;

  const NgAnnotationBase({
    this.selector,
    this.visibility: NgDirective.LOCAL_VISIBILITY,
    this.publishTypes,
    this.map,
    this.exportExpressions,
    this.exportExpressionAttrs
  });
}

/**
 * Meta-data marker placed on a class which should act as a controller for the
 * component. Angular components are a light-weight version of web-components.
 * Angular components use shadow-DOM for rendering their templates.
 *
 * Angular components are instantiated using dependency injection, and can
 * ask for any injectable object in their constructor. Components
 * can also ask for other components or directives declared on the DOM element.
 *
 * Components can declared these optional methods:
 *
 * * `attach()` - Called on first [Scope.$digest()].
 *
 * * `detach()` - Called on when owning scope is destroyed.
 *
 */
class NgComponent extends NgAnnotationBase {
  /**
   * Inlined HTML template for the component.
   */
  final String template;

  /**
   * A URL to HTML template. This will be loaded asynchronously and
   * cached for future component instances.
   */
  final String templateUrl;

  /**
   * A CSS URL to load into the shadow DOM.
   */
  final String cssUrl;

  /**
   * An expression under which the controller instance will be published into.
   * This allows the expressions in the template to be referring to controller
   * instance and its properties.
   */
  final String publishAs;

  /**
   * Set the shadow root applyAuthorStyles property. See shadow-DOM
   * documentation for further details.
   */
  final bool applyAuthorStyles;

  /**
   * Set the shadow root resetStyleInheritance property. See shadow-DOM
   * documentation for further details.
   */
  final bool resetStyleInheritance;

  const NgComponent({
    this.template,
    this.templateUrl,
    this.cssUrl,
    this.publishAs,
    this.applyAuthorStyles,
    this.resetStyleInheritance,
    map,
    selector,
    visibility,
    publishTypes : const <Type>[],
    exportExpressions,
    exportExpressionAttrs
  }) : super(selector: selector, visibility: visibility,
      publishTypes: publishTypes, map: map,
      exportExpressions: exportExpressions,
      exportExpressionAttrs: exportExpressionAttrs);
}

RegExp _ATTR_NAME = new RegExp(r'\[([^\]]+)\]$');

class NgDirective extends NgAnnotationBase {
  static const String LOCAL_VISIBILITY = 'local';
  static const String CHILDREN_VISIBILITY = 'children';
  static const String DIRECT_CHILDREN_VISIBILITY = 'direct_children';

  final bool transclude;
  final String attrName;

  const NgDirective({
    this.transclude: false,
    this.attrName: null,
    map,
    selector,
    visibility,
    publishTypes : const <Type>[],
    exportExpressions,
    exportExpressionAttrs
  }) : super(selector: selector, visibility: visibility,
      publishTypes: publishTypes, map: map,
      exportExpressions: exportExpressions,
      exportExpressionAttrs: exportExpressionAttrs);

  get defaultAttributeName {
    if (attrName == null && selector != null) {
      var match = _ATTR_NAME.firstMatch(selector);
      return match != null ? match[1] : null;
    }
    return attrName;
  }
}

/**
 * Implementing directives or components [attach] method will be called when
 * the next scope digest occurs after component instantiation. It is guaranteed
 * that when [attach] is invoked, that all attribute mappings have already
 * been processed.
 */
abstract class NgAttachAware {
  void attach();
}

/**
 * Implementing directives or components [detach] method will be called when
 * the associated scope is destroyed.
 */
abstract class NgDetachAware {
  void detach();
}

/**
 * See:
 * http://www.html5rocks.com/en/tutorials/webcomponents/shadowdom-201/#toc-style-inheriting
 */
class NgShadowRootOptions {
  final bool applyAuthorStyles;
  final bool resetStyleInheritance;
  const NgShadowRootOptions([this.applyAuthorStyles = false,
                             this.resetStyleInheritance = false]);
}

Map<Type, Directive> _directiveCache = new Map<Type, Directive>();

// TODO(pavelgj): Get rid of Directive and use NgComponent/NgDirective directly.
class Directive {
  static int STRUCTURAL_PRIORITY = 2;
  static int ATTR_PRIORITY = 1;
  static int COMPONENT_PRIORITY = 0;

  Type type;
  NgAnnotationBase annotation;


  String $selector;
  int $priority = Directive.ATTR_PRIORITY;
  String $template;
  String $templateUrl;
  String $cssUrl;
  String $publishAs;
  Map<String, String> $map;
  String $visibility;
  NgShadowRootOptions $shadowRootOptions = new NgShadowRootOptions();
  List<Type> $publishTypes = <Type>[];

  bool isComponent = false;

  Directive._new(Type this.type) {
    var annotations = [];
    annotations.addAll(_reflectMetadata(type, NgDirective));
    annotations.addAll(_reflectMetadata(type, NgComponent));
    if (annotations.length != 1) {
      throw 'Expecting exatly one annotation of type NgComponent or '
            'NgDirective on $type found ${annotations.length} annotations.';
    }
    annotation =  annotations.first;
  }

  factory Directive(Type type) {
    var instance = _directiveCache[type];
    if (instance != null) {
      return instance;
    }

    instance = new Directive._new(type);
    var name = type.toString();
    var isAttr = false;
    instance.$selector = name.splitMapJoin(
        new RegExp(r'[A-Z]'),
        onMatch: (m) => '-' + m.group(0).toLowerCase())
      .substring(1);

    var directive = _reflectSingleMetadata(type, NgDirective);
    var component = _reflectSingleMetadata(type, NgComponent);
    if (directive != null && component != null) {
      throw 'Cannot have both NgDirective and NgComponent annotations.';
    }

    if (directive != null) {
      instance.$selector = directive.selector;
      instance.$visibility = directive.visibility;
      instance.$publishTypes = directive.publishTypes;
      instance.$map = directive.map;
    }
    if (component != null) {
      instance.isComponent = true;
      instance.$priority = Directive.COMPONENT_PRIORITY;
      instance.$template = component.template;
      instance.$selector = component.selector;
      instance.$templateUrl = component.templateUrl;
      instance.$cssUrl = component.cssUrl;
      instance.$visibility = component.visibility;
      instance.$map = component.map;
      instance.$publishAs = component.publishAs;
      instance.$shadowRootOptions =
          new NgShadowRootOptions(component.applyAuthorStyles,
                                  component.resetStyleInheritance);
      instance.$publishTypes = component.publishTypes;
    }

    if (instance.$selector == null || instance.$selector.isEmpty) {
      throw new Exception('Selector is required on $type.');
    }

    if (instance.$map == null) {
      instance.$map = new Map<String, String>();
    }
    _directiveCache[type] = instance;
    if (instance.annotation is NgDirective && instance.annotation.transclude) {
      instance.$priority = Directive.STRUCTURAL_PRIORITY;
    }
    return instance;
  }
}

Map<Type, ClassMirror> _reflectionCache = new Map<Type, ClassMirror>();

// A hack for slow reflectClass.
ClassMirror fastReflectClass(Type type) {
  ClassMirror reflectee = _reflectionCache[type];
  if (reflectee == null) {
    reflectee = reflectClass(type);
    _reflectionCache[type] = reflectee;
  }
  return reflectee;
}

/**
 * A set of functions which build on top of dart:mirrors making them
 * easier to use.
 */

// Return the value of a type's static field or null if it is not defined.
_reflectStaticField(Type type, String field) {
  Symbol fieldSym = new Symbol(field);
  var reflection = fastReflectClass(type);
  if (!reflection.members.containsKey(fieldSym)) return null;
  if (!reflection.members[fieldSym].isStatic) return null;

  var fieldReflection = reflection.getField(fieldSym);
  if (fieldReflection == null) return null;
  return fieldReflection.reflectee;
}

// TODO(pavelgj): cache.
Iterable _reflectMetadata(Type type, Type metadata) {
  var meta = fastReflectClass(type).metadata;
  if (meta == null) {
    throw "Type $type does not have metadata. Syntax error, perhaps?";
  }
  return meta.where((InstanceMirror im) => im.reflectee.runtimeType == metadata)
  .map((InstanceMirror im) => im.reflectee);
}

_reflectSingleMetadata(Type type, Type metadataType) {
  var metadata = _reflectMetadata(type, metadataType);
  if (metadata.length == 0) {
    return null;
  }
  if (metadata.length > 1) {
    throw 'Expecting not more than one annotation of type $metadataType';
  }
  return metadata.first;
}

dynamic _defaultIfNull(dynamic value, dynamic defaultValue) =>
    value == null ? defaultValue : value;

class DirectiveRegistry {
  Map<String, Directive> directiveMap = {};

  List<String> enumerate() => directiveMap.keys.toList();

  register(Type directiveType) {
   var directive = new Directive(directiveType);

   directiveMap[directive.$selector] = directive;
  }

  Directive operator[](String selector) {
    if (directiveMap.containsKey(selector)){
      return directiveMap[selector];
    } else {
      throw new ArgumentError('Unknown selector: $selector');
    }
  }
}
