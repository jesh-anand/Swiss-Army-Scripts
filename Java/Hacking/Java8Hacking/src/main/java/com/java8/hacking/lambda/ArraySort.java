package com.java8.hacking.lambda;

import java.util.Arrays;
import java.util.Comparator;

import com.java8.hacking.bean.Dog;

/**
 * 
 * This class demos how sorting is done with and without Lambda expression
 * 
 * @author Prajesh Ananthan
 *
 */

public class ArraySort {
    public static void main(String[] args) {
	Dog d1 = new Dog("Max", 2, 50);
	Dog d2 = new Dog("Rocky", 1, 30);
	Dog d3 = new Dog("Bear", 3, 40);

	// Sort the dogs by weight
	Dog[] dogArray = { d1, d2, d3 };
	System.out.println("Before sorting..");
	printDogs(dogArray);
	
	System.out.println("After sorting..");
//	Arrays.sort(dogArray, new Comparator<Dog>() {
//	    @Override
//	    public int compare(Dog o1, Dog o2) {
//		return o1.getWeight() - o2.getWeight();
//	    }
//	});
//	printDogs(dogArray);

	// With lambda expression
	Arrays.sort(dogArray, (Dog m, Dog n) -> m.getWeight() - n.getWeight());
	printDogs(dogArray);

    }

    public static void printDogs(Dog[] dogs) {
	System.out.println("--Dog List--");
	for (Dog d : dogs)
	    System.out.print(d);
	System.out.println();
    }

}
