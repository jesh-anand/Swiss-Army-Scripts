package com.java8.hacking.lambda;

import java.util.Arrays;
import java.util.List;
import java.util.function.Consumer;

/**
 * 
 * This class demos how "i -> System.out.println(i)" is actually implemented at
 * the back with the use of Consumer interface.
 * 
 * @author Prajesh Ananthan
 *
 */

public class ConsumerDemo {

    public static void main(String[] args) {

	List<Integer> values = Arrays.asList(1, 2, 3, 4, 5);
	// values.forEach(i -> System.out.println(i));

	/*
	 * The long way
	 * 
	 */
	Consumer<Integer> c = new Consumer<Integer>() {

	    @Override
	    public void accept(Integer t) {
		System.out.println(t);
	    }

	};
	
	// values.forEach(c);

	/*
	 * Note how the implementation was simplified
	 */
	Consumer<Integer> c2 = t -> System.out.println(t);
//	values.forEach(c2);
	values.forEach(System.out::println);
    }
}
