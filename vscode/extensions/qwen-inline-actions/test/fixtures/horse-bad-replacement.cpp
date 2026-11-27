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