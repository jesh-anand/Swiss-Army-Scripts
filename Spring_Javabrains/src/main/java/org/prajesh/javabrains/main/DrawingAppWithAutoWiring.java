package org.prajesh.javabrains.main;

import org.prajesh.javabrains.shapes.IShape;
import org.prajesh.javabrains.shapes.Triangle2;
import org.prajesh.javabrains.shapes.Triangle3;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

public class DrawingAppWithAutoWiring {
    public static void main(String[] args) {
        ApplicationContext context = new ClassPathXmlApplicationContext("spring-interfaces.xml");
        IShape circle = (IShape) context.getBean("circle");
        circle.draw();
    }
}