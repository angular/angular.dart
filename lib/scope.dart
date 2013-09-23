library angular.core.service.scope;

import 'dart:mirrors';
import 'dart:json';
import 'package:meta/meta.dart';
import 'package:perf_api/perf_api.dart';

import 'exception_handler.dart';
import 'parser/parser_library.dart';
import 'utils.dart';
import 'zone.dart';



/**
 * Used by [Scope.$on] to notify the listeners of events.
 */
class ScopeEvent {
  String name;
  Scope targetScope;
  Scope currentScope;
  bool propagationStopped = false;
  bool defaultPrevented = false;

  ScopeEvent(this.name, this.targetScope);

  stopPropagation () => propagationStopped = true;
  preventDefault() => defaultPrevented = true;
}

/**
 * Allows the configuration of [Scope.$digest] iteration maximum time-to-live
 * value. Digest keeps checking the state of the watcher getters until it
 * can execute one full iteration with no watchers triggering. TTL is used
 * to prevent an infinite loop where watch A triggers watch B which in turn
 * triggers watch A. If the system does not stabilize in TTL iteration then
 * an digest is stop an an exception is thrown.
 */
class ScopeDigestTTL {
  final num ttl;
  ScopeDigestTTL(): ttl = 5;
  ScopeDigestTTL.value(num this.ttl);
}

/**
 * Scope has two responsibilities. 1) to keep track af watches and 2)
 * to keep references to the model so that they are available for
 * data-binding.
 */
@proxy
class Scope implements Map {
  String $id;
  Scope $parent;
  Scope $root;
  num _nextId = 0;

  ExceptionHandler _exceptionHandler;
  Parser _parser;
  Zone _zone;
  num _ttl;
  String _phase;
  Map<String, Object> _properties = {};
  List<Function> _innerAsyncQueue;
  List<Function> _outerAsyncQueue;
  List<_Watch> _watchers = [];
  Map<String, List<Function>> _listeners = {};
  Scope _nextSibling, _prevSibling, _childHead, _childTail;
  bool _isolate = false;
  Profiler _perf;


  Scope(ExceptionHandler this._exceptionHandler, Parser this._parser,
      ScopeDigestTTL ttl, Zone this._zone, Profiler this._perf) {
    _properties[r'this']= this;
    _ttl = ttl.ttl;
    $root = this;
    $id = '_${$root._nextId++}';
    _innerAsyncQueue = [];
    _outerAsyncQueue = [];

    // Set up the zone to auto digest this scope.
    _zone.onTurnDone = $digest;

    _zone.interceptCall = (body) {
      _beginPhase('auto-digesting zoned call');
      try {
        return body();
      } finally {
        _clearPhase();
      }
    };
  }

  Scope._child(Scope this.$parent, bool this._isolate, Profiler this._perf) {
    _exceptionHandler = $parent._exceptionHandler;
    _parser = $parent._parser;
    _ttl = $parent._ttl;
    _properties[r'this'] = this;
    _zone = $parent._zone;
    $root = $parent.$root;
    $id = '_${$root._nextId++}';
    _innerAsyncQueue = $parent._innerAsyncQueue;
    _outerAsyncQueue = $parent._outerAsyncQueue;

    _prevSibling = $parent._childTail;
    if ($parent._childHead != null) {
      $parent._childTail._nextSibling = this;
      $parent._childTail = this;
    } else {
      $parent._childHead = $parent._childTail = this;
    }
  }

  _identical(a, b) =>
    identical(a, b) ||
    (a is String && b is String && a == b) ||
    (a is num && b is num && a.isNaN && b.isNaN);

  containsKey(String name) => this[name] != null;

  operator []=(String name, value) => _properties[name] = value;
  operator [](String name) {
    if (name == r'$id') return this.$id;
    if (name == r'$parent') return this.$parent;
    if (name == r'$root') return this.$root;
    var scope = this;
    do {
      if (scope._properties.containsKey(name)) {
        return scope._properties[name];
      } else if (!scope._isolate) {
        scope = scope.$parent;
      } else {
        return null;
      }
    } while(scope != null);
    return null;
  }

  noSuchMethod(Invocation invocation) {
    var name = MirrorSystem.getName(invocation.memberName);
    if (invocation.isGetter) {
      return this[name];
    } else if (invocation.isSetter) {
      var value = invocation.positionalArguments[0];
      name = name.substring(0, name.length - 1);
      this[name] = value;
      return value;
    } else {
      if (this[name] is Function) {
        return this[name]();
      } else {
        super.noSuchMethod(invocation);
      }
    }
  }



  $new([bool isolate = false]) {
    return new Scope._child(this, isolate, _perf);
  }


  $watch(watchExp, [Function listener]) {
    var watcher = new _Watch(_compileToFn(listener), _initWatchVal,
        _compileToFn(watchExp), watchExp.toString());

    // we use unshift since we use a while loop in $digest for speed.
    // the while loop reads in reverse order.
    _watchers.insert(0, watcher);

    return () => _watchers.remove(watcher);
  }

  $watchCollection(obj, listener) {
    var oldValue;
    var newValue;
    num changeDetected = 0;
    Function objGetter = _compileToFn(obj);
    List internalArray = [];
    Map internalMap = {};
    num oldLength = 0;

    var $watchCollectionWatch = () {
      newValue = objGetter(this);
      var newLength, key;

      if (newValue is! Map && newValue is! List) {
        if (!_identical(oldValue, newValue)) {
          oldValue = newValue;
          changeDetected++;
        }
      } else if (newValue is List) {
        if (!_identical(oldValue, internalArray)) {
          // we are transitioning from something which was not an array into array.
          oldValue = internalArray;
          oldLength = oldValue.length = 0;
          changeDetected++;
        }

        newLength = newValue.length;

        if (oldLength != newLength) {
          // if lengths do not match we need to trigger change notification
          changeDetected++;
          oldValue.length = oldLength = newLength;
        }
        // copy the items to oldValue and look for changes.
        for (var i = 0; i < newLength; i++) {
          if (!_identical(oldValue[i], newValue[i])) {
            changeDetected++;
            oldValue[i] = newValue[i];
          }
        }
      } else { // Map
        if (!_identical(oldValue, internalMap)) {
          // we are transitioning from something which was not an object into object.
          oldValue = internalMap = {};
          oldLength = 0;
          changeDetected++;
        }
        // copy the items to oldValue and look for changes.
        newLength = 0;
        newValue.forEach((key, value) {
          newLength++;
          if (oldValue.containsKey(key)) {
            if (!_identical(oldValue[key], value)) {
              changeDetected++;
              oldValue[key] = value;
            }
          } else {
            oldLength++;
            oldValue[key] = value;
            changeDetected++;
          }

        });
        if (oldLength > newLength) {
          // we used to have more keys, need to find them and destroy them.
          changeDetected++;
          var keysToRemove = [];
          oldValue.forEach((key, _) {
            if (!newValue.containsKey(key)) {
              oldLength--;
              keysToRemove.add(key);
            }
          });
          keysToRemove.forEach((k) {
            oldValue.remove(k);
          });
        }
      }
      return changeDetected;
    };

    var $watchCollectionAction = () {
      relaxFnApply(listener, [newValue, oldValue, this]);
    };

    return this.$watch($watchCollectionWatch, $watchCollectionAction);
  }


  /**
   * Add this function to your code if you want to add a $digest
   * and want to assert that the digest will be called on this turn.
   * This method will be deleted when we are comfortable with
   * auto-digesting scope.
   */
  $$verifyDigestWillRun() {
    _zone.assertInTurn();
  }

  $digest() => _perf.time('angular.scope.digest', () {
    var innerAsyncQueue = _innerAsyncQueue,
        length,
        dirty, _ttlLeft = _ttl,
        logIdx, logMsg;
    List<List<String>> watchLog = [];
    List<_Watch> watchers;
    _Watch watch;
    Scope next, current, target = this;

    _beginPhase('\$digest');
    try {
      do { // "while dirty" loop
        dirty = false;
        current = target;
        //asyncQueue = current._asyncQueue;
        //dump('aQ: ${asyncQueue.length}');

        while(innerAsyncQueue.length > 0) {
          try {
            $root.$eval(innerAsyncQueue.removeAt(0));
          } catch (e, s) {
            _exceptionHandler(e, s);
          }
        }

        do { // "traverse the scopes" loop
          if ((watchers = current._watchers) != null) {
            // process our watches
            length = watchers.length;
            while (length-- > 0) {
              try {
                watch = watchers[length];
                var value = watch.get(current);
                var last = watch.last;
                if (!_identical(value, last)) {
                  dirty = true;
                  watch.last = value;
                  watch.fn(value, ((last == _initWatchVal) ? value : last), current);
                  if (_ttlLeft < 5) {
                    logIdx = 4 - _ttlLeft;
                    while (watchLog.length <= logIdx) {
                      watchLog.add([]);
                    }
                    logMsg = (watch.exp is Function)
                        ? 'fn: ' + (watch.exp.toString())
                        : watch.exp;
                    logMsg += '; newVal: ' + _toJson(value) + '; oldVal: ' + _toJson(last);
                    watchLog[logIdx].add(logMsg);
                  }
                }
              } catch (e, s) {
                _exceptionHandler(e, s);
              }
            }
          }

          // Insanity Warning: scope depth-first traversal
          // yes, this code is a bit crazy, but it works and we have tests to prove it!
          // this piece should be kept in sync with the traversal in $broadcast
          if (current._childHead == null) {
            if (current == target) {
              next = null;
            } else {
              next = current._nextSibling;
              if (next == null) {
                while(current != target && (next = current._nextSibling) == null) {
                  current = current.$parent;
                }
              }
            }
          } else {
            next = current._childHead;
          }
        } while ((current = next) != null);

        if(dirty && (_ttlLeft--) == 0) {
          throw '$_ttl \$digest() iterations reached. Aborting!\n' +
              'Watchers fired in the last 5 iterations: ${_toJson(watchLog)}';
        }
      } while (dirty || innerAsyncQueue.length > 0);
      while(_outerAsyncQueue.length > 0) {
        try {
          $root.$eval(_outerAsyncQueue.removeAt(0));
        } catch (e, s) {
          _exceptionHandler(e, s);
        }
      }
    } finally {
      _clearPhase();
    }
  });


  $destroy() {
    if ($root == this) return; // we can't remove the root node;

    $broadcast(r'$destroy');

    if ($parent._childHead == this) $parent._childHead = _nextSibling;
    if ($parent._childTail == this) $parent._childTail = _prevSibling;
    if (_prevSibling != null) _prevSibling._nextSibling = _nextSibling;
    if (_nextSibling != null) _nextSibling._prevSibling = _prevSibling;
  }


  $eval(expr, [locals]) {
    return relaxFnArgs(_compileToFn(expr))(this, locals);
  }


  $evalAsync(expr, {outsideDigest: false}) {
    if (outsideDigest) {
      _outerAsyncQueue.add(expr);
    } else {
      _innerAsyncQueue.add(expr);
    }
  }


  $apply([expr]) {
    return _zone.run(() {
      try {
        return $eval(expr);
      } catch (e, s) {
        _exceptionHandler(e, s);
      }
    });
  }


  $on(name, listener) {
    var namedListeners = _listeners[name];
    if (!_listeners.containsKey(name)) {
      _listeners[name] = namedListeners = [];
    }
    namedListeners.add(listener);

    return () {
      namedListeners.remove(listener);
    };
  }


  $emit(name, [List args]) {
    var empty = [],
        namedListeners,
        scope = this,
        event = new ScopeEvent(name, this),
        listenerArgs = [event],
        i;

    if (args != null) {
      listenerArgs.addAll(args);
    }

    do {
      namedListeners = scope._listeners[name];
      if (namedListeners != null) {
        event.currentScope = scope;
        i = 0;
        for (var length = namedListeners.length; i<length; i++) {
          try {
            relaxFnApply(namedListeners[i], listenerArgs);
            if (event.propagationStopped) return event;
          } catch (e, s) {
            _exceptionHandler(e, s);
          }
        }
      }
      //traverse upwards
      scope = scope.$parent;
    } while (scope != null);

    return event;
  }


  $broadcast(String name, [List listenerArgs]) {
    var target = this,
        current = target,
        next = target,
        event = new ScopeEvent(name, this);

    //down while you can, then up and next sibling or up and next sibling until back at root
    if (listenerArgs == null) {
      listenerArgs = [];
    }
    listenerArgs.insert(0, event);
    do {
      current = next;
      event.currentScope = current;
      if (current._listeners.containsKey(name)) {
        current._listeners[name].forEach((listener) {
          try {
            relaxFnApply(listener, listenerArgs);
          } catch(e, s) {
            _exceptionHandler(e, s);
          }
        });
      }

      // Insanity Warning: scope depth-first traversal
      // yes, this code is a bit crazy, but it works and we have tests to prove it!
      // this piece should be kept in sync with the traversal in $broadcast
      if (current._childHead == null) {
        if (current == target) {
          next = null;
        } else {
          next = current._nextSibling;
          if (next == null) {
            while(current != target && (next = current._nextSibling) == null) {
              current = current.$parent;
            }
          }
        }
      } else {
        next = current._childHead;
      }
    } while ((current = next) != null);

    return event;
  }

  _beginPhase(phase) {
    if ($root._phase != null) {
      // TODO(deboer): Remove the []s when dartbug.com/11999 is fixed.
      throw ['${$root._phase} already in progress'];
    }

    $root._phase = phase;
  }

  _clearPhase() {
    $root._phase = null;
  }

  Function _compileToFn(exp) {
    if (exp == null) {
      return () => null;
    } else if (exp is String) {
      return _parser(exp).eval;
    } else if (exp is Function) {
      return exp;
    } else {
      throw 'Expecting String or Function';
    }
  }
}

var _initWatchVal = new Object();

class _Watch {
  Function fn;
  dynamic last;
  Function get;
  String exp;

  _Watch(fn, this.last, getFn, this.exp) {
    this.fn = relaxFnArgs3(fn);
    this.get = relaxFnArgs1(getFn);
  }
}

_toJson(obj) {
  try {
    return stringify(obj);
  } catch(e) {
    return "NOT-JSONABLE";
  }
}
