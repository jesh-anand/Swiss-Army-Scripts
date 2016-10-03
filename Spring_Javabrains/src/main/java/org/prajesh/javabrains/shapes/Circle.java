package org.prajesh.javabrains.shapes;

import org.prajesh.javabrains.beans.Point;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;

@Component
public class Circle implements IShape {

    private Point center;

    public Point getCenter() {
        return center;
    }

    /**
     * The annotation autowires center instance to center object reference
     * Note the naming must tally across the code in order for the "wiring" to work.
     * 
     * @Qualifier wires the instance from config file to this method. Refer to spring-with-annotation.xml
     * 
     * @param center
     */
    @Autowired
    @Qualifier("circleRelated")
    public void setCenter(Point center) {
        this.center = center;
    }

    public void draw() {
        System.out.println("Drawing a circle...");
        System.out.println("Circle point is: " + center.getX() + " + " + center.getY());

    }

}
