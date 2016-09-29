package org.prajesh.javabrains;

import org.prajesh.javabrains.shapes.Triangle2;
import org.prajesh.javabrains.shapes.Triangle3;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

public class DrawingApp {
    public static void main(String[] args) {
        ApplicationContext context = new ClassPathXmlApplicationContext("spring.xml");
        Triangle3 triangle3 = (Triangle3) context.getBean("triangle3");
        triangle3.draw();
    }
}