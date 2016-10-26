package com.java8.hacking.defaultmethod;

/**
 * 
 * Default method implementation:
 * 
 *  The reason
 * =============
 * This capability was added for backward compatibility so that old interfaces
 * could leverage the lambda expression capability of Java 8.
 * 
 * Java 8 introduces default method so that List/Collection interface can have a 
 * default implementation of forEach method, and the class implementing these interfaces 
 * need not implement the same.
 * 
 * 1) Default method
 * 2) Static default method
 * 
 * @author Prajesh Ananthan
 *
 */

public class DefaultMethodTest {
    public static void main(String[] args) {
	Car car = new Car();
	car.print();
    }

}

interface Vehicle {
    default void print() {
	System.out.println("I am a vehicle!");
    }

    static void blowHorn() {
	System.out.println("Horn thrown!");
    }
}

interface FourWheeler {
    default void print() {
	System.out.println("I am a four wheeler!");
    }
}

class Car implements Vehicle, FourWheeler {

    @Override
    public void print() {
	Vehicle.super.print();
	Vehicle.blowHorn();
	FourWheeler.super.print();
	System.out.println("I am a car!");
    }

}
