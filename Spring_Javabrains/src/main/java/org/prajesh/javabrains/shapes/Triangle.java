package org.prajesh.javabrains.shapes;

public class Triangle {

  private String type;

  private int width;
  private int height;


  public Triangle() {

  }

  public Triangle(String type) {
    this.type = type;
  }

  public Triangle(int height, int width) {
    this.height = height;
    this.width = width;
  }
  
  public void printArea() {
    System.out.println("Value is " + height * width);
  }

  public void draw() {
    System.out.println(getType() + " triangle is drawn!");
  }

  public String getType() {
    return type;
  }

  public void setType(String type) {
    this.type = type;
  }

  public int getWidth() {
    return width;
  }

  public int getHeight() {
    return height;
  }
}
