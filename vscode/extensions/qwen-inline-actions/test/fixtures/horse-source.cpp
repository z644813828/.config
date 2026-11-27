#include <iostream>
#include <string>
#include <vector>

// Base class - made truly abstract by making constructor protected and adding
// pure virtual destructor
class Animal {
protected:
  std::string name;
  int age;

public:
  // Constructor
  Animal(const std::string &n, int a) : name(n), age(a) {}

  // Virtual destructor for proper inheritance
  virtual ~Animal() = default;

  // Pure virtual function to make this class abstract
  virtual void makeSound() const = 0;

  // Regular function
  void displayInfo() const {
    std::cout << "Name: " << name << ", Age: " << age << std::endl;
  }

  // Getter methods
  std::string getName() const { return name; }
  int getAge() const { return age; }
};

// Derived class - Dog
class Dog : public Animal {
private:
  std::string breed;

public:
  Dog(const std::string &n, int a, const std::string &b)
      : Animal(n, a), breed(b) {}

  // Override virtual function
  void makeSound() const override {
    std::cout << name << " barks: Woof! Woof!" << std::endl;
  }

  // Additional method specific to Dog
  void fetch() const { std::cout << name << " fetches the ball" << std::endl; }

  void displayInfo() const {
    Animal::displayInfo();
    std::cout << "Breed: " << breed << std::endl;
  }
};

// Derived class - Cat
class Cat : public Animal {
private:
  bool isIndoor;

public:
  Cat(const std::string &n, int a, bool indoor)
      : Animal(n, a), isIndoor(indoor) {}

  // Override virtual function
  void makeSound() const override {
    std::cout << name << " meows: Meow! Meow!" << std::endl;
  }

  // Additional method specific to Cat
  void climb() const { std::cout << name << " climbs the tree" << std::endl; }

  void displayInfo() const {
    Animal::displayInfo();
    std::cout << "Indoor: " << (isIndoor ? "Yes" : "No") << std::endl;
  }
};

class Mouse : public Animal {
private:
  bool isNervous;

public:
  Mouse(const std::string &n, int a, bool nervous)
      : Animal(n, a), isNervous(nervous) {}

  // Override virtual function
  void makeSound() const override {
    std::cout << name << " squeaks: Squeak! Squeak!" << std::endl;
  }

  // Additional method specific to Mouse
  void hide() const {
    std::cout << name << " hides under the couch" << std::endl;
  }

  void displayInfo() const {
    Animal::displayInfo();
    std::cout << "Nervous: " << (isNervous ? "Yes" : "No") << std::endl;
  }
};

// AI: животное лошадь

// Abstract base class
class Shape {
protected:
  std::string color;

public:
  Shape(const std::string &c) : color(c) {}
  virtual ~Shape() = default;

  // Pure virtual function - makes this an abstract class
  virtual double calculateArea() const = 0;

  virtual void displayInfo() const {
    std::cout << "Color: " << color << std::endl;
  }
};

// Derived concrete class
class Rectangle : public Shape {
private:
  double width, height;

public:
  Rectangle(const std::string &c, double w, double h)
      : Shape(c), width(w), height(h) {}

  double calculateArea() const override { return width * height; }

  void displayInfo() const override {
    Shape::displayInfo();
    std::cout << "Rectangle - Width: " << width << ", Height: " << height
              << ", Area: " << calculateArea() << std::endl;
  }
};

// Derived concrete class
class Circle : public Shape {
private:
  double radius;

public:
  Circle(const std::string &c, double r) : Shape(c), radius(r) {}

  double calculateArea() const override { return 3.14159 * radius * radius; }

  void displayInfo() const override {
    Shape::displayInfo();
    std::cout << "Circle - Radius: " << radius << ", Area: " << calculateArea()
              << std::endl;
  }
};

int main() {
  // Create instances of different animals
  Dog dog("Buddy", 3, "Golden Retriever");
  Cat cat("Whiskers", 2, true);

  // Demonstrate polymorphism with pointers to base class
  std::vector<Animal *> animals = {&dog, &cat};

  std::cout << "=== Animal Sounds ===" << std::endl;
  for (const auto &a : animals) {
    a->makeSound();
  }

  std::cout << "\n=== Animal Information ===" << std::endl;
  dog.displayInfo();
  std::cout << std::endl;
  cat.displayInfo();

  // Demonstrate specific methods
  std::cout << "\n=== Specific Methods ===" << std::endl;
  dog.fetch();
  cat.climb();

  // Demonstrate shapes and abstract class
  std::cout << "\n=== Shapes ===" << std::endl;
  Rectangle rect("Red", 5.0, 3.0);
  Circle circle("Blue", 4.0);

  std::vector<Shape *> shapes = {&rect, &circle};

  for (const auto &s : shapes) {
    s->displayInfo();
  }

  return 0;
}
