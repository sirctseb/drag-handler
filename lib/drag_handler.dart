part of Tabasci;

typedef void DragCallback(DragHandler dragHandler, Element element, MouseEvent event);

// TODO this should probably be a singleton. when do you drag more than one thing at a time?
class DragHandler {
  
  /// The function to be called on mouse move when dragging
  DragCallback dragCallback;
  
  /// The function to be called when dragging begins
  DragCallback startCallback;
  
  /// The function to be called when dragging ends
  DragCallback endCallback;
  
  /// The function to be called when the mouse is dragged out of the original element
  DragCallback dragOut;
  
  /// The function to be called when the mouse is dragged (back) into the original element
  DragCallback dragIn;
  
  // reference to the local mouse up handler
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
  
  DragHandler() {
    // store a reference to the autostop up handler so we can add and remove it
    _mouseUp = _autoStopUpHandler;
    // set autostop on by default
    autoStop = true;
  }
  
  // the method that will be called on mouse up events when autostop is on
  void _autoStopUpHandler(MouseEvent event) {
    //print("drag handler: got mouse up, stopping drag");
    // stop the drag
    // only call if we are currently dragging
    if(_dragging) {
      stopDrag(event);
    }
  }
  
  /// Begin the drag
  void startDrag() {
    //print("drag handler: registering call back and move event");
    if(!_dragging) {
    
      // register for the move event
      if(dragCallback != null) {
        document.body.on.mouseMove.add(dragCallback);
      }
      // call the start callback
      if(startCallback != null) {
        startCallback();
      }
      // signal that we are dragging
      _dragging = true;
    }
  }
  
  /// Manually end the drag
  void stopDrag([MouseEvent event]) {
    // signal that we are no longer dragging
    _dragging = false;
    
    //print("drag handler: removing callback");
    // remove the callback
    if(dragCallback != null) {
      document.body.on.mouseMove.remove(dragCallback);
    }
    // call the end callback
    if(endCallback != null) {
      endCallback(event);
    }
  }
}
