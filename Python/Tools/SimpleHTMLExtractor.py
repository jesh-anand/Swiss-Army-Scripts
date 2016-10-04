from html.parser import HTMLParser

"""SimpleHTMLExtractor.py: A HTML parser that extracts text and outputs to file

"""
__author__ = "Prajesh Ananthan"
__copyright__ = "Copyright 2016, Python"
__license__ = "GPL"


class MyHTMLParser(HTMLParser):
    # def handle_starttag(self, tag, attrs):
    #     print("Encountered a start tag:", tag)

    #
    # def handle_endtag(self, tag):
    #     print("Encountered an end tag :", tag)

    def handle_data(self, data):
        data = str(data)
        if not data.startswith(' '):
            f.write(data + "\n")


################################### Main Function ##############################################
if __name__ == '__main__':
    parser = MyHTMLParser()

    f = open('htmldata.txt', 'a')

    # TODO: Insert a GUI input text box
    # -- Insert HTML element here
    parser.feed(
        '<ul><li><a href="http://www.mkyong.com/spring/spring-bean-reference-example/">Spring bean reference example</a><br> How beans access to each other by specify the bean references in the same or different bean configuration file.</li><li><a href="http://www.mkyong.com/spring/how-to-define-bean-properties-in-spring/">Inject value into bean properties in Spring</a><br> Three ways to inject value into bean properties.</li><li><a href="http://www.mkyong.com/spring/load-multiple-spring-bean-configuration-file/">Load multiple Spring bean configuration file</a><br> Developers always categorize different bean configuration files in different modules folder, here’s a tip to show you how to load multiple Spring bean configuration files.</li><li><a href="http://www.mkyong.com/spring/spring-inner-bean-examples/">Spring inner bean examples</a><br> Whenever a bean is used for one particular property only, it’s always advised to declare it as an inner bean.</li><li><a href="http://www.mkyong.com/spring/spring-bean-scopes-examples/">Spring bean scopes examples</a><br> Bean scope is used to decide which type of bean instance should be return from the Spring container back to the caller.</li><li><a href="http://www.mkyong.com/spring/spring-collections-list-set-map-and-properties-example/">Spring Collections (List, Set, Map, and Properties) example</a><br> Example to inject values into collections type (List, Set, Map, and Properties).</li><li><a href="http://www.mkyong.com/spring/spring-listfactorybean-example/">ListFactoryBean example</a><br> Create a concrete List collection class (ArrayList and LinkedList), and inject it into bean property.</li><li><a href="http://www.mkyong.com/spring/spring-setfactorybean-example/">SetFactoryBean example</a><br> Create a concrete Set collection class (HashSet and TreeSet), and inject it into bean property.</li><li><a href="http://www.mkyong.com/spring/spring-mapfactorybean-example/">MapFactoryBean example</a><br> Create a concrete Map collection class (HashMap and TreeMap), and inject it into bean property.</li><li><a href="http://www.mkyong.com/spring/spring-how-to-pass-a-date-into-bean-property-customdateeditor/">Spring inject Date into bean property – CustomDateEditor</a><br> Normally, Spring is accepting date variable, here’s a tip to use CustomDateEditor to work around it.</li><li><a href="http://www.mkyong.com/spring/spring-propertyplaceholderconfigurer-example/">Spring PropertyPlaceholderConfigurer example</a><br> Externalize the deployment details into a properties file, and access from a bean configuration file via a special format – ${variable}.</li><li><a href=" http://www.mkyong.com/spring/spring-bean-configuration-inheritance/">Spring bean configuration inheritance</a><br> Inheritance is very useful for a bean to share common values, properties or configuration.</li><li><a href="http://www.mkyong.com/spring/spring-properties-dependency-checking/">Spring dependency checking</a><br> Spring comes with 4 dependency checking modes to make sure the required properties have been set in bean.</li><li><a href="http://www.mkyong.com/spring/spring-dependency-checking-with-required-annotation/">Spring dependency checking with @Required Annotation</a><br> Dependency checking in annotation mode.</li><li><a href="http://www.mkyong.com/spring/spring-define-custom-required-style-annotation/">Custom @Required-style annotation</a><br> Create a custom @Required-style annotation ,which is equivalent to @Required annotation.</li><li><a href="http://www.mkyong.com/spring/spring-initializingbean-and-disposablebean-example/">Bean InitializingBean and DisposableBean example</a><br> Perform certain actions upon bean initialization and destruction. (interface)</li><li><a href="http://www.mkyong.com/spring/spring-init-method-and-destroy-method-example/">Bean init-method and destroy-method example</a><br> Perform certain actions upon bean initialization and destruction. (XML)</li><li><a href="http://www.mkyong.com/spring/spring-postconstruct-and-predestroy-example/">Bean @PostConstruct and @PreDestroy example</a><br> Perform certain actions upon bean initialization and destruction. (Annotation)</li></ul>')

    f.close()
################################# End Main Function #############################################
