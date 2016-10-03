package org.prajesh.javabrains.aop.aspect;

import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Before;

/**
 * 
 * This is an aspect class. Put it simply - An intercepter to intercept some method calls.
 * 
 * @author Prajesh Ananthan
 *
 */
@Aspect
public class LoggingAspect {

    /**
     * 
     * getName() method is ran before the execution of loggingAdvise method is
     * executed
     * 
     */
    @Before("execution(public String getName())")
    public void logginAdvise() {
	System.out.println("Advise ran. Get method called.");
    }

}
