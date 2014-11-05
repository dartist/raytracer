library raytracer;

import 'dart:math';
import 'dart:typed_data';
import 'dart:async';

import 'package:vector_math/vector_math_64.dart' show Vector3;
export 'package:vector_math/vector_math_64.dart' show Vector3;

class Scene {
  final List<Thing> things;
  final List<Light> lights;
  final Camera camera;

  Scene({this.things, this.lights, this.camera});

  Future<List<int>> render(int width, int height) {
    RayTracer tracer = new RayTracer(this);
    return tracer.render(width, height);
  }
}

class Color {
  final double r, g, b;
  const Color(this.r, this.g, this.b);

  static const WHITE = const Color(1.0, 1.0, 1.0);
  static const GREY = const Color(0.5, 0.5, 0.5);
  static const BLACK = const Color(0.0, 0.0, 0.0);

  static const BACKGROUND = Color.BLACK;
  static const DEFAULT_COLOR = Color.BLACK;

  Color operator +(Color v) => new Color(r + v.r, g + v.g, b + v.b);
  Color operator *(Color v) => new Color(r * v.r, g * v.g, b * v.b);
  Color scale(double k) => new Color(k * r, k * g, k * b);

  int get red => _toInt(this.r);
  int get green => _toInt(this.g);
  int get blue => _toInt(this.b);

  static int _toInt(double d) => ((d > 1 ? 1 : d) * 255).toInt();
}

class Camera {
  final Vector3 pos, forward, right, up;
  Camera._(this.pos, this.forward, this.right, this.up);

  factory Camera(Vector3 pos, Vector3 direction) {
    Vector3 down = new Vector3(0.0, -1.0, 0.0);
    Vector3 forward = (direction - pos).normalize();
    Vector3 right = forward.cross(down).normalize() * 1.5;
    Vector3 up = forward.cross(right).normalize() * 1.5;
    return new Camera._(pos, forward, right, up);
  }
}

class Ray {
  final Vector3 start, dir;
  Ray(this.start, this.dir);
}

class Intersection {
  final Thing thing;
  final Ray ray;
  final double dist;
  Intersection(this.thing, this.ray, this.dist);
}

class Light {
  final Vector3 pos;
  final Color color;
  Light(this.pos, this.color);
}

abstract class Surface {
  int get roughness;
  Color diffuse(Vector3 pos);
  Color specular(Vector3 pos);
  double reflect(Vector3 pos);
}

abstract class Thing {
  Surface get surface;
  Intersection intersect(Ray ray);
  Vector3 normal(Vector3 pos);
}

class Sphere implements Thing {
  final double radius2, radius;
  final Vector3 center;
  final Surface surface;

  Sphere(this.center, double radius, this.surface)
      : this.radius = radius
      , this.radius2 = radius * radius;

  Vector3 normal(Vector3 pos) => (pos - center).normalize();

  Intersection intersect(Ray ray) {
    Vector3 eo = this.center - ray.start;
    double v = eo.dot(ray.dir);
    double dist = 0.0;
    if (v >= 0) {
      double disc = this.radius2 - (eo.dot(eo) - v * v);
      if (disc >= 0) dist = v - sqrt(disc);
    }
    return dist == 0 ? null : new Intersection(this, ray, dist);
  }
}

class Plane implements Thing {
  final Vector3 norm;
  final double offset;
  final Surface surface;
  Plane(this.norm, this.offset, this.surface);

  Vector3 normal(Vector3 pos) => norm;

  Intersection intersect(Ray ray) {
    double denom = norm.dot(ray.dir);
    if (denom > 0) {
      return null;
    } else {
      var dist = (norm.dot(ray.start) + offset) / (-denom);
      return new Intersection(this, ray, dist);
    }
  }
}

class CustomSurface implements Surface {
  final Color diffuseColor, specularColor;
  final int roughness;
  final double reflectPos;
  const CustomSurface(this.diffuseColor, this.specularColor, this.reflectPos,
      this.roughness);

  Color diffuse(Vector3 pos) => diffuseColor;
  Color specular(Vector3 pos) => specularColor;
  double reflect(Vector3 pos) => reflectPos;
}

class CheckerBoardSurface implements Surface {
  final int roughness;
  const CheckerBoardSurface([this.roughness = 150]);

  bool _isWhite(Vector3 pos) =>
      (pos.z.floor() + pos.x.floor()) % 2 != 0;

  Color diffuse(Vector3 pos) => _isWhite(pos) ? Color.WHITE : Color.BLACK;
  Color specular(Vector3 pos) => Color.WHITE;
  double reflect(Vector3 pos) => _isWhite(pos) ? 0.1 : 0.7;
}

class Surfaces {
  static const Surface SHINY =
      const CustomSurface(Color.WHITE, Color.GREY, 0.7, 250);
  static const Surface CHECKERBOARD =
      const CheckerBoardSurface();
}

class RayTracer {
  final Scene scene;
  RayTracer(this.scene);

  static const int MAX_DEPTH = 5;

  Future<List<int>> render(int width, int height) {
    Completer<List<int>> completer = new Completer<List<int>>();
    Uint8ClampedList result = new Uint8ClampedList(width * height * 4);
    int index = 0;

    int y = 0;
    Future<bool> renderNextRow() {
      return new Future<bool>(() {
        for (int x = 0; x < width; x++) {
          Vector3 point = _getPoint(x, y, width, height, scene.camera);
          Color color = _traceRay(new Ray(scene.camera.pos, point), 0);
          result[index++] = color.red;
          result[index++] = color.green;
          result[index++] = color.blue;
          result[index++] = 255;
        }
        return ++y < height;
      });
    }

    Future.doWhile(renderNextRow).then((ignore) => completer.complete(result));
    return completer.future;
  }

  static Vector3 _getPoint(int x, int y, int width, int height, Camera camera) {
    double scaleX = (x - (width / 2.0)) / 2.0 / width;
    double scaleY = -(y - (height / 2.0)) / 2.0 / height;
    Vector3 result = camera.forward
        + camera.right * scaleX
        + camera.up * scaleY;
    return result.normalize();
  }

  Intersection _intersections(Ray ray) {
    double closest = double.INFINITY;
    Intersection closestInter = null;
    for (Thing thing in scene.things) {
      Intersection inter = thing.intersect(ray);
      if (inter != null && inter.dist < closest) {
        closestInter = inter;
        closest = inter.dist;
      }
    }
    return closestInter;
  }

  double _testRay(Ray ray) {
    var isect = _intersections(ray);
    return isect != null ? isect.dist : null;
  }

  Color _traceRay(Ray ray, int depth) {
    Intersection isect = _intersections(ray);
    return (isect == null) ? Color.BACKGROUND : _shade(isect, depth);
  }

  Color _shade(Intersection isect, int depth) {
    Vector3 d = isect.ray.dir;
    Vector3 pos = d * isect.dist + isect.ray.start;
    Vector3 normal = isect.thing.normal(pos);
    Vector3 reflectDir = d - normal * normal.dot(d) * 2.0;
    Color naturalColor =
        Color.BACKGROUND +
        _getNaturalColor(isect.thing, pos, normal, reflectDir);
    Color reflectedColor = (depth >= MAX_DEPTH) ?
        Color.GREY :
        _getReflectionColor(isect.thing, pos, normal, reflectDir, depth);
    return naturalColor + reflectedColor;
  }

  Color _getReflectionColor(Thing thing,
                            Vector3 pos,
                            Vector3 normal,
                            Vector3 rd,
                            int depth) {
    Color color = _traceRay(new Ray(pos, rd), depth + 1);
    double scale = thing.surface.reflect(pos);
    return color.scale(scale);
  }

  Color _getNaturalColor(Thing thing,
                         Vector3 pos,
                         Vector3 norm,
                         Vector3 rd) {
    Color addLight(Color col, Light light) {
      Vector3 ldis = light.pos - pos;
      Vector3 livec = ldis.normalized();
      double neatIsect = _testRay(new Ray(pos, livec));
      bool isInShadow = (neatIsect == null)
          ? false
          : (neatIsect <= ldis.length);
      if (isInShadow) {
        return col;
      } else {
        double illum = livec.dot(norm);
        Color lcolor = (illum > 0) ?
            light.color.scale(illum) :
            Color.DEFAULT_COLOR;
        double specular = livec.dot(rd.normalized());
        Color scolor = (specular > 0) ?
            light.color.scale(pow(specular, thing.surface.roughness)) :
            Color.DEFAULT_COLOR;
        return col +
            (thing.surface.diffuse(pos) * lcolor) +
            (thing.surface.specular(pos) * scolor);
      }
    }
    return scene.lights.fold(Color.DEFAULT_COLOR, addLight);
  }
}
