package org.prajesh.javabrains;

import org.prajesh.javabrains.shapes.IShape;
import org.prajesh.javabrains.shapes.Triangle2;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

public class DrawingAppWithAnnotation {
    public static void main(String[] args) {
        ApplicationContext context = new ClassPathXmlApplicationContext("spring-with-annotation.xml");
        IShape circle = (IShape) context.getBean("circle");
        circle.draw();
    }
}