package org.prajesh.javabrains.shapes;

import org.prajesh.javabrains.beans.Point;
import org.springframework.beans.factory.annotation.Autowired;

public class Circle implements IShape {

    private Point center;

    public Point getCenter() {
        return center;
    }

    /**
     * The annotation autowires center instance to center object reference
     * Note the naming must tally across the code in order for the "wiring" to work.
     *
     * @param center
     */
    @Autowired
    public void setCenter(Point center) {
        this.center = center;
    }

    public void draw() {
        System.out.println("Drawing a circle...");
        System.out.println("Circle point is: " + center.getX() + " + " + center.getY());

    }

}
