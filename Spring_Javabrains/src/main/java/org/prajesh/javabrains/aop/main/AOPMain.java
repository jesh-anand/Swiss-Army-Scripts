package org.prajesh.javabrains.aop.main;

import org.prajesh.javabrains.aop.service.ShapeService;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

/**
 * Main class for AOP implementation
 *
 * @author Prajesh Ananthan
 */
public class AOPMain {
    public static void main(String[] args) {
        ApplicationContext ctx = new ClassPathXmlApplicationContext("spring-aop.xml");
        ShapeService shapeService = ctx.getBean("shapeService", ShapeService.class);
        System.out.println(shapeService.getCircle().getName());
    }
}
