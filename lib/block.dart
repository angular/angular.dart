part of angular;

String _SHADOW = 'SHADOW_INJECTOR';

/**
* ElementWrapper is an interface for [Block]s and [BlockHole]s. Its purpose is
* to allow treating [Block] and [BlockHole] under same interface so that
* [Block]s can be added after [BlockHole].
*/
abstract class ElementWrapper {
  List<dom.Node> elements;
  ElementWrapper next;
  ElementWrapper previous;
}

/**
 * A Block is a fundamental building block of DOM. It is a chunk of DOM which
 * Can not be structural changed. It can only have its attributes changed.
 * A Block can have [BlockHole]s embedded in its DOM.  A [BlockHole] can
 * contain other [Block]s and it is the only way in which DOM can be changed
 * structurally.
 *
 * A [Block] is a collection of DOM nodes and [Directive]s for those nodes.
 *
 * A [Block] is responsible for instantiating the [Directive]s and for
 * inserting / removing itself to/from DOM.
 *
 * A [Block] can be created from [BlockFactory].
 *
 */
class Block implements ElementWrapper {
  List<dom.Node> elements;
  ElementWrapper previous = null;
  ElementWrapper next = null;

  Function onInsert;
  Function onRemove;
  Function onMove;

  Injector _injector;
  List<dynamic> _directives = [];

  Block(List<dom.Node> this.elements);

  Block insertAfter(ElementWrapper previousBlock) {
    // TODO(misko): this will try to insert regardless if the node is an existing server side pre-rendered instance.
    // This is inefficient since the node should already be at the right location. We should have a check
    // for that. If pre-rendered then do nothing. This will also short circuit animation.

    // Update Link List.
    next = previousBlock.next;
    if (next != null) {
      next.previous = this;
    }
    previous = previousBlock;
    previousBlock.next = this;

    // Update DOM
    List<dom.Node> previousElements = previousBlock.elements;
    dom.Node previousElement = previousElements[previousElements.length - 1];
    dom.Node insertBeforeElement = previousElement.nextNode;
    dom.Node parentElement = previousElement.parentNode;
    bool preventDefault = false;

    Function insertDomElements = () {
      for(var i = 0, ii = elements.length; i < ii; i++) {
        parentElement.insertBefore(elements[i], insertBeforeElement);
      }
    };

    if (onInsert != null) {
      onInsert({
        "preventDefault": () {
          preventDefault = true;
          return insertDomElements;
        },
        "element": elements[0]
      });
    }

    if (!preventDefault) {
      insertDomElements();
    }
    return this;
  }

  Block remove() {
    bool preventDefault = false;

    Function removeDomElements = () {
      for(var j = 0, jj = elements.length; j < jj; j++) {
        dom.Node current = elements[j];
        dom.Node next = j+1 < jj ? elements[j+1] : null;

        while(next != null && current.nextNode != next) {
          current.nextNode.remove();
        }
        elements[j].remove();
      }
    };

    if (onRemove != null) {
      onRemove({
        "preventDefault": () {
          preventDefault = true;
          return removeDomElements();
        },
        "element": elements[0]
      });
    }

    if (!preventDefault) {
      removeDomElements();
    }

    // Remove block from list
    if (previous != null && (previous.next = next) != null) {
      next.previous = previous;
    }
    next = previous = null;
    return this;
  }

  Block moveAfter(ElementWrapper previousBlock) {
    var previousElements = previousBlock.elements,
        previousElement = previousElements[previousElements.length - 1],
        insertBeforeElement = previousElement.nextNode,
        parentElement = previousElement.parentNode,
        blockElements = elements;

    for(var i = 0, ii = blockElements.length; i < ii; i++) {
      parentElement.insertBefore(blockElements[i], insertBeforeElement);
    }

    // Remove block from list
    previous.next = next;
    if (next != null) {
      next.previous = previous;
    }
    // Add block to list
    next = previousBlock.next;
    if (next != null) {
      next.previous = this;
    }
    previous = previousBlock;
    previousBlock.next = this;
    return this;
  }
}

/**
 * ComponentFactory is responsible for setting up components. This includes
 * the shadowDom, fetching template, importing styles, setting up attribute
 * mappings, publishing the controller, and compiling and caching the template.
 */
class _ComponentFactory {

  dom.Element element;
  Directive directive;
  dom.ShadowRoot shadowDom;
  Scope shadowScope;
  Injector shadowInjector;
  Compiler compiler;
  var controller;

  _ComponentFactory(this.element, this.directive);

  dynamic call(Injector injector, Compiler compiler, Scope scope,
      BlockCache $blockCache,  Http $http,
      TemplateCache $templateCache) {
    this.compiler = compiler;
    shadowDom = element.createShadowRoot();
    shadowDom.applyAuthorStyles =
        directive.$shadowRootOptions.applyAuthorStyles;
    shadowDom.resetStyleInheritance =
        directive.$shadowRootOptions.resetStyleInheritance;

    shadowScope = scope.$new(true);
    // TODO(pavelgj): fetching CSS with Http is mainly an attempt to
    // work around an unfiled Chrome bug when reloading same CSS breaks
    // styles all over the page. We shouldn't be doing browsers work,
    // so change back to using @import once Chrome bug is fixed or a
    // better work around is found.
    async.Future<String> cssFuture;
    if (directive.$cssUrl != null) {
      cssFuture = $http.getString(directive.$cssUrl, cache: $templateCache);
    } else {
      cssFuture = new async.Future.value(null);
    }
    var blockFuture;
    if (directive.$template != null) {
      blockFuture =
          new async.Future.value($blockCache.fromHtml(directive.$template));
    } else if (directive.$templateUrl != null) {
      blockFuture = $blockCache.fromUrl(directive.$templateUrl);
    }
    TemplateLoader templateLoader = new TemplateLoader(
        cssFuture.then((String css) {
          if (css != null) {
            shadowDom.innerHtml = '<style>$css</style>';
          }
          if (blockFuture != null) {
            return blockFuture.then((BlockFactory blockFactory) =>
                attachBlockToShadowDom(blockFactory));
          }
          return shadowDom;
        }));
    controller =
        createShadowInjector(injector, templateLoader).get(directive.type);
    if (directive.$publishAs != null) {
      shadowScope[directive.$publishAs] = controller;
    }
    return controller;
  }

  attachBlockToShadowDom(BlockFactory blockFactory) {
    var block = blockFactory(shadowInjector);
    shadowDom.nodes.addAll(block.elements);
    return shadowDom;
  }

  createShadowInjector(injector, TemplateLoader templateLoader) {
    var shadowModule = new ScopeModule(shadowScope)
      ..type(directive.type)
      ..value(TemplateLoader, templateLoader)
      ..value(dom.ShadowRoot, shadowDom);
    shadowInjector = injector.createChild([shadowModule], name: _SHADOW);
    return shadowInjector;
  }
}

/**
 * BlockCache is used to cache the compilation of templates into [Block]s.
 * It can be used synchronously if HTML is known or asynchronously if the
 * template HTML needs to be looked up from the URL.
 */
class BlockCache {
  Cache _blockCache;
  Http $http;
  TemplateCache $templateCache;
  Compiler compiler;

  BlockCache(CacheFactory $cacheFactory, Http this.$http,
      TemplateCache this.$templateCache, Compiler this.compiler) {
    _blockCache = $cacheFactory('blocks');
  }

  BlockFactory fromHtml(String html) {
    BlockFactory blockFactory = _blockCache.get(html);
    if (blockFactory == null) {
      var div = new dom.Element.tag('div');
      div.innerHtml = html;
      blockFactory = compiler(div.nodes);
      _blockCache.put(html, blockFactory);
    }
    return blockFactory;
  }

  async.Future<BlockFactory> fromUrl(String url) {
    return $http.getString(url, cache: $templateCache).then((String tmpl) {
      return fromHtml(tmpl);
    });
  }
}

/**
 * A convenience wrapper for "templates" cache, its purpose is
 * to create new Type which can be used for injection.
 */
class TemplateCache implements Cache<HttpResponse> {
  Cache _cache;

  TemplateCache(CacheFactory $cacheFactory) {
    _cache = $cacheFactory('templates');
  }

  Object get(key) => _cache.get(key);
  put(key, HttpResponse value) => _cache.put(key, value);
  putString(key, String value) => _cache.put(key, new HttpResponse(200, value));
  void remove(key) => _cache.remove(key);
  void removeAll() => _cache.removeAll();
  CacheInfo info() => _cache.info();
  void destroy() => _cache.destroy();
}

/**
 * TemplateLoader is an asynchronous access to ShadowRoot which is
 * loaded asynchronously. It allows a Component to be notified when its
 * ShadowRoot is ready.
 */
class TemplateLoader {
  final async.Future<dom.ShadowRoot> _template;
  async.Future<dom.ShadowRoot> get template => _template;
  TemplateLoader(this._template);
}

/**
 * NodeAttrs is a facade for node attributes. The facade is responsible
 * for normalizing attribute names as well as allowing access to the
 * value of the directive.
 */
class NodeAttrs {
  dom.Node node;

  NodeAttrs(dom.Node this.node);

  operator []=(String name, String value) => node.attributes[name] = value;
  operator [](name) {
    return node.attributes[name];
  }

  dom.Element get element => node;
}

/**
 * A BlockHole is an instance of a hole. BlockHoles designate where child
 * [Block]s can be added in parent [Block]. BlockHoles wrap a DOM element,
 * and act as references which allows more blocks to be added.
 */
class BlockHole extends ElementWrapper {
  List<dom.Node> elements;

  ElementWrapper previous;
  ElementWrapper next;

  BlockHole(List<dom.Node> this.elements);
}

/**
 * BoundBlockFactory is a [BlockFactory] which does not need Injector because
 * it is pre-bound to an injector from the parent. This means that this
 * BoundBlockFactory can only be used from within a specific Directive such
 * as [NgRepeat], but it can not be stored in a cache.
 *
 * The BoundBlockFactory needs [Scope] to be created.
 */
class BoundBlockFactory {
  BlockFactory blockFactory;
  Injector injector;

  BoundBlockFactory(BlockFactory this.blockFactory, Injector this.injector);

  Block call(Scope scope) {
    return blockFactory(injector.createChild([new ScopeModule(scope)]));
  }
}

/**
 * BlockFactory is used to create new [Block]s. BlockFactory is created by the
 * [Compiler] as a result of compiling a template.
 */
class BlockFactory {
  List directivePositions;
  List<dom.Node> templateElements;
  Profiler _perf;

  BlockFactory(this.templateElements, this.directivePositions, this._perf) {
    ASSERT(templateElements != null);
    ASSERT(directivePositions != null);
  }

  BoundBlockFactory bind(Injector injector) {
    return new BoundBlockFactory(this, injector);
  }

  Block call(Injector injector, [List<dom.Node> elements]) {
    if (elements == null) {
      elements = cloneElements(templateElements);
    }
    var block = new Block(elements);
    _link(block, elements, directivePositions, injector);
    return block;
  }

  _link(Block block, List<dom.Node> nodeList, List directivePositions, Injector parentInjector) {
    var preRenderedIndexOffset = 0;
    var directiveDefsByName = {};

    for (num i = 0, ii = directivePositions.length; i < ii;) {
      num index = directivePositions[i++];

      List<DirectiveRef> directiveRefs = directivePositions[i++];
      List childDirectivePositions = directivePositions[i++];
      var nodeListIndex = index + preRenderedIndexOffset;
      dom.Node node = nodeList[nodeListIndex];

      // if node isn't attached to the DOM, create a parent for it.
      var parentNode = node.parentNode;
      var fakeParent = false;
      if (parentNode == null) {
        fakeParent = true;
        parentNode = new dom.DivElement();
        parentNode.append(node);
      }

      var childInjector = _instantiateDirectives(block, parentInjector, node,
          directiveRefs, parentInjector.get(Parser));

      if (childDirectivePositions != null) {
        _link(block, node.nodes, childDirectivePositions, childInjector);
      }

      if (fakeParent) {
        // extract the node from the parentNode.
        nodeList[nodeListIndex] = parentNode.nodes[0];
      }
    }
  }

  Injector _instantiateDirectives(Block block,
                                  Injector parentInjector, dom.Node node,
                                  List<DirectiveRef> directiveRefs,
                                  Parser parser) =>
  _perf.time('angular.blockFactory.instantiateDirectives', () {
    if (directiveRefs == null || directiveRefs.length == 0) return parentInjector;
    var nodeModule = new Module();
    var blockHoleFactory = (_) => null;
    var blockFactory = (_) => null;
    var boundBlockFactory = (_) => null;
    var nodeAttrs = new NodeAttrs(node);
    var nodesAttrsDirectives = null;
    Map<Type, _ComponentFactory> fctrs;

    nodeModule.value(Block, block);
    nodeModule.value(dom.Element, node);
    nodeModule.value(dom.Node, node);
    nodeModule.value(NodeAttrs, nodeAttrs);
    directiveRefs.forEach((DirectiveRef ref) {
      Type type = ref.directive.type;
      _NgAnnotationBase annotation = ref.directive.annotation;
      var visibility = _elementOnly;
      if (ref.directive.$visibility == NgDirective.CHILDREN_VISIBILITY) {
        visibility = null;
      } else if (ref.directive.$visibility == NgDirective.DIRECT_CHILDREN_VISIBILITY) {
        visibility = _elementDirectChildren;
      }
      if (ref.directive.type == NgTextMustacheDirective) {
        nodeModule.factory(NgTextMustacheDirective, (Injector injector) {
          return new NgTextMustacheDirective(node, ref.value,
              injector.get(Interpolate), injector.get(Scope));
        });
      } else if (ref.directive.type == NgAttrMustacheDirective) {
        if (nodesAttrsDirectives == null) {
          nodesAttrsDirectives = [];
          nodeModule.factory(NgAttrMustacheDirective, (Injector injector) {
            nodesAttrsDirectives.forEach((ref) {
              new NgAttrMustacheDirective(node, ref.value,
                  injector.get(Interpolate), injector.get(Scope));
            });
          });
        }
        nodesAttrsDirectives.add(ref);
      } else if (ref.directive.isComponent) {
        //nodeModule.factory(type, new ComponentFactory(node, ref.directive), visibility: visibility);
        // TODO(misko): there should be no need to wrap function like this.
        nodeModule.factory(type, (Injector injector) {
            Compiler compiler = injector.get(Compiler);
            Scope scope = injector.get(Scope);
            BlockCache blockCache = injector.get(BlockCache);
            Http http = injector.get(Http);
            TemplateCache templateCache = injector.get(TemplateCache);
            // This is a bit of a hack since we are returning different type then we are.
            var componentFactory = new _ComponentFactory(node, ref.directive);
            if (fctrs == null) fctrs = new Map<Type, _ComponentFactory>();
            fctrs[type] = componentFactory;
            return componentFactory(injector, compiler, scope, blockCache, http, templateCache);
          },
          visibility: visibility);
      } else {
        nodeModule.type(type, visibility: visibility);
      }
      for (var publishType in ref.directive.$publishTypes) {
        nodeModule.factory(publishType,
            (Injector injector) => injector.get(type),
            visibility: visibility);
      }
      if (annotation is NgDirective && annotation.transclude) {
        blockHoleFactory = (_) => new BlockHole([node]);
        blockFactory = (_) => ref.blockFactory;
        boundBlockFactory = (Injector injector) => ref.blockFactory.bind(injector);
      }
    });
    nodeModule.factory(BlockHole, blockHoleFactory);
    nodeModule.factory(BlockFactory, blockFactory);
    nodeModule.factory(BoundBlockFactory, boundBlockFactory);
    var nodeInjector = parentInjector.createChild([nodeModule]);
    var scope = nodeInjector.get(Scope);
    directiveRefs.forEach((ref) {
      var controller = nodeInjector.get(ref.directive.type);
      var shadowScope = (fctrs != null && fctrs.containsKey(ref.directive.type))
          ? fctrs[ref.directive.type].shadowScope : null;
      _createAttributeMapping(ref, node, scope, shadowScope, controller, parser);
      if (understands(controller, 'attach')) {
        var removeWatcher;
        removeWatcher = scope.$watch(() {
          removeWatcher();
          controller.attach();
        });
      }
      if (understands(controller, 'detach')) {
        scope.$on(r'$destroy', controller.detach);
      }
    });
    return nodeInjector;
  });

  /// DI visibility callback allowing node-local visibility.
  bool _elementOnly(Injector requesting, Injector defining) {
    if (requesting.name == _SHADOW) {
      requesting = requesting.parent;
    }
    return identical(requesting, defining);
  }

  /// DI visibility callback allowing visibility from direct child into parent.
  bool _elementDirectChildren(Injector requesting, Injector defining) {
    if (requesting.name == _SHADOW) {
      requesting = requesting.parent;
    }
    return _elementOnly(requesting, defining) || identical(requesting.parent, defining);
  }
}

RegExp _MAPPING = new RegExp(r'^([\@\=\&])(\.?)\s*(.*)$');
_createAttributeMapping(DirectiveRef directiveRef, dom.Node element,
                        Scope scope, Scope shadowScope,
                        Object controller, Parser parser) {
  Directive directive = directiveRef.directive;
  directive.$map.forEach((attrName, mapping) {
    Match match = _MAPPING.firstMatch(mapping);
    if (match == null) {
      throw "Unknown mapping '$mapping' for attribute '$attrName'.";
    }
    var attrValue = attrName == '.'
        ? directiveRef.value
        : element.attributes[snakeCase(attrName, '-')];
    if (attrValue == null) attrValue = '';

    var mode = match[1];
    var controllerContext = match[2];
    var dstPath = match[3];
    var context = controllerContext == '.' ? controller : shadowScope;

    Expression dstPathFn = parser(dstPath.isEmpty ? attrName : dstPath);
    if (!dstPathFn.assignable) {
      throw "Expression '$dstPath' is not assignable in mapping '$mapping' for attribute '$attrName'.";
    }
    switch(mode) {
      case '@':
        dstPathFn.assign(context, attrValue);
        break;
      case '=':
        Expression attrExprFn = parser(attrValue);
        var shadowValue = null;
        scope.$watch(
                () => attrExprFn.eval(scope),
                (v) => dstPathFn.assign(context, shadowValue = v));
        if (shadowScope != null) {
          if (attrExprFn.assignable) {
            shadowScope.$watch(
                    () => dstPathFn.eval(context),
                    (v) {
                  if (shadowValue != v) {
                    shadowValue = v;
                    attrExprFn.assign(scope, v);
                  }
                });
          }
        }
        break;
      case '&':
        dstPathFn.assign(context, parser(attrValue).bind(scope));
        break;
    }
  });
}
