// Copyright (c) 2013, Christopher Best
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library drag_handler;

import "dart:html";
import "dart:async";
import "package:logging/logging.dart";

// TODO long form documentation at top

/// Function that determines if a drag should be allowed to start
typedef bool AllowDragStart(DragHandler dragHandler, Element element, MouseEvent event);

/// The event class that is sent with drag handler stream event updates
class DragEvent {
  /// The [DragHandler] sending the event
  DragHandler dragHandler;
  /// The [Element] being dragged
  Element element;
  /// The [MouseEvent] that instigated the drag handler event
  MouseEvent mouseEvent;
  /// For out events, the [Element] being dragged out of
  /// For over events, the [Element] being dragged over
  Element other;
  DragEvent._(DragHandler this.dragHandler, Element this.element, MouseEvent this.mouseEvent, [Element this.other]);

  /// Whether this event corresponds to the last drag event of
  /// its type (up, down, move, out, over) that was received
  // return true here for up and down and implement in subclasses for others
  bool get lastEvent => true;
}

/// The event class that is sent with drag over stream event updates
class DragOverEvent extends DragEvent {

  /// Whether this event corresponds to the last drag event that was received
  bool get lastEvent => this == _lastOver;

  // create a drag over event
  DragOverEvent._(DragHandler handler, Element element, MouseEvent event, Element over)
      : super._(handler, element, event, over) {
    // TODO this assumes we only create these when real over events are received
    // TODO if one is created for some other reason then _lastOver will not be correct
    _lastOver = this;
  }

  // The last drag over event created
  static DragOverEvent _lastOver;
}

/// The event class that is sent with drag out stream event updates
class DragOutEvent extends DragEvent {

  /// Whether this event corresponds to the last drag out event that was received
  bool get lastEvent => this == _lastOut;

  // create a drag out event
  DragOutEvent._(DragHandler handler, Element element, MouseEvent event, Element over)
      : super._(handler, element, event, over) {
    // TODO this assumes we only create these when real over events are received
    // TODO if one is created for some other reason then _lastOver will not be correct
    _lastOut = this;
  }

  // The last drag out event created
  static DragOutEvent _lastOut;
}

/// The event class that is sent with drag move stream event updates
class DragMoveEvent extends DragEvent {

  /// Whether this event corresponds to the last drag out event that was received
  bool get lastEvent => this == _lastMove;

  // create drag move event
  DragMoveEvent._(DragHandler handler, Element element, MouseEvent event)
      : super._(handler, element, event) {
    _lastMove = this;
  }

  // The last drag move event created
  static DragMoveEvent _lastMove;
}

class DragHandler {
  static final _logger = new Logger("drag-handler");

  // stream controllers
  StreamController<DragEvent> _dragStreamController = new StreamController<DragEvent>();
  StreamController<DragEvent> _dragStartStreamController = new StreamController<DragEvent>();
  StreamController<DragEvent> _dragEndStreamController = new StreamController<DragEvent>();
  StreamController<DragEvent> _dragOutStreamController = new StreamController<DragEvent>();
  StreamController<DragEvent> _dragOverStreamController = new StreamController<DragEvent>();

  /// Exposed drag handler event streams
  Stream<DragEvent> get onDrag => _dragStreamController.stream;
  Stream<DragEvent> get onDragStart => _dragStartStreamController.stream;
  Stream<DragEvent> get onDragEnd => _dragEndStreamController.stream;
  Stream<DragEvent> get onDragOut => _dragOutStreamController.stream;
  Stream<DragEvent> get onDragOver => _dragOverStreamController.stream;

  /// The function to call to determine if the drag should be allowed to start on mouse down
  AllowDragStart dragConditions;

  // methods to subscribe / unsubscribe safely
  void _listen(String event, Node element, [bool useCapture = false]) {
    var subscriptions, handler, provider;
    if(event == "mouseDown") {
      subscriptions = _mouseDownSubscriptions;
      handler = _mouseDown;
      provider = Element.mouseDownEvent;
    } else if(event == "mouseMove") {
      subscriptions = _mouseMoveSubscriptions;
      handler = _mouseMove;
      provider = Element.mouseMoveEvent;
    } else if(event == "mouseOver") {
      subscriptions = _mouseOverSubscriptions;
      handler = _mouseOver;
      provider = Element.mouseOverEvent;
    } else if(event == "mouseOut") {
      subscriptions = _mouseOutSubscriptions;
      handler = _mouseOut;
      provider = Element.mouseOutEvent;
    }
    _logger.fine("listening for $event for element ${element.hashCode}, capture: $useCapture");
    subscriptions[element.hashCode] = provider.forTarget(element, useCapture:useCapture).listen(handler);
  }
  void _cancel(String event, Node element) {
    var subscriptions;
    if(event == "mouseDown") {
      subscriptions = _mouseDownSubscriptions;
    } else if(event == "mouseMove") {
      subscriptions = _mouseMoveSubscriptions;
    } else if(event == "mouseOver") {
      subscriptions = _mouseOverSubscriptions;
    } else if(event == "mouseOut") {
      subscriptions = _mouseOutSubscriptions;
    }
    if(subscriptions.containsKey(element.hashCode)) {
      _logger.fine("cancelling $event for element ${element.hashCode}");
      subscriptions[element.hashCode].cancel();
    }
    subscriptions.remove(element.hashCode);
  }

  // references to the local mouse event handlers
  var _mouseDown;
  Map<int, StreamSubscription> _mouseDownSubscriptions = new Map();
  var _mouseMove;
  Map<int, StreamSubscription> _mouseMoveSubscriptions = new Map();
  var _mouseOver;
  Map<int, StreamSubscription> _mouseOverSubscriptions = new Map();
  var _mouseOut;
  Map<int, StreamSubscription> _mouseOutSubscriptions = new Map();
  var _mouseUp;

  bool _autoStop;
  /// True if we should automatically stop drags on mouse up
  bool get autoStop => _autoStop;
  StreamSubscription _mouseUpSubscription;
  set autoStop(bool a) {
    if(_autoStop != a) {
      _logger.finer("changing autoStop to $a");
      _autoStop = a;
      if(a) {
        // register up handler or resume existing
        if(_mouseUpSubscription == null) {
          _logger.finest("adding mouse up event to document");
          _mouseUpSubscription = document.onMouseUp.listen(_mouseUp);
        } else {
          _logger.finest("resuming mouse up event on document");
          _mouseUpSubscription.resume();
        }
      } else {
        // pause up handler
        _logger.finest("pausing mouse up event on document");
        _mouseUpSubscription.pause();
      }
    }
  }

  bool _enabled = true;
  /// True iff the handler is active
  bool get enabled => _enabled;
  bool _delayedDisable = false;
  set enabled(bool e) {
    _logger.fine("setting enabled to $e");
    // if we are currently dragging, delay a disable until it ends
    if(_dragging && _enabled && !e) {
      _delayedDisable = true;
      return;
    }
    // if we are enabled during a delayed disable, disable the delayed disable
    if(_delayedDisable && e) {
      _delayedDisable = false;
    }

    // if we aren't changing state, don't do anything
    if(_enabled != e) {

      // update flag
      _enabled = e;

      // add or remove handlers
      if(enabled) {
        // add mouse down handlers to the targets
        for(Element t in _targets) {
          _listen("mouseDown", t);
        }
      } else {
        // remove mouse down handlers from the targets
        for(Element t in _targets) {
          _cancel("mouseDown", t);
        }
      }
    }
  }

  /// Prevent default action on mouse down. To prevent draggable parents
  /// from begin dragged and text from being selected
  // TODO there may be a better way to accomplish this
  bool preventDefault = false;

  // true iff a drag is occurring
  bool _dragging = false;

  // true iff we got a mouse down and are waiting for the first move
  // to actually start the drag
  bool _dragStartPending = false;
  // the mouse down event that starts a drag
  MouseEvent _startEvent;

  // The set of elements the handler watches for drags on. These are watched for start, end and move
  Set<Element> _targets = new Set<Element>();
  // The set of elements to watch for over events on
  Set<Element> _overTargets = new Set<Element>();
  // The set of elements to watch for out events on
  Set<Element> _outTargets = new Set<Element>();

  /// Add a target to the set
  void addTarget(Element element, {bool drag: true, bool over: true, bool out: true}) {
    if(drag && !_targets.contains(element)) {
      _targets.add(element);
      if(enabled) {
        _logger.finer("adding mouse down to ${element.hashCode}");
        _listen("mouseDown", element);
      }
    }
    if(over && !_overTargets.contains(element)) {
      _overTargets.add(element);
      if(enabled && (_dragging || _dragStartPending)) {
        _logger.finer("adding mouse over to ${element.hashCode}");
        _listen("mouseOver", element, true);
      }
    }
    if(out && !_outTargets.contains(element)) {
      _outTargets.add(element);
      if(enabled && (_dragging || _dragStartPending)) {
        _logger.finer("adding mouse out to ${element.hashCode}");
        _listen("mouseOut", element, true);
      }
    }
  }
  /// Add targets to the set
  void addTargets(Iterable<Element> elements, {bool drag: true, bool over: true, bool out:true}) {
    _logger.fine("adding ${elements.length} elements, drag: $drag, over: $over, out: $out");
    for(Element element in elements) {
      addTarget(element, drag: drag, over: over, out: out);
    }
  }
  /// Remove a target from the set
  void removeTarget(Element element, {bool drag: true, bool over: true, bool out: true}) {
    if(drag && _targets.contains(element)) {
      // remove down handler
      _cancel("mouseDown", element);
      _targets.remove(element);
      _logger.finer("removing ${element.hashCode} and cancelling mouse down");
    }
    if(over && _overTargets.contains(element)) {
      // TOD if have subscribers?
      _cancel("mouseOver", element);
      _overTargets.remove(element);
      _logger.finer("removing ${element.hashCode} and cancelling mouse over");
    }
    if(out && _outTargets.contains(element)) {
      _cancel("mouseOut", element);
      _outTargets.remove(element);
      _logger.finer("removing ${element.hashCode} and cancelling mouse out");
    }
  }
  /// Remove targets from the set
  void removeTargets(List<Element> elements, {bool drag: true, bool over: true, bool out: true}) {
    _logger.fine("removing ${elements.length} elements");
    for(Element element in elements) {
      removeTarget(element, drag: drag, over: over, out: out);
    }
  }
  /// Remove all targets
  void removeAllTargets({bool drag: true, bool over: true, bool out: true}) {
    _logger.fine("removing all elements");
    if(drag) removeTargets(new List.from(_targets));
    if(out) removeTargets(new List.from(_outTargets));
    if(over) removeTargets(new List.from(_overTargets));
  }

  /// The element that the current drag started on
  Element currentTarget;

  /// Construct a handler with an Element or List<Element>
  DragHandler(target) {

    // store a reference to the autostop up handler so we can add and remove it
    _mouseUp = _autoStopUpHandler;
    _mouseDown = _mouseDownHandler;
    _mouseOver = _mouseOverHandler;
    _mouseOut = _mouseOutHandler;
    _mouseMove = _mouseMoveHandler;

    // add initial element(s)
    // non-null check helps dart2js
    if(target != null) {
      if(target is Element) addTarget(target);
      else if(target is List<Element>) addTargets(target);
    }

    // set autostop on by default
    autoStop = true;
  }

  void _mouseDownHandler(MouseEvent event) {
    // if there is a condition callback, call it to see if we should start the drag
    if(dragConditions != null && !dragConditions(this, event.currentTarget, event)) return;

    _logger.fine("got mouse down event for ${event.currentTarget.hashCode}");

    if(preventDefault) {
      event.preventDefault();
    }

    // store the current target
    // TODO should we get the element explicitly from our own list?
    // TODO or is event.currentTarget safely the same?
    currentTarget = event.currentTarget;

    // set dragging flag
    _dragStartPending = true;
    _startEvent = event;

    // register for a move event if the callback exists
    _listen("mouseMove", document);

    // register for mouse over event on all elements
    for(Element e in _overTargets) {
      _listen("mouseOver", e, true);
    }

    // register for mouse out event on all elements
    for(Element e in _outTargets) {
      _listen("mouseOut", e, true);
    }
  }

  void _pendingToDrag() {
    if(_dragStartPending) {
      _logger.finer("changing states from pending to dragging");

      // send start event
      _dragStartStreamController.add(new DragEvent._(this, currentTarget, _startEvent));

      // switch from pending to dragging
      _dragStartPending = false;
      _dragging = true;
    }
  }

  void _mouseOverHandler(MouseEvent event) {
    // only respond to this event when the element being left is
    // not a child of the element the event was attached to
    if((event.currentTarget as Element).contains(event.relatedTarget)) return;

    _logger.fine("got mouse over event for ${event.currentTarget.hashCode}");

    // do actual start in case we were pending before
    _pendingToDrag();

    // send over event
    _dragOverStreamController.add(new DragOverEvent._(this, currentTarget, event, event.currentTarget));
  }
  void _mouseOutHandler(MouseEvent event) {
    // only respond to this event when the element we're going to is
    // not a child of the element the event was attached to
    if((event.currentTarget as Element).contains(event.relatedTarget)) return;

    _logger.fine("got mouse out event for ${event.currentTarget.hashCode}");

    // do actual start in case we were pending before
    _pendingToDrag();

    // send out event
    _dragOutStreamController.add(new DragOutEvent._(this, currentTarget, event, event.currentTarget));
  }
  void _mouseMoveHandler(MouseEvent event) {
    _logger.finest("got mouse move event");

    // do actual start in case we were pending before
    _pendingToDrag();

    // send drag event
    _dragStreamController.add(new DragMoveEvent._(this, currentTarget, event));
  }

  // the method that will be called on mouse up events when autostop is on
  void _autoStopUpHandler(MouseEvent event) {
    // stop the drag
    // only call if we are currently dragging and enabled
    if((_dragStartPending || _dragging) && enabled) {
      _logger.fine("stopping drag for auto stop");
      stopDrag(event);
    }
  }

  /// Manually end the drag
  void stopDrag([MouseEvent event]) {
    _logger.fine("stopping drag");

    // signal that we are no longer dragging
    _dragging = false;

    // TODO if elements are changed during a drag, they won't be removed either

    // remove callbacks
    // TODO this can just be paused
    _cancel("mouseMove", document);
    for(Element e in _overTargets) {
      _cancel("mouseOver", e);
    }
    for(Element e in _outTargets) {
      _cancel("mouseOut", e);
    }

    // send end event if we weren't just pending
    if(!_dragStartPending) {
      _dragEndStreamController.add(new DragEvent._(this, currentTarget, event));
    }

    // clear current target
    currentTarget = null;

    // if we are on a delayed disable, do the disable
    if(_delayedDisable) {
      _delayedDisable = false;
      enabled = false;
    }

    // clear pending flag if it was set
    _dragStartPending = false;
  }
}
