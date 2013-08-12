part of angular;

String _COMPONENT = '-component';
String _DIRECTIVE = '-directive';
String _ATTR_DIRECTIVE = '-attr' + _DIRECTIVE;

class _NgAnnotationBase {
  final String selector;
  final String visibility;
  final List<Type> publishTypes;

  const _NgAnnotationBase({
    this.selector,
    this.visibility: NgDirective.LOCAL_VISIBILITY,
    this.publishTypes
  });
}

class NgComponent extends _NgAnnotationBase {
  final String template;
  final String templateUrl;
  final String cssUrl;
  final Map<String, String> map;
  final String publishAs;
  final bool applyAuthorStyles;
  final bool resetStyleInheritance;

  const NgComponent({
    this.template,
    this.templateUrl,
    this.cssUrl,
    this.map,
    this.publishAs,
    this.applyAuthorStyles,
    this.resetStyleInheritance,
    selector,
    visibility,
    publishTypes : const <Type>[]
  }) : super(selector: selector, visibility: visibility, publishTypes: publishTypes);
}

class NgDirective extends _NgAnnotationBase {
  static const String LOCAL_VISIBILITY = 'local';
  static const String CHILDREN_VISIBILITY = 'children';
  static const String DIRECT_CHILDREN_VISIBILITY = 'direct_children';

  final bool transclude;

  const NgDirective({
    this.transclude: false,
    selector,
    visibility,
    publishTypes : const <Type>[]
  }) : super(selector: selector, visibility: visibility, publishTypes: publishTypes);
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
  // TODO(misko): this should be renamed to selector once we change over to meta-data.
  String $name;
  Function $generate;
  bool $transclude = false;
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
  bool isStructural = false;

  Directive._new(Type this.type);

  factory Directive(Type type) {
    var instance = _directiveCache[type];
    if (instance != null) {
      return instance;
    }

    instance = new Directive._new(type);
    var name = type.toString();
    var isAttr = false;
    instance.$name = name.splitMapJoin(
        new RegExp(r'[A-Z]'),
        onMatch: (m) => '-' + m.group(0).toLowerCase())
      .substring(1);

    var directive = _reflectSingleMetadata(type, NgDirective);
    var component = _reflectSingleMetadata(type, NgComponent);
    if (directive != null && component != null) {
      throw 'Cannot have both NgDirective and NgComponent annotations.';
    }

    var selector;
    if (directive != null) {
      selector = directive.selector;
      instance.$transclude = directive.transclude;
      instance.$visibility = directive.visibility;
      instance.$publishTypes = directive.publishTypes;
    }
    if (component != null) {
      instance.$priority = Directive.COMPONENT_PRIORITY;
      instance.$template = component.template;
      selector = component.selector;
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

    if (selector != null) {
      instance.$name = selector;
    } else if (instance.$name.endsWith(_ATTR_DIRECTIVE)) {
      var attrName = instance.$name.
          substring(0, instance.$name.length - _ATTR_DIRECTIVE.length);
      instance.$name = '[$attrName]';
    } else if (instance.$name.endsWith(_DIRECTIVE)) {
      instance.$name = instance.$name.
          substring(0, instance.$name.length - _DIRECTIVE.length);
    } else if (instance.$name.endsWith(_COMPONENT)) {
      instance.isComponent = true;
      instance.$name = instance.$name.
          substring(0, instance.$name.length - _COMPONENT.length);
    } else {
      throw "Directive name '$name' must end with $_DIRECTIVE, "
            "$_ATTR_DIRECTIVE, $_COMPONENT or have a \$selector field.";
    }

    instance.isStructural = instance.$transclude;
    if (instance.isStructural) {
      instance.$priority = Directive.STRUCTURAL_PRIORITY;
    }
    if (instance.isComponent && instance.$map == null) {
      instance.$map = new Map<String, String>();
    }
    _directiveCache[type] = instance;
    return instance;
  }
}

_reflectSingleMetadata(Type type, Type metadataType) {
  var metadata = reflectMetadata(type, metadataType);
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

class DirectiveRef {
  dom.Node element;
  String value;
  Directive directive;
  BlockFactory blockFactory;

  DirectiveRef(dom.Node this.element, Directive this.directive, [
               String this.value,
               BlockFactory this.blockFactory]) {
  }

  String toString() {
    return '{ element: ${element.outerHtml}, selector: ${directive.$name}, value: $value }';
  }
}


class DirectiveRegistry {
  Map<String, Directive> directiveMap = {};

  List<String> enumerate() => directiveMap.keys.toList();

  register(Type directiveType) {
   var directive = new Directive(directiveType);

   directiveMap[directive.$name] = directive;
  }

  Directive operator[](String selector) {
    if (directiveMap.containsKey(selector)){
      return directiveMap[selector];
    } else {
      throw new ArgumentError('Unknown selector: $selector');
    }
  }
}
