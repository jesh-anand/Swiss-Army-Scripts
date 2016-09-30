package org.prajesh.javabrains;

import org.prajesh.javabrains.shapes.Circle;
import org.prajesh.javabrains.shapes.IShape;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

public class DrawingApp {
    public static void main(String[] args) {
        ApplicationContext context = new ClassPathXmlApplicationContext("spring-interfaces.xml");
        IShape circle = (IShape) context.getBean("circle");
        circle.draw();

        IShape square = (IShape) context.getBean("square");
        square.draw();
    }
}