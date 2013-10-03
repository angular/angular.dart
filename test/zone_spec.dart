library zone_spec;

import '_specs.dart';

import 'dart:async';

main() => describe('zone', () {
  var zone;
  beforeEach(inject((Logger log) {
    zone = new Zone();
    zone.onTurnDone = () {
      log('onTurnDone');
    };
  }));


  describe('exceptions', () {
    it('should throw exceptions from the body', () {
      var error;
      zone.onError = (e, s, l) => error = e;
      expect(() {
        zone.run(() {
          throw ['hello'];
        });
      }).toThrow('hello');
      expect(error).toEqual(['hello']);
    });


    it('should handle exceptions in onRunAsync', () {
      // TODO(deboer): Define how exceptions should behave in zones.
    });


    it('should handle exceptioned in onTurnDone', () {
      // TODO(deboer): Define how exceptions should behave in zones.
    });
  });


  it('should have nice error when crossing runAsync boundries', async(inject(() {
    var error;
    var stack;
    var longStacktrace;

    zone.onError = (e, s, f) {
      error = e;
      stack = s;
      longStacktrace = f;
    };
    var FRAME = new RegExp(r'.*\(.*\:(\d+):\d+\)');

    var line = ((){ try {throw [];} catch(e, s) { return int.parse(FRAME.firstMatch('$s')[1]);}})();
    var throwFn = () { throw ['double zonned']; };
    var inner = () => zone.run(throwFn);
    var middle = () => runAsync(inner);
    var outer = () => runAsync(middle);
    zone.run(outer);

    fastForward();
    expect(error).toEqual(['double zonned']);

    // Not in dart2js..
    if ('$stack'.contains('.dart.js')) {
      return;
    }

    expect('$stack').toContain('zone_spec.dart:${line+1}');
    expect('$stack').toContain('zone_spec.dart:${line+2}');
    expect('$longStacktrace').toContain('zone_spec.dart:${line+3}');
    expect('$longStacktrace').toContain('zone_spec.dart:${line+4}');
    expect('$longStacktrace').toContain('zone_spec.dart:${line+5}');
  })));

  it('should call onTurnDone after a synchronous block', inject((Logger log) {
    zone.run(() {
      log('run');
    });
    expect(log.result()).toEqual('run; onTurnDone');
  }));


  it('should return the body return value from run', () {
    expect(zone.run(() { return 6; })).toEqual(6);
  });


  it('should call onTurnDone for a runAsync in onTurnDone', async(inject((Logger log) {
    var ran = false;
    zone.onTurnDone = () {
      if (!ran) {
        runAsync(() { ran = true; log('onTurnAsync'); });
      }
      log('onTurnDone');
    };
    zone.run(() {
      log('run');
    });
    fastForward();

    expect(log.result()).toEqual('run; onTurnDone; onTurnAsync; onTurnDone');
  })));


  it('should call onTurnDone for a runAsync in onTurnDone triggered by a runAsync in run', async(inject((Logger log) {
    var ran = false;
    zone.onTurnDone = () {
      if (!ran) {
        runAsync(() { ran = true; log('onTurnAsync'); });
      }
      log('onTurnDone');
    };
    zone.run(() {
      runAsync(() { log('runAsync'); });
      log('run');
    });
    fastForward();

    expect(log.result()).toEqual('run; runAsync; onTurnDone; onTurnAsync; onTurnDone');
  })));



  it('should call onTurnDone once after a turn', async(inject((Logger log) {
    zone.run(() {
      log('run start');
      runAsync(() {
        log('async');
      });
      log('run end');
    });
    fastForward();

    expect(log.result()).toEqual('run start; run end; async; onTurnDone');
  })));


  it('should work for Future.value as well', async(inject((Logger log) {
    var futureRan = false;
    zone.onTurnDone = () {
      if (!futureRan) {
        new Future.value(null).then((_) { log('onTurn future'); });
        futureRan = true;
      }
      log('onTurnDone');
    };

    zone.run(() {
      log('run start');
      new Future.value(null)
        .then((_) {
          log('future then');
          new Future.value(null)
            .then((_) { log('future ?'); });
          return new Future.value(null);
        })
        .then((_) {
          log('future ?');
        });
      log('run end');
    });
    fastForward();

    expect(log.result()).toEqual('run start; run end; future then; future ?; future ?; onTurnDone; onTurn future; onTurnDone');
  })));


  it('should call onTurnDone after each turn', async(inject((Logger log) {
    Completer a, b;
    zone.run(() {
      a = new Completer();
      b = new Completer();
      a.future.then((_) => log('a then'));
      b.future.then((_) => log('b then'));
      log('run start');
    });
    fastForward();
    zone.run(() {
      a.complete(null);
    });
    fastForward();
    zone.run(() {
      b.complete(null);
    });
    fastForward();

    expect(log.result()).toEqual('run start; onTurnDone; a then; onTurnDone; b then; onTurnDone');
  })));


  it('should call onTurnDone after each turn in a chain', async(inject((Logger log) {
    zone.run(() {
      log('run start');
      runAsync(() {
        log('async1');
        runAsync(() {
          log('async2');
        });
      });
      log('run end');
    });
    fastForward();

    expect(log.result()).toEqual('run start; run end; async1; async2; onTurnDone');
  })));


  it('should call onTurnDone once even if run is called multiple times', async(inject((Logger log) {
    zone.run(() {
      log('runA start');
      runAsync(() {
        log('asyncA');

      });
      log('runA end');
    });
    zone.run(() {
      log('runB start');
      runAsync(() {
        log('asyncB');
      });
      log('runB end');
    });
    fastForward();

    expect(log.result()).toEqual('runA start; runA end; runB start; runB end; asyncA; asyncB; onTurnDone');
  })));


  it('should not call onTurnDone for futures created outside of run body', async(inject((Logger log) {
    // Odd? Yes. Since Future.value resolves immediately, it (and its thens)
    // are already on the runAsync queue when we schedule onTurnDone.
    // Since we want to test explicitly that onTurnDone is not waiting for
    // the future, we use a second Future.value in a then to reschedule
    // the future on the runAsync queue.
    var future = new Future.value(4).then((x) => new Future.value(x));
    zone.run(() {
      future.then((_) => log('future then'));
      log('zone run');
    });
    fastForward();

    expect(log.result()).toEqual('zone run; onTurnDone; future then');
  })));


  it('should call onTurnDone even if there was an exception in body', async(inject((Logger log) {
    zone.onError = (e, s, l) => log('onError');
    expect(() => zone.run(() {
      log('zone run');
      throw 'zoneError';
    })).toThrow('zoneError');
    expect(() => zone.assertInTurn()).toThrow();
    expect(log.result()).toEqual('zone run; onTurnDone; onError');
  })));


  it('should call onTurnDone even if there was an exception in runAsync', async(inject((Logger log) {
    zone.onError = (e, s, l) => log('onError');
    zone.run(() {
      log('zone run');
      runAsync(() {
        log('runAsync');
        throw new Error();
      });
    });

    fastForward();

    expect(() => zone.assertInTurn()).toThrow();
    expect(log.result()).toEqual('zone run; runAsync; onError; onTurnDone');
  })));


  it('should support assertInZone', async(() {
    var calls = '';
    zone.onTurnDone = () {
      zone.assertInZone();
      calls += 'done;';
    };
    zone.run(() {
      zone.assertInZone();
      calls += 'sync;';
      runAsync(() {
        zone.assertInZone();
        calls += 'async;';
      });
    });

    fastForward();
    expect(calls).toEqual('sync;async;done;');
  }));


  it('should assertInZone for chained futures not in zone', () {
    expect(async(() {
      var future = new Future.value(4);
      zone.run(() {
        future = future.then((_) {
          return 5;
        });
      });
      future.then((_) {
        expect(_).toEqual(5);
        zone.assertInZone();
      });
      fastForward();
    })).toThrow('Function must be called in a zone');
  });


  it('should throw outside of the zone', () {
    expect(async(() {
      zone.assertInZone();
      fastForward();
    })).toThrow('Function must be called in a zone');
  });


  it('should support assertInTurn', async(() {
    var calls = '';
    zone.onTurnDone = () {
      calls += 'done;';
      zone.assertInTurn();
    };
    zone.run(() {
      calls += 'sync;';
      zone.assertInTurn();
      runAsync(() {
        calls += 'async;';
        zone.assertInTurn();
      });
    });

    fastForward();
    expect(calls).toEqual('sync;async;done;');
  }));


  it('should assertInTurn outside of the zone', () {
    expect(async(() {
      zone.assertInTurn();
      fastForward();
    })).toThrow('ssertion');  // Support both dart2js and the VM with half a word.
  });
});
