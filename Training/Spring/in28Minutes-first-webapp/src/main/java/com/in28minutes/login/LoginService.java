package com.in28minutes.login;

import org.springframework.stereotype.Service;

/**
 * 
 * With @Service annotation, We are telling Spring to set the instance of this
 * bean class
 * 
 * eg. new LoginService()
 * 
 * @author Prajesh Ananthan
 *
 */
@Service
public class LoginService implements IService {
    @Override
    public boolean validateUser(String user, String password) {
	return user.equalsIgnoreCase("prajesh") && password.equals("dummy");
    }

}