package org.prajesh.javabrains.shapes;

import org.prajesh.javabrains.beans.Point;

public class Circle implements IShape {

    Point center;

    public Point getCenter() {
	return center;
    }

    public void setCenter(Point center) {
	this.center = center;
    }

    public void draw() {
	System.out.println("Drawing a circle...");
	System.out.println("Circle point is: " + center.getX() + " + " + center.getY());

    }

}
