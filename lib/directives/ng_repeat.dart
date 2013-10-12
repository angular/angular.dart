part of angular.directive;

class _Row {
  var id;
  Scope scope;
  Block block;
  dom.Element startNode;
  dom.Element endNode;
  List<dom.Element> elements;

  _Row(this.id);
}

/**
 * @ngdoc directive
 * @name ng.directive:ngRepeat
 *
 * @description
 * The `ngRepeat` directive instantiates a template once per item from a collection. Each template
 * instance gets its own scope, where the given loop variable is set to the current collection item,
 * and `$index` is set to the item index or key.
 *
 * Special properties are exposed on the local scope of each template instance, including:
 *
 * | Variable  | Type            | Details                                                                     |
 * |-----------|-----------------|-----------------------------------------------------------------------------|
 * | `$index`  | {@type number}  | iterator offset of the repeated element (0..length-1)                       |
 * | `$first`  | {@type boolean} | true if the repeated element is first in the iterator.                      |
 * | `$middle` | {@type boolean} | true if the repeated element is between the first and last in the iterator. |
 * | `$last`   | {@type boolean} | true if the repeated element is last in the iterator.                       |
 * | `$even`   | {@type boolean} | true if the iterator position `$index` is even (otherwise false).           |
 * | `$odd`    | {@type boolean} | true if the iterator position `$index` is odd (otherwise false).            |
 *
 *
 * @element ANY
 * @scope
 * @priority 1000
 * @param {repeat_expression} ngRepeat The expression indicating how to enumerate a collection. These
 *   formats are currently supported:
 *
 *   * `variable in expression` – where variable is the user defined loop variable and `expression`
 *     is a scope expression giving the collection to enumerate.
 *
 *     For example: `album in artist.albums`.
 *
 *   * `(key, value) in expression` – where `key` and `value` can be any user defined identifiers,
 *     and `expression` is the scope expression giving the collection to enumerate.
 *
 *     For example: `(name, age) in {'adam':10, 'amalie':12}`.
 *
 *   * `variable in expression track by tracking_expression` – You can also provide an optional tracking function
 *     which can be used to associate the objects in the collection with the DOM elements. If no tracking function
 *     is specified the ng-repeat associates elements by identity in the collection. It is an error to have
 *     more than one tracking function to resolve to the same key. (This would mean that two distinct objects are
 *     mapped to the same DOM element, which is not possible.)  Filters should be applied to the expression,
 *     before specifying a tracking expression.
 *
 *     For example: `item in items` is equivalent to `item in items track by $id(item)'. This implies that the DOM elements
 *     will be associated by item identity in the array.
 *
 *     For example: `item in items track by $id(item)`. A built in `$id()` function can be used to assign a unique
 *     `$$hashKey` property to each item in the array. This property is then used as a key to associated DOM elements
 *     with the corresponding item in the array by identity. Moving the same object in array would move the DOM
 *     element in the same way ian the DOM.
 *
 *     For example: `item in items track by item.id` is a typical pattern when the items come from the database. In this
 *     case the object identity does not matter. Two objects are considered equivalent as long as their `id`
 *     property is same.
 *
 *     For example: `item in items | filter:searchText track by item.id` is a pattern that might be used to apply a filter
 *     to items in conjunction with a tracking expression.
 *
 *
 * Example:
 *
 *  <ul ng-repeat="item in ['foo', 'bar', 'baz']">
 *    <li>{{$item}}</li>
 *  </ul>
 */

@NgDirective(
    children: NgAnnotation.TRANSCLUDE_CHILDREN,
    selector: '[ng-repeat]',
    map: const {'.': '@.expression'})
class NgRepeatDirective  {
  static RegExp SYNTAX = new RegExp(r'^\s*(.+)\s+in\s+(.*?)\s*(\s+track\s+by\s+(.+)\s*)?$');
  static RegExp LHS_SYNTAX = new RegExp(r'^(?:([\$\w]+)|\(([\$\w]+)\s*,\s*([\$\w]+)\))$');

  BlockHole blockHole;
  BoundBlockFactory boundBlockFactory;
  Scope scope;

  String _expression;
  String valueIdentifier;
  String keyIdentifier;
  String listExpr;
  Map<Object, _Row> rows = new Map<dynamic, _Row>();
  Function trackByIdFn = (key, value, index) => value;
  Function removeWatch = () => null;

  NgRepeatDirective(BlockHole this.blockHole,
                        BoundBlockFactory this.boundBlockFactory,
                        Scope this.scope);

  set expression(value) {
    _expression = value;
    removeWatch();
    Match match = SYNTAX.firstMatch(_expression);
    if (match == null) {
      throw "[NgErr7] ngRepeat error! Expected expression in form of '_item_ in _collection_[ track by _id_]' but got '$_expression'.";
    }
    listExpr = match.group(2);
    var assignExpr = match.group(1);
    match = LHS_SYNTAX.firstMatch(assignExpr);
    if (match == null) {
      throw "[NgErr8] ngRepeat error! '_item_' in '_item_ in _collection_' should be an identifier or '(_key_, _value_)' expression, but got '$assignExpr'.";
    }
    valueIdentifier = match.group(3);
    if (valueIdentifier == null) valueIdentifier = match.group(1);
    keyIdentifier = match.group(2);

    removeWatch = scope.$watchCollection(listExpr, _onCollectionChange);
  }

  List<_Row> _computeNewRows(collection, trackById) {
    List<_Row> newRowOrder = [];
    // Same as lastBlockMap but it has the current state. It will become the
    // lastBlockMap on the next iteration.
    Map<dynamic, _Row> newRows = new Map<dynamic, _Row>();
    var arrayLength = collection.length;
    // locate existing items
    var length = newRowOrder.length = collection.length;
    for (var index = 0; index < length; index++) {
      var value = collection[index];
      trackById = trackByIdFn(index, value, index);
      if (rows.containsKey(trackById)) {
        var row = rows[trackById];
        rows.remove(trackById);
        newRows[trackById] = row;
        newRowOrder[index] = row;
      } else if (newRows.containsKey(trackById)) {
        // restore lastBlockMap
        newRowOrder.forEach((row) {
          if (row != null && row.startNode != null) {
            rows[row.id] = row;
          }
        });
        // This is a duplicate and we need to throw an error
        throw "[NgErr50] ngRepeat error! Duplicates in a repeater are not allowed. Use 'track by' expression to specify unique keys. Repeater: $_expression, Duplicate key: $trackById";
      } else {
        // new never before seen row
        newRowOrder[index] = new _Row(trackById);
        newRows[trackById] = null;
      }
    }
    // remove existing items
    rows.forEach((key, row){
      row.block.remove();
      row.scope.$destroy();
    });
    rows = newRows;
    return newRowOrder;
  }

  _onCollectionChange(collection) {
    var previousNode = blockHole.elements[0],     // current position of the node
        nextNode,
        childScope,
        trackById,
        cursor = blockHole;

    if (collection is! List) {
      collection = [];
    }

    List<_Row> newRowOrder = _computeNewRows(collection, trackById);

    for (var index = 0, length = collection.length; index < length; index++) {
      var key = index;
      var value = collection[index];
      _Row row = newRowOrder[index];

      if (row.startNode != null) {
        // if we have already seen this object, then we need to reuse the
        // associated scope/element
        childScope = row.scope;

        nextNode = previousNode;
        do {
          nextNode = nextNode.nextNode;
        } while(nextNode != null);

        if (row.startNode == nextNode) {
          // do nothing
        } else {
          // existing item which got moved
          row.block.moveAfter(cursor);
        }
        previousNode = row.endNode;
      } else {
        // new item which we don't know about
        childScope = scope.$new();
      }

      childScope[valueIdentifier] = value;
      childScope[r'$index'] = index;
      childScope[r'$first'] = (index == 0);
      childScope[r'$last'] = (index == (collection.length - 1));
      childScope[r'$middle'] = !(childScope.$first || childScope.$last);

      if (row.startNode == null) {
        rows[row.id] = row;
        var block = boundBlockFactory(childScope);
        row.block = block;
        row.scope = childScope;
        row.elements = block.elements;
        row.startNode = row.elements[0];
        row.endNode = row.elements[row.elements.length - 1];
        block.insertAfter(cursor);
      }
      cursor = row.block;
    }
  }
}
