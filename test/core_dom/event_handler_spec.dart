library event_handler_spec;

import '../_specs.dart';

@Component(selector: 'bar',
    template: '''
              <div>
                <span on-abc="ctrl.invoked=true;"></span>
                <content></content>
              </div>
              ''',
    publishAs: 'ctrl')
class BarComponent {
  var invoked = false;
  BarComponent(RootScope scope) {
    scope.context['barComponent'] = this;
  }
}

main() {
  describe('EventHandler', () {
    Element ngAppElement;
    beforeEachModule((Module module) {
      ngAppElement = new DivElement()..attributes['ng-app'] = '';
      module..bind(BarComponent);
      module..bind(Node, toValue: ngAppElement);
      document.body.append(ngAppElement);
    });

    afterEach(() {
      ngAppElement.remove();
      ngAppElement = null;
    });

    compile(_, html) {
      ngAppElement.setInnerHtml(html, treeSanitizer: new NullTreeSanitizer());
      _.compile(ngAppElement);
      return ngAppElement.firstChild;
    }

    it('should register and handle event using on-* syntax', (TestBed _) {
      var e = compile(_, '''<div on-abc="invoked=true;"></div>''');

      _.triggerEvent(e, 'abc');

      expect(_.rootScope.context['invoked']).toBeTrue();
    });

    it('should expose event', (TestBed _) {
      var e = compile(_, '''<div on-abc="storedEvent=event;"></div>''');

      _.triggerEvent(e, 'abc', 'MouseEvent');

      expect(_.rootScope.context['storedEvent']).toBeAnInstanceOf(MouseEvent);
    });

    it('should register and handle event using (^*) syntax', (TestBed _) {
      var e = compile(_, '''<div (^abc)="invoked=true;"></div>''');

      _.triggerEvent(e, 'abc');

      expect(_.rootScope.context['invoked']).toBeTrue();
    });

    it('should register and handle event using (*) syntax', (TestBed _) {
      var e = compile(_, '''<div (abc)="invoked=true;"></div>''');

      _.triggerEvent(e, 'abc');

      expect(_.rootScope.context['invoked']).toBeTrue();
    });

    it('should call (*) event handlers only when the target is the element it self', (TestBed _) {
      var e = compile(_, '''<div (abc)="invoked=true;"><span></span></div>''');

      _.triggerEvent(e.querySelector("span"), 'abc');

      expect(_.rootScope.context['invoked']).toBeNull();
    });

    it('shoud register and handle event with long name', (TestBed _) {
      var e = compile(_, '''<div on-my-new-event="invoked=true;"></div>''');

      _.triggerEvent(e, 'my-new-event');
      expect(_.rootScope.context['invoked']).toBeTrue();
    });

    it('shoud have model updates applied correctly', (TestBed _) {
      var e = compile(_,
        '''<div on-abc='description="new description";'>{{description}}</div>''');
      e.dispatchEvent(new Event('abc'));
      _.rootScope.apply();
      expect(e.text).toEqual("new description");
    });

    it('shoud register event when shadow dom is used', async((TestBed _) {
      var e = compile(_,'<bar></bar>');

      microLeap();

      var shadowRoot = e.shadowRoot;
      var span = shadowRoot.querySelector('span');
      span.dispatchEvent(new CustomEvent('abc'));
      BarComponent ctrl = _.rootScope.context['barComponent'];
      expect(ctrl.invoked).toEqual(true);
    }));

    it('shoud handle event within content only once', async((TestBed _) {
      var e = compile(_,
        ''' <bar>
               <div on-abc="ctrl.invoked=true;"></div>
             </bar>
           ''');

      microLeap();

      document.querySelector('[on-abc]').dispatchEvent(new Event('abc'));
      var shadowRoot = document.querySelector('bar').shadowRoot;
      var shadowRootScope = _.getScope(shadowRoot);
      BarComponent ctrl = shadowRootScope.context['ctrl'];
      expect(ctrl.invoked).toEqual(false);

      expect(_.rootScope.context['ctrl']['invoked']).toEqual(true);
    }));
  });
}
