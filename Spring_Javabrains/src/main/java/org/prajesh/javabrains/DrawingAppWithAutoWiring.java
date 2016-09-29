package org.prajesh.javabrains;

import org.prajesh.javabrains.shapes.IShape;
import org.prajesh.javabrains.shapes.Triangle2;
import org.prajesh.javabrains.shapes.Triangle3;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

public class DrawingAppWithAutoWiring {
    public static void main(String[] args) {
	ApplicationContext context = new ClassPathXmlApplicationContext("spring-autowiring.xml");
	IShape triangle2 = (Triangle2) context.getBean("triangle2");
	triangle2.draw();
    }
}