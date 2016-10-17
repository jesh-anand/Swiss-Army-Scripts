package com.java8.hacking.stream;

import java.util.stream.Stream;

import com.java8.hacking.bean.Dog;

/**
 * 
 * This class utilizes the Stream API for sorting elements in an Array
 * 
 * -> Refer to ArraySort.java
 * 
 * @author Prajesh Ananthan
 *
 */

public class StreamClass1 {
    public static void main(String[] args) {
	Dog d1 = new Dog("Max", 2, 50);
	Dog d2 = new Dog("Rocky", 1, 30);
	Dog d3 = new Dog("Bear", 3, 40);

	Dog[] dogArray = { d1, d2, d3 };

	Stream<Dog> dogStream = Stream.of(dogArray);
	Stream<Dog> sortedDogStream = dogStream.sorted((Dog m, Dog n) -> Integer.compare(m.getWeight(), n.getWeight()));
	sortedDogStream.forEach(d -> System.out.print(d));
    }

}
