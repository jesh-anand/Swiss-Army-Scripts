package org.prajesh.javabrains.shapes;

import org.prajesh.javabrains.beans.Point;

public class Square implements IShape {

    Point squarePoints;

    public Point getSquarePoints() {
	return squarePoints;
    }

    public void setSquarePoints(Point squarePoints) {
	this.squarePoints = squarePoints;
    }

    public void draw() {
	System.out.println("Drawing a square...");
	System.out.println("Circle point is: " + squarePoints.getX() + " + " + squarePoints.getY());

    }

}
