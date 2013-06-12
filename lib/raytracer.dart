import 'dart:html';
import 'dart:math';

//Moved User-configurable Scene to the top
Scene defaultScene() =>
   new Scene(
      things: [new Plane(new Vector(0.0, 1.0, 0.0), 0.0, Surfaces.checkerboard),
               new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, Surfaces.shiny),
               new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, Surfaces.shiny)],
      lights: [new Light(new Vector(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07) ),
               new Light(new Vector(1.5, 2.5, 1.5),  new Color(0.07, 0.07, 0.49) ),
               new Light(new Vector(1.5, 2.5, -1.5), new Color(0.07, 0.49, 0.071) ),
               new Light(new Vector(0.0, 3.5, 0.0),  new Color(0.21, 0.21, 0.35) )],
      camera: new Camera(new Vector(3.0, 2.0, 4.0), new Vector(-1.0, 0.5, 0.0))
   );

//Example Usage
//void main() {
//  var c = new CanvasElement(width:512, height:512);
//  document.body.children.add(c);
//  var rayTracer = new RayTracer();
//  rayTracer.render(defaultScene(), c.context2D, 512, 512);
//}

class Vector {
   num x, y, z;
   Vector(this.x, this.y, this.z);
   
   operator -(Vector v)  => new Vector(x - v.x, y - v.y, z - v.z); 
   operator +(Vector v)  => new Vector(x + v.x, y + v.y, z + v.z);
   static times(num k, Vector v) => new Vector(k * v.x, k * v.y, k * v.z);
   static num dot(Vector v1, Vector v2)  => v1.x * v2.x + v1.y * v2.y + v1.z * v2.z; 
   static num mag(Vector v)  => sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
   static Vector norm(Vector v) {
     var _mag = mag(v);
     var div = _mag == 0 ? double.INFINITY : 1.0 / _mag;
     return times(div, v);
   }
   static Vector cross(Vector v1, Vector v2) {
     return new Vector(v1.y * v2.z - v1.z * v2.y,
         v1.z * v2.x - v1.x * v2.z,
         v1.x * v2.y - v1.y * v2.x);
   }
}

class Color {
   num r, g, b;
   static final white = new Color(1.0, 1.0, 1.0);
   static final grey = new Color(0.5, 0.5, 0.5);
   static final black = new Color(0.0, 0.0, 0.0);
   static final background = Color.black;
   static final defaultColor = Color.black;

   Color(this.r,this.g,this.b);
   static scale(num k, Color v) => new Color(k * v.r, k * v.g, k * v.b); 
   operator +(Color v) => new Color(r + v.r, g + v.g, b + v.b); 
   operator *(Color v) => new Color(r * v.r, g * v.g, b * v.b); 
   static _intColor(num d) => ((d > 1 ? 1 : d) * 255).toInt();
   static String toDrawingRGB(Color c) =>"rgb(${_intColor(c.r)}, ${_intColor(c.g)}, ${_intColor(c.b)})";
}

class Camera {
  Vector pos, forward, right, up;  
  Camera (this.pos, Vector lookAt) {
     var down = new Vector(0.0, -1.0, 0.0);
     forward = Vector.norm(lookAt - pos);
     right = Vector.times(1.5, Vector.norm(Vector.cross(forward, down)));
     up = Vector.times(1.5, Vector.norm(Vector.cross(forward, right)));
  }
}

class Ray {
  Vector start, dir;
  Ray({this.start, this.dir});
}

class Intersection {
  Thing thing;
  Ray ray;
  num dist;
  Intersection(this.thing, this.ray, this.dist);
}

class Light {
  Vector pos;
  Color color;
  Light(this.pos, this.color);
}

abstract class Surface {
  int roughness;
  Color diffuse(Vector pos);
  Color specular(Vector pos);
  num reflect(Vector pos);
}

abstract class Thing {
  Intersection intersect(Ray ray);
  Vector normal(Vector pos);
  Surface surface;
}

class Scene {
  List<Thing> things;
  List<Light> lights;
  Camera camera;
  Scene({this.things,this.lights,this.camera});
}

class Sphere implements Thing {
  num radius2, radius;
  Vector center;
  Surface surface;

  Sphere (this.center, this.radius, this.surface) {
       this.radius2 = radius * radius;
  }  
  normal(Vector pos) => Vector.norm(pos - center);
  intersect(Ray ray) {
       var eo = this.center - ray.start;
       var v = Vector.dot(eo, ray.dir);
       var dist = 0;
       if (v >= 0) {
           var disc = this.radius2 - (Vector.dot(eo, eo) - v * v);
           if (disc >= 0) 
               dist = v - sqrt(disc);           
       }
       return dist == 0 ? null : new Intersection(this, ray, dist); 
   }
}

class Plane implements Thing {
  Vector norm;
  num offset;
  Surface surface;
  Plane(this.norm, this.offset, this.surface);
  Vector normal(Vector pos) => norm;
  Intersection intersect(Ray ray) {
     var denom = Vector.dot(norm, ray.dir);
     if (denom > 0) {
       return null;
     } else {
       var dist = (Vector.dot(norm, ray.start) + offset) / (-denom);
       return new Intersection(this, ray, dist);
     }
  }
}

class CustomSurface implements Surface {
  Color diffuseColor, specularColor;
  int roughness;
  num reflectPos;  
  CustomSurface(this.diffuseColor, this.specularColor, this.reflectPos, this.roughness);  
  diffuse(pos) => diffuseColor;
  specular(pos) => specularColor;
  reflect(pos) => reflectPos;  
}

class CheckerBoardSurface implements Surface {
  int roughness;
  CheckerBoardSurface([this.roughness=150]);  
  diffuse(pos) => (pos.z.floor() + pos.x.floor()) % 2 != 0 
    ? Color.white
    : Color.black;
  specular(pos) => Color.white;
  reflect(pos)  => (pos.z.floor() + pos.x.floor()) % 2 != 0 ? 0.1 : 0.7;
}

class Surfaces {
  static final shiny = new CustomSurface(Color.white, Color.grey, 0.7, 250);
  static final checkerboard = new CheckerBoardSurface();
}

class RayTracer {
   num _maxDepth = 5;

   Intersection _intersections(Ray ray, Scene scene) {
       var closest = double.INFINITY;
       Intersection closestInter = null;
       for (Thing thing in scene.things) {
           var inter = thing.intersect(ray);
           if (inter != null && inter.dist < closest) {
               closestInter = inter;
               closest = inter.dist;
           }
       }
       return closestInter;
   }

   _testRay(Ray ray, Scene scene) {
       var isect = _intersections(ray, scene);
       return isect != null
           ? isect.dist
           : null;
   }

   _traceRay(Ray ray, Scene scene, num depth) {
       var isect = _intersections(ray, scene);
       return isect == null
           ? Color.background
           : _shade(isect, scene, depth);
   }

   _shade(Intersection isect, Scene scene, num depth) {
       var d = isect.ray.dir;
       var pos = Vector.times(isect.dist, d) + isect.ray.start;
       var normal = isect.thing.normal(pos);
       var reflectDir = d - Vector.times(2, Vector.times(Vector.dot(normal, d), normal));
       var naturalColor = Color.background + _getNaturalColor(isect.thing, pos, normal, reflectDir, scene);
       var reflectedColor = (depth >= _maxDepth) ? Color.grey : _getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth);
       return naturalColor + reflectedColor;
   }

   _getReflectionColor(Thing thing, Vector pos, Vector normal, Vector rd, Scene scene, num depth) =>
       Color.scale(thing.surface.reflect(pos), _traceRay(new Ray(start:pos, dir:rd), scene, depth + 1));

   _getNaturalColor(Thing thing, Vector pos, Vector norm, Vector rd, Scene scene) {
       var addLight = (col, light) {
           var ldis = light.pos - pos;
           var livec = Vector.norm(ldis);
           var neatIsect = _testRay(new Ray(start:pos, dir:livec), scene);
           var isInShadow = neatIsect == null ? false : (neatIsect <= Vector.mag(ldis));
           if (isInShadow) {
               return col;
           } else {
               var illum = Vector.dot(livec, norm);
               var lcolor = (illum > 0) ? Color.scale(illum, light.color)
                                         : Color.defaultColor;
               var specular = Vector.dot(livec, Vector.norm(rd));
               var scolor = (specular > 0) ? Color.scale(pow(specular, thing.surface.roughness), light.color)
                                           : Color.defaultColor;
               return col + (thing.surface.diffuse(pos)  * lcolor)
                          + (thing.surface.specular(pos) * scolor);
           }
       };
       return scene.lights.fold(Color.defaultColor, addLight);
   }

   render(Scene scene, CanvasRenderingContext2D ctx, num screenWidth, num screenHeight) {
       var getPoint = (x, y, camera) {
           var recenterX = (x) => (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
           var recenterY = (y) => - (y - (screenHeight / 2.0)) / 2.0 / screenHeight;
           return Vector.norm(camera.forward 
               + Vector.times(recenterX(x), camera.right) 
               + Vector.times(recenterY(y), camera.up));
       };
       for (int y = 0; y < screenHeight; y++) {
           for (int x = 0; x < screenWidth; x++) {
               var color = _traceRay(new Ray(start: scene.camera.pos, dir: getPoint(x, y, scene.camera) ), scene, 0);
               ctx.fillStyle = Color.toDrawingRGB(color);
               ctx.fillRect(x, y, x + 1, y + 1);
           }
       }
   }
}