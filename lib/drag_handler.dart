part of Tabasci;

typedef void DragCallback(DragHandler dragHandler, Element element, MouseEvent event);

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
  
  // true iff a drag is occurring
  bool _dragging = false;

  // The set of elements the handler watches for drags on
  List<Element> _targets = [];
  
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
    // TODO if(!_dragging)?
    
    // TODO if we check for non-null handlers here, before we attach them,
    // then they won't be called if they are set during the actual drag
    // unless we explicitly check in a setter
    
    // store the current target
    // TODO should we get the element explicitly from our own list?
    // TODO or is event.currentTarget safely the same?
    _currentTarget = event.currentTarget;
    
    // set dragging flag
    _dragging = true;
    
    // register for a move event if the callback exists
    if(drag != null) {
      document.body.on.mouseMove.add(_mouseMove);
    }
    // register for mouse over event if the callback exists
    if(dragOver != null) {
      _currentTarget.on.mouseOver.add(_mouseOver);
    }
    // register for mouse out event if the callback exists
    if(dragOut != null) {
      _currentTarget.on.mouseOut.add(_mouseOut);
    }
  }
  void _mouseOverHandler(MouseEvent event) {
    // call the drag in callback
    if(dragOver != null) {
      dragOver(this, event.currentTarget, event);
    }
  }
  void _mouseOutHandler(MouseEvent event) {
    // call the drag out callback
    if(dragOut != null) {
      dragOut(this, event.currentTarget, event);
    }
  }
  void _mouseMoveHandler(MouseEvent event) {
    // call the drag callback
    // TODO is currentTarget the correct thing?
    // TODO if so, we don't really need to pass it as a para
    // because it's in event
    // TODO now that we store _currentTarget, we should probably use that
    if(drag != null) {
      drag(this, event.currentTarget, event);
    }
  }
  
  // the method that will be called on mouse up events when autostop is on
  void _autoStopUpHandler(MouseEvent event) {
    // stop the drag
    // only call if we are currently dragging
    if(_dragging) {
      stopDrag();
    }
  }
  
  /// Manually end the drag
  void stopDrag() {
    // signal that we are no longer dragging
    _dragging = false;
    
    // TODO if callbacks are set to null during a drag,
    // they will never be removed. we should define a setter that checks
    
    // remove callbacks
    if(drag != null) {
      document.body.on.mouseMove.remove(_mouseMove);
    }
    if(dragOver != null) {
      _currentTarget.on.mouseOut.remove(_mouseOver);
    }
    if(dragOut != null) {
      _currentTarget.on.mouseOut.remove(_mouseOut);
    }
    
    // call the end callback
    if(dragEnd != null) {
      dragEnd(this, _currentTarget, null);
    }
    
    // clear current target
    _currentTarget = null;
  }
}
