package com.java8.hacking.bean;

public class Dog {
    private String name;
    private int age;
    private int weight;

    public Dog(String name, int age, int weight) {
	this.name = name;
	this.age = age;
	this.weight = weight;
    }

    public String getName() {
	return name;
    }

    public int getAge() {
	return age;
    }

    public int getWeight() {
	return weight;
    }

    @Override
    public String toString() {
	return name + " | " + weight + "\n";
    }

}
