drag_handler
============

drag_handler is a dart library to simplify the management of mouse dragging state.
An instance of the DragHandler class maintains a set of DOM elements and monitors them for mouse events.

## Usage ##
To use this library in your code :

* add a dependency in your `pubspec.yaml` :

    ```yaml
dependencies:
  drag_handler: ">=0.1.1 <1.0.0"
```

* add import in your `dart` code :

    ```dart
import 'package:drag_handler/drag_handler.dart';
```

* create a DragHandler

    ```dart
var dh = new DragHandler();
```

* add a target

    ```dart
dh.addTarget(querySelector('#drag-element'));
```

* listen for drag events
  1. Drag start: when the user mouses down on a DOM element added to the DragHandler and begins to move the mouse.

    ```dart
    dh.onDragStart.listen((DragEvent e) => print('Started dragging on element ${e.element}'));
    ```
  2. Drag: each time the user moves the mouse during a drag

    ```dart
    dh.onDrag.listen((DragEvent e) => print('Still dragging ${e.element}'));
    ```
  3. Drag out: when the user moves the mouse out of an element in the DragHandler.

    ```dart
    dh.onDragOut.listen((DragEvent e) => print('Started drag on ${e.element}, dragging out of ${e.other}'));
    ```
  4. Drag over: when the user moves the mouse into an element in the DragHandler

    ```dart
    dh.onDragOver.listen((DragEvent e) => print('Started drag on ${e.element}, dragging over ${e.other}'));
    ```
  5. Drag end: when the user mouses up during a drag

    ```dart
    dh.onDragEnd.listen((DragEvent e) => print('Finished dragging ${e.element}'));
    ```

* selectively add targets

    If you want to know if a drag operation enters or leaves an element,
but you don't want to watch for drags that _start_ on that element, you can specify those events when adding the target:

    ```dart
dh.addTarget(querySelector("#drag-target"), drag: false, over: true, out: true);
```

* temporarily disable a DragHandler

    ```dart
dh.enabled = false;
```
