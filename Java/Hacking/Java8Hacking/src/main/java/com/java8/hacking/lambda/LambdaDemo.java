package com.java8.hacking.lambda;

/**
 * 
 * '->' is called the lambda expression
 * 
 * Implementation 
 * 
 * @author Prajesh Ananthan
 *
 */
interface A {
    void show(String word);
}

public class LambdaDemo {
    public static void main(String[] args) {

	// Using anonymous class
	A obj = new A() {
	    @Override
	    public void show(String val) {
		System.out.println("Show something!");
	    }
	};

	// This is the same as the block above
	A obj2 = i -> System.out.println("Hello " + i);
	obj2.show("World!");
    }

}
