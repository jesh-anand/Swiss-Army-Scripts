package com.java8.hacking.lambda;

import java.util.HashMap;
import java.util.Map;

/**
 * 
 * This class shows the difference iterating over a map with Java 7 and 8
 * 
 * Source: https://www.mkyong.com/java8/java-8-foreach-examples/
 * 
 * @author Prajesh Ananthan
 *
 */
public class ForEachMap {

    public static void main(String[] args) {

	Map<String, Integer> items = new HashMap<>();
	items.put("A", 10);
	items.put("B", 20);
	items.put("C", 30);
	items.put("D", 40);
	items.put("E", 50);
	items.put("F", 60);

	// loopMapJava7(items);
	 loopMapJava8(items);

    }
    
    private static void loopMapJava7(Map<String, Integer> i) {
	for (Map.Entry<String, Integer> entry : i.entrySet()) {
	    System.out.println("Item: " + entry.getKey() + " | Count: " + entry.getValue());
	}
    }

    private static void loopMapJava8(Map<String, Integer> i) {
	i.forEach((k, v) -> System.out.println("Key: " + k + " Value: " + v));
	
	// Set condition within foreach statement
	i.forEach((k, v) -> {
	    
	    if (k.equals("F")) {
		System.out.println("Item found => " + k);
	    }
	});
    }

}
