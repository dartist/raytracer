import 'dart:html';
import 'package:raytracer/raytracer.dart';

final Scene scene = new Scene(
   things: [
       new Plane(new Vector3(0.0, 1.0, 0.0), 0.0, Surfaces.CHECKERBOARD),
       new Sphere(new Vector3(0.0, 1.0, -0.25), 1.0, Surfaces.SHINY),
       new Sphere(new Vector3(-1.0, 0.5, 1.5), 0.5, Surfaces.SHINY)],
   lights: [
       new Light(new Vector3(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07)),
       new Light(new Vector3(1.5, 2.5, 1.5), new Color(0.07, 0.07, 0.49)),
       new Light(new Vector3(1.5, 2.5, -1.5), new Color(0.07, 0.49, 0.071)),
       new Light(new Vector3(0.0, 3.5, 0.0), new Color(0.21, 0.21, 0.35))],
   camera:
       new Camera(new Vector3(3.0, 2.0, 4.0), new Vector3(-1.0, 0.5, 0.0)));

void main() {
  int width = 512;
  int height = 512;

  CanvasElement canvas = new CanvasElement(width: width, height: height);
  document.body.children.add(canvas);

  scene.render(width, height).then((List<int> pixels) {
    ImageData image = canvas.context2D.createImageData(width, height);
    image.data.setAll(0, pixels);
    canvas.context2D.putImageData(image, 0, 0);
  });
}
