package com.java8.hacking.lambda;

import java.util.Arrays;
import java.util.List;

public class ForEachStatment {
    public static void main(String[] args) {

	List<String> values = Arrays.asList("ananthan", "ali", "jennifer", "lars", "brandon");

	// Before Java 8
	for (String val : values)
	    System.out.println(val);

	// After Java 8
	values.forEach(i -> System.out.println(i));
    }

}
