<%@ page isELIgnored="false"%>
<html>
<body>
	<h2>Please Login</h2>

	<form method="post" action="${flowExecutionUrl}">

		<input type="hidden" name="_eventId" value="performLogin"> 
		<input type="hidden" name="_flowExecutionKey" value="${flowExecutionKey}" />

		Enter Username<input type="text" name="userName" maxlength="40"><br> 
		Enter Password <input type="password" name="password" maxlength="40">
		<input type="submit" value="Login" />

	</form>

</body>
</html>
