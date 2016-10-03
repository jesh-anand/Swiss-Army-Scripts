package org.prajesh.javabrains.aop.service;

import org.prajesh.javabrains.aop.shape.Circle;
import org.prajesh.javabrains.aop.shape.Triangle;

/**
 * 
 * Note: The setter methods are a must in able for Spring to set the instance
 * 
 * @author Prajesh Ananthan
 *
 */
public class ShapeService {

    private Circle circle;
    private Triangle triangle;

    public Triangle getTriangle() {
	return triangle;
    }

    public void setTriangle(Triangle triangle) {
	this.triangle = triangle;
    }

    public Circle getCircle() {
	return circle;
    }

    public void setCircle(Circle circle) {
	this.circle = circle;
    }

}
