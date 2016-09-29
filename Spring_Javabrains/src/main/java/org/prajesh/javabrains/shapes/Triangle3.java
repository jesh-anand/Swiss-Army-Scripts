package org.prajesh.javabrains.shapes;

import org.prajesh.javabrains.beans.Point;

import java.util.List;

public class Triangle3 implements IShape {

    private List<Point> points;

    public List<Point> getPoints() {
	return points;
    }

    public void setPoints(List<Point> points) {
	this.points = points;
    }

    public void draw() {
	for (Point point : points) {
	    System.out.println("Point = (" + point.getX() + "," + point.getY() + ")");
	}
    }
}
