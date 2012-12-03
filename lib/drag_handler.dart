part of Tabasci;

class DragHandler {
  
  // the function to be called on mouse move when dragging
  var _dragCallback;
  
  // the mouse up handler
  var _mouseUp;
  
  // true if we should automatically stop drags on mouse up
  bool _autoStop;
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
    
  DragHandler() {
    autoStop = true;
    _mouseUp = autoStopUpHandler;
  }
  
  void autoStopUpHandler(MouseEvent event) {
    // stop drag
    stopDrag();
  }
  
  void startDrag(callback) {
    // if there is an existing callback, remove it
    stopDrag();
    // store the callback
    _dragCallback = callback;
    // register for the move event
    document.body.on.mouseMove.add(_dragCallback);
  }
  void stopDrag() {
    // remove the callback
    if(_dragCallback != null) {
      document.body.on.mouseMove.remove(_dragCallback);
    }
  }
}
