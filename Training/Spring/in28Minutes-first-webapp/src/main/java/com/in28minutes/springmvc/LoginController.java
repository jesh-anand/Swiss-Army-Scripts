package com.in28minutes.springmvc;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * This is a controller class. It is done with the @Controller annotation
 * 
 * @author Prajesh Ananthan
 *
 */
@Controller
public class LoginController {

    /**
     * mapping login url to this method
     * 
     * @return
     */
    @RequestMapping(value = "/login")
    public String sayHello() {
	return "login";
    }
}
