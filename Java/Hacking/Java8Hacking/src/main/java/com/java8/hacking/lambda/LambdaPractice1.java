package com.java8.hacking.lambda;

/**
 * 
 * This class displays some of the ways to implement lambda expressions
 * 
 * To put it simply, lambda expression is about implementing an operation on
 * args/params parsed in the method in the functional interface.
 * 
 * @author Prajesh Ananthan
 *
 */

public class LambdaPractice1 {
    public static void main(String[] args) {

	MathOperation substraction = beforeJava8();

	// With type declaration
	MathOperation addition = (int a, int b) -> a + b;

	// Without type declaration
	MathOperation multiply = (a, b) -> a * b;

	new LambdaPractice1().operate(10, 5, multiply);

	GreetingService greeting = message -> System.out.println("Hello " + message);
	greeting.sayMessage("World");

    }

    private void operate(int a, int b, MathOperation mathOperation) {
	System.out.println(mathOperation.operation(a, b));
    }

    private static MathOperation beforeJava8() {

	MathOperation mathOperation = new MathOperation() {

	    @Override
	    public int operation(int a, int b) {
		return a - b;
	    }
	};

	return mathOperation;
    }

}

interface MathOperation {
    int operation(int a, int b);
}

interface GreetingService {
    void sayMessage(String message);
}
