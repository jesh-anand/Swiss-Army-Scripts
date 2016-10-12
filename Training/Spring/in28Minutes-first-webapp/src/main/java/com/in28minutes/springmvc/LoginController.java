package com.in28minutes.springmvc;

import org.apache.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.ModelMap;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;

import com.in28minutes.login.IService;

/**
 * This is a controller class. It is done with the @Controller annotation
 * 
 * @author Prajesh Ananthan
 *
 */
@Controller
public class LoginController {

    Logger logger = Logger.getLogger(LoginController.class);
    
    // Spring: Set loginService - AutoWiring
    @Autowired
    IService loginService;

    /**
     * mapping login url to this method
     * 
     * To handle GET request
     * 
     * @return "login"
     */
    @RequestMapping(value = "/login", method = RequestMethod.GET)
    public String showLoginPage() {
	return "login";
    }

    /**
     * The post process after user clicks the submit button
     * 
     * The information received from form are inserted into the model object.
     * 
     * The return name of this method is linked to the jsp page name via
     * todo-servlet.xml (eg. welcome -> welcome.jsp)
     * 
     * NOTE: ModelMap class to pass the user details across to the view (jsp page)
     * 
     * @return "welcome"
     */
    @RequestMapping(value = "/login", method = RequestMethod.POST)
    public String handleLoginRequest(@RequestParam String name, @RequestParam String password, ModelMap model) {
	
	boolean isValidUser = loginService.validateUser(name, password);
	
	if (!isValidUser) {
	    model.put("errorMessage", "Invalid user name and password!");
	    return "login";
	}
	
	model.put("name", name);
	model.put("password", password);
	return "welcome";
    }
}
