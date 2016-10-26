package com.java8.hacking.lambda;

/**
 * 
 * The use of default implemented methods inside an interface for Java 8
 * 
 * @author Prajesh Ananthan
 *
 */

interface Phone {
    void call();

    // Note the user method definition inside Java 8
    default void message() {
	System.out.println("Texting..");
    }
}

class Pixel implements Phone {

    @Override
    public void call() {
	System.out.println("Calling...");

    }

}

public class DemoInterface {
    public static void main(String[] args) {
	Phone phone = new Pixel();
	phone.call();
	phone.message();
    }
}
