package com.prajesh.springmvc.webflow.bean;

import java.io.Serializable;

public class LoginBean implements Serializable {
    private static final long serialVersionUID = 1L;

    private String userName;

    public String getUserName() {
	return userName;
    }

    public void setUserName(String userName) {
	this.userName = userName;
    }

    public String getPassword() {
	return password;
    }

    public void setPassword(String password) {
	this.password = password;
    }

    private String password;

}
