package com.prajesh.springmvc.webflow.service;

import org.springframework.stereotype.Service;

import com.prajesh.springmvc.webflow.bean.LoginBean;

@Service
public class LoginService {

    public boolean validateUser(LoginBean loginBean) {
	String username = loginBean.getUserName();
	String password = loginBean.getPassword();

	if (username.equals("prajesh") && password.equals("password")) {
	    return true;
	}
	return false;
    }

}
