package com.in28minutes.jee;

import java.io.IOException;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.in28minutes.login.LoginService;

@WebServlet(urlPatterns = "/login.do")
public class LoginServlet extends HttpServlet {

    private LoginService service = new LoginService();

    /**
     * When user goes to link:
     * http://localhost:8080/login.do
     * <p>
     * With '@WebServlet(urlPatterns = "/login.do")' annotation in this class,
     * it is linked to the login.jsp page.
     * 
     * This is normal way a request/respond is handled without Spring MVC into play
     *
     * @param request
     * @param response
     * @throws IOException
     * @throws ServletException
     */
    @Override
    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response) throws IOException, ServletException {
        request.getRequestDispatcher("/WEB-INF/views/login.jsp").forward(
                request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request,
                          HttpServletResponse response) throws IOException, ServletException {
        String name = request.getParameter("name");
        String password = request.getParameter("password");

        boolean isValidUser = service.validateUser(name, password);

        if (isValidUser) {
            request.setAttribute("name", "Prajesh Ananthan");
            request.getRequestDispatcher("/WEB-INF/views/welcome.jsp").forward(
                    request, response);
        } else {
            request.setAttribute("errorMessage", "Invalid Credentials!!");
            request.getRequestDispatcher("/WEB-INF/views/login.jsp").forward(
                    request, response);
        }
    }

}