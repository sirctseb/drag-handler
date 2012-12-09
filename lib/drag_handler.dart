part of Tabasci;

typedef void DragCallback(DragHandler dragHandler, Element element, MouseEvent event);
// type of a function that determines if a drag should be allowed to start
typedef bool AllowDragStart(DragHandler dragHandler, Element element, MouseEvent event);

// TODO this should probably be a singleton. when do you drag more than one thing at a time?
// TODO make universal enable/disable flag
class DragHandler {
  
  /// The function to be called on mouse move when dragging
  DragCallback drag;
  
  /// The function to be called when dragging begins
  DragCallback dragStart;
  
  /// The function to be called when dragging ends
  DragCallback dragEnd;
  
  /// The function to be called when the mouse is dragged out of the original element
  DragCallback dragOut;
  
  /// The function to be called when the mouse is dragged (back) into the original element
  DragCallback dragOver;
  
  /// The function to call to determine if the drag should be allowed to start on mouse down
  AllowDragStart dragConditions;
  
  // references to the local mouse event handlers
  var _mouseDown;
  var _mouseMove;
  var _mouseOver;
  var _mouseOut;
  var _mouseUp;
  
  bool _autoStop;
  /// True if we should automatically stop drags on mouse up
  bool get autoStop => _autoStop;
  set autoStop(bool a) {
    if(_autoStop != a) {
      _autoStop = a;
      if(a) {
        // register up handler
        document.body.on.mouseUp.add(_mouseUp);
      } else {
        // unregister up handler
        document.body.on.mouseUp.remove(_mouseUp);
      }
    }
  }
  
  bool _enabled = true;
  /// True iff the handler is active
  bool get enabled => _enabled;
  bool _delayedDisable = false;
  set enabled(bool e) {
    // if we are currently dragging, delay a disable until it ends
    // TODO yikes, this is kind of scary
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
          t.on.mouseDown.add(_mouseDown);
        }
      } else {
        // remove mouse down handlers from the targets
        for(Element t in _targets) {
          t.on.mouseDown.remove(_mouseDown);
        }
      }
    }
    
    // TODO should we actually remove the up handler?
    // TODO currently we just check for enabled in up handler
  }
  
  // true iff a drag is occurring
  bool _dragging = false;
  
  // true iff we got a mouse down and are waiting for the first move
  // to actually start the drag
  bool _dragStartPending = false;
  // the mouse down event that starts a drag
  MouseEvent _startEvent;

  // The set of elements the handler watches for drags on
  List<Element> _targets = [];
  
  /// Add a target to the set
  void addTarget(Element element) {
    // save size to compare with size after
    int oldSize = _targets.length;
    // add element
    _targets.add(element);
    // if size is bigger, the element is new, so add down handler
    if(_targets.length > oldSize && enabled) {
      element.on.mouseDown.add(_mouseDown);
      // if dragging or pending, add event handlers to the new element
      if(_dragging || _dragStartPending) {
        if(dragOver != null) {
          element.on.mouseOver.add(_mouseOver);
        }
        if(dragOut != null) {
          element.on.mouseOut.add(_mouseOut);
        }
      }
    }
  }
  /// Add targets to the set
  void addTargets(List<Element> elements) {
    for(Element element in elements) {
      addTarget(element);
    }
  }
  /// Remove a target from the set
  void removeTarget(Element element) {
    int index = _targets.indexOf(element);
    if(index != -1) {
      // remove down handler
      _targets[index].on.mouseDown.remove(_mouseDown);
      _targets.removeAt(index);
      if(dragOver != null) {
        element.on.mouseOver.remove(_mouseOver);
      }
      if(dragOut != null) {
        element.on.mouseOut.remove(_mouseOut);
      }
    }
  }
  /// Remove targets from the set
  void removeTargets(List<Element> elements) {
    for(Element element in elements) {
      removeTarget(element);
    }
  }
  
  // The element that the current drag started on
  Element _currentTarget;
  
  /// Construct a handler with an Element or List<Element>
  DragHandler(target) {
    // add initial element(s)
    if(target is Element) _targets.add(target);
    else if(target is List<Element>) _targets.addAll(target);
    
    // store a reference to the autostop up handler so we can add and remove it
    _mouseUp = _autoStopUpHandler;
    _mouseDown = _mouseDownHandler;
    _mouseOver = _mouseOverHandler;
    _mouseOut = _mouseOutHandler;
    _mouseMove = _mouseMoveHandler;
    
    // add mouse down handlers to the targets
    for(Element t in _targets) {
      t.on.mouseDown.add(_mouseDown);
    }
    
    // set autostop on by default
    autoStop = true;
  }
  
  void _mouseDownHandler(MouseEvent event) {
    // if there is a condition callback, call it to see if we should start the drag
    if(dragConditions != null && !dragConditions(this, event.currentTarget, event)) return;
    
    //print("mouse down, enabled: $enabled");
    // TODO if(!_dragging)?
    
    // TODO if we check for non-null handlers here, before we attach them,
    // then they won't be called if they are set during the actual drag
    // unless we explicitly check in a setter
    
    // store the current target
    // TODO should we get the element explicitly from our own list?
    // TODO or is event.currentTarget safely the same?
    _currentTarget = event.currentTarget;
    
    // set dragging flag
    // TODO have an intermediate state where we notice
    // the mouse down and watch for the other events,
    // but we don't set _dragging or do callbacks
    // until we actually get a mouse move
    // TODO we should also save the event object and not send
    // the callback until we get the mouse move?
    _dragStartPending = true;
    _startEvent = event;
    //_dragging = true;
    
    // register for a move event if the callback exists
    if(drag != null) {
      document.on.mouseMove.add(_mouseMove);
    }
    // register for mouse over event on all elements if the callback exists
    if(dragOver != null) {
      for(Element e in _targets) {
        e.on.mouseOver.add(_mouseOver);
      }
    }
    // register for mouse out event on all elements if the callback exists
    if(dragOut != null) {
      for(Element e in _targets) {
        e.on.mouseOut.add(_mouseOut);
      }
    }
  }
  
  void _pendingToDrag() {
    if(_dragStartPending) {
      
      // call start callback if it exists
      if(dragStart != null) {
        dragStart(this, _currentTarget, _startEvent);
      }
      
      // switch from pending to dragging
      _dragStartPending = false;
      _dragging = true;
    }
  }
  
  void _mouseOverHandler(MouseEvent event) {
    // TODO what cases should this occur
    
    // do actual start in case we were pending before
    _pendingToDrag();
    
    // call the drag in callback
    if(dragOver != null) {
      dragOver(this, event.currentTarget, event);
    }
  }
  void _mouseOutHandler(MouseEvent event) {
    // only respond to this event when the element being left is
    // not a child of the element the event was attached to
    if((event.currentTarget as Element).contains(event.toElement)) return;
    
    // do actual start in case we were pending before
    _pendingToDrag();
    
    // call the drag out callback
    if(dragOut != null) {
      dragOut(this, event.currentTarget, event);
    }
  }
  void _mouseMoveHandler(MouseEvent event) {
    // do actual start in case we were pending before
    _pendingToDrag();

    //print("mouse move, enabled: $enabled, dragging: $_dragging");
    // call the drag callback
    // TODO is currentTarget the correct thing?
    // TODO if so, we don't really need to pass it as a para
    // because it's in event
    // TODO now that we store _currentTarget, we should probably use that
    // TODO now that we store _currentTarget, we should definitely use that,
    // TODO because this event was attached to body
    if(drag != null) {
      drag(this, event.currentTarget, event);
    }
  }
  
  // the method that will be called on mouse up events when autostop is on
  void _autoStopUpHandler(MouseEvent event) {
    //print("auto stop handling, enabled: $enabled, dragging: $_dragging");
    // stop the drag
    // only call if we are currently dragging and enabled
    if((_dragStartPending || _dragging) && enabled) {
      stopDrag(event);
    }
  }
  
  /// Manually end the drag
  void stopDrag([MouseEvent event]) {
    
    // signal that we are no longer dragging
    _dragging = false;
    
    // TODO if callbacks are set to null during a drag,
    // they will never be removed. we should define a setter that checks
    
    // TODO if elements are changed during a drag, they won't be removed either
    
    // remove callbacks
    if(drag != null) {
      document.on.mouseMove.remove(_mouseMove);
    }
    if(dragOver != null) {
      for(Element e in _targets) {
        e.on.mouseOver.remove(_mouseOver);
      }
    }
    if(dragOut != null) {
      for(Element e in _targets) {
        e.on.mouseOut.remove(_mouseOut);
      }
    }
    
    // call the end callback
    // only do callback if we weren't just pending
    if(dragEnd != null && !_dragStartPending) {
      dragEnd(this, _currentTarget, event);
    }
    
    // clear current target
    _currentTarget = null;
    
    // if we are on a delayed disable, do the disable
    if(_delayedDisable) {
      _delayedDisable = false;
      enabled = false;
    }
    
    // clear pending flag if it was set
    _dragStartPending = false;
  }
}
