	-> Everything other than primitives (int, long, double) are objects in Java.
	__________________________________________________________________________
	
	Get class name => this.getClass().getSimpleName()
	__________________________________________________________________________
	
	Convert from epoch to Human Readable date
	=====================================	
	String date = new java.text.SimpleDateFormat("MM/dd/yyyy HH:mm:ss").format(new java.util.Date (epoch*1000));
	
	Convert from Human Readable Date to epoch
	=====================================
	long epoch = new java.text.SimpleDateFormat("MM/dd/yyyy HH:mm:ss").parse("01/01/1970 01:00:00").getTime() / 1000;
	
	What is java.util.UUID?
	====================
	- represents an immutable Universally Unique Identifier (UUID)
	- used for for creating random file names, session id in web application, transaction id etc

	mport java.util.UUID;

	public class GenerateUUID {
	  
	  public static final void main(String[] args){
		//generate random UUIDs
		UUID idOne = UUID.randomUUID();
		log("UUID One: " + idOne);
	  }
	  
	  private static void log(Object aObject){
		System.out.println( String.valueOf(aObject) );
	  }
	} 
	__________________________________________________________________________
	
	public String[] split(String regex, int limit)
	
	-> 'limit' denotes the length of split array.
	
	eg. 
	
	String val = "boo:and:foo";	
	String variable = val.split(":", 2)[1]; // and:foo
	String variable = val.split(":", 3)[1]; // and
	
	The array content with the following limit below:
	limit = 2   { "boo", "and:foo" }
	limit = 5	{ "boo", "and", "foo" }
	__________________________________________________________________________
	
	Read a large file
	===============
	
	
	
	Compress file to tar.gz
	=====================
	
	public void compressFile() {
			File outputFile 					= null;
			File inputFile 						= null;
			FileOutputStream fOut 				= null;
			BufferedOutputStream bOut 			= null;
			GzipCompressorOutputStream gzOut 	= null;
			TarArchiveOutputStream tOut 		= null;
			try {
				 outputFile 			= new File(properties.getProperty("ICM_OUTPUT_DIRECTORY") + this.extractFileName +".tar.gz");
				 fOut 					= new FileOutputStream(outputFile);
				 bOut 					= new BufferedOutputStream(fOut);
				 gzOut 					= new GzipCompressorOutputStream(bOut);
				 tOut 					= new TarArchiveOutputStream(gzOut);
				 inputFile 				= new File(properties.getProperty("ICM_OUTPUT_DIRECTORY") + this.fileName);
				 TarArchiveEntry entry 	= new TarArchiveEntry(inputFile, inputFile
				  	      .getParentFile().toURI().relativize(inputFile.toURI())
				  	      .getPath());	   
				 tOut.putArchiveEntry(entry);
				 FileInputStream fi 				= new FileInputStream(inputFile);
				 BufferedInputStream sourceStream	= new BufferedInputStream(fi,2048);
				 int count;
				 byte data[] = new byte[2048];
				 while ((count = sourceStream.read(data, 0, 2048)) != -1) {
				  	     tOut.write(data, 0, count);
				 }
				 sourceStream.close();
				 tOut.closeArchiveEntry();
				 tOut.close();
			}catch(Exception e){
				logger.error("IOException occurred ",e);
			} finally{
				File f = new File(properties.getProperty("ICM_OUTPUT_DIRECTORY") + this.fileName);
				f.delete();
			}
		}
	
	__________________________________________________________________________
	
	
	To calculate the number of spaces in a file
	======================================
	
	 String space = "there are spaces in the string";
	 int numOfspaces = 0;

	 for (int i = 0; i < space.length(); i++) {
		if (space.charAt(i) != ' ')
			continue;
		++numOfspaces;
	 }
	__________________________________________________________________________
	
	Load Property file
	================
	
	Properties prop = new Properties();
	InputStream in = getClass().getResourceAsStream("foo.properties");
	prop.load(in);
	in.close();
	__________________________________________________________________________

	Create with timestamp at the end:
	=============================
	// Format the timestamp
	File file = new File("File name" + InterfaceValidatorConstants.UNDERSCORE + System.currentTimeMillis()+".csv");
	__________________________________________________________________________

	File.separator 		= '/'
	File.pathSeparator	= ';'


	Condition pattern:
	if (subElemList != null && subElemList.size() > 0)  {
	}

	Returns the current working directory of the file instance:
	====================================================
	-> file.getParent();
	__________________________________________________________________________


	To check parse String is a double or not:
	====================================
		boolean isDouble(String str) {
			try {
				Double.parseDouble(str);
				return true;
			} catch (NumberFormatException e) {
				return false;
			}
		}
	__________________________________________________________________________



	To differentiate between 12 a.m. and 12 p.m. data
	============================================
	Notice Use hh instead of HH. The former does this:
	hh - 12 hour format
	-----------------
	Hour in am/pm (1-12)

	HH - 24 hour format
	-----------------
	Hour in day (0-23)


	From runCompleteFeed.sh (line. 50)
	==============================
	java -Dmodel="parameter subsitution"

	Note: '-D' sets a system property for the running java app
	....................................................

		if (System.getProperty("model", null) != null) {
			logger.info("ELEMENT MODEL==>" + System.getProperty("model"));
			completeFeedController.setModel(
					System.getProperty("model").replace("^", " "));
		}

		(System.getProperty("model", null)
		-> the string value of the system property, or the default value if there is no property with that key.
		
		System.getProperty("model")
		-> get the parameter value from the bash scritp with 'java -Dmodel=""'
	__________________________________________________________________________



	Get the file for the current directory where the jar was executed:
	===========================================================
	InputStreamReader inputStreamReader = new InputStreamReader(
													ReportWriterUtil.class.getClassLoader().getResourceAsStream("template.html")
												);
	__________________________________________________________________________

	To check if the timestamp parsed is later than a day from the currenttimestamp:
	======================================================================

	private boolean isLateFeed(long currentTimestamp, String date) {
			boolean flag			= false;
			SimpleDateFormat sdf	= new SimpleDateFormat("ddMMyyyy");
			Date d1 				= null;
			Date d2 				= null;
			
			try {
				d1				= new Date(currentTimestamp);
				d2				= sdf.parse(date);
				
				long diff		= d1.getTime() - d2.getTime();
				long diffDays	= diff / (24 * 60 * 60 * 1000);
				
				if (diffDays > 1) {
					flag = true;
				}
				
			} catch (ParseException e) {
				logger.error(CLASSNAME + ".isLateFeed()" + NPMCapabilityConstants.LOG_SEP 
						   + "Fail to parse the date for : " + date
						   + NPMCapabilityConstants.LOG_SEP + "ErrorMessage: " + e.getMessage(), e);
			}
			return flag;
		}
		
	Note from above:
	-----------------------------------------------------------------------
	Converts a parsed date to milliseconds:-
	===================================
	String date					= "01012016";
	// Date format should tally with parsed date
	SimpleDateFormat sdf		= new SimpleDateFormat("ddMMyyyy");
	Date d1						= sdf.parse(date);
	d1.getTime();
	-----------------------------------------------------------------------

	To convert epoch time to date:
	===========================
		public static String getDatefromMillis(long epochTime) {
			Date d = new Date(epochTime);
			String dateString = d.toString().split(" ")[3];
			return dateString;
		}


	To list out files recursively:
	=============================

	private void walkLrOutputDirectory(File dir) {
			File root 			= new File(dir.getAbsolutePath());
			File[] list 		= root.listFiles();
			
			for ( File f : list ) {
				if (  f.isDirectory() ) 
					walkLrOutputDirectory( f );
				else
					OrbitFinalFileHelper.setLrOutputFiles(f);
			}
		}
		
		

	To check if the file is empty and header string is not empty, Then write to file:
	=======================================================================
	header 			= buildHeader(runNumber, feedDate);

	if( finalFeedFile.length() == 0 && !StringUtils.isEmpty( header ) ) {
		logger.info(CLASSNAME + ".mergeFiles()" + NPMCapabilityConstants.LOG_SEP + "Writing header.");
		out.write(header);
		out.newLine();
	}
	
	Read from file
	=============	
	http://www.mkyong.com/java/how-to-read-file-from-java-bufferedreader-example/
	
	Write to file
	============
	http://www.mkyong.com/java/how-to-write-to-file-in-java-bufferedwriter-example/

	About StringTokenizer
	=====================

	Note:	1) It is a legacy class.
			2) Retained for compatibility reasons 

	String str = "This is String , split by StringTokenizer, created by prajeshananthan"
	StringTokenizer st = new StringTokenizer(str);
	// Splits by space
	 while (st.hasMoreElements()) {
				System.out.println(st.nextElement());
	}


	Loop through an enum:
	===================
		enum Day {
		  SUNDAY, MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY 
		}

		for (Day d: Day.values()) {
		  System.out.println(d.toString());
		}



	List Files in a directory:
	=======================
	File folder = new File("your/path");
	File[] listOfFiles = folder.listFiles();


	Loading property file with exception handling:
	==========================================

	public void loadProperties (File propFile) {
		try {
			prop.load(new FileInputStream(propFile));
		} catch (FileNotFoundException e) {
			logger.error("FeedCompareConfig properties file not found.", e);
		} catch (IOException e) {
			logger.error(e.getMessage(), e);
		}
	}

		
	Example writting an Exception
	===========================

	try {
				
		fstream = new FileReader(finalFeedFile);
		in = new BufferedReader(fstream);

		while ((thisLine = in.readLine()) != null) {
			last = thisLine;
		}

		if(last != null)
			linesCount = Integer.valueOf(last.split(",")[1]) - 2;

		logger.debug(linesCount);
	} catch (FileNotFoundException e) {
		logger.error( CLASSNAME + ".getLineCountFrmFile()" 
				+ NPMCapabilityConstants.LOG_SEP 
				+ "File not found : " + finalFeedFile.getAbsolutePath() 
				+ NPMCapabilityConstants.LOG_SEP + "ErrorMessage: " + e.getMessage(), e);
	} catch (IOException e) {
		logger.error( CLASSNAME + ".getLineCountFrmFile()" 
				+ NPMCapabilityConstants.LOG_SEP 
				+ "Exception found while getting line count from : " + finalFeedFile.getAbsolutePath() 
				+ NPMCapabilityConstants.LOG_SEP + "ErrorMessage: " + e.getMessage(), e);
	} finally {
		if( in != null ) {
			try {
				in.close();
			} catch ( Exception e ) {
				logger.warn( CLASSNAME + ".getLineCountFrmFile()" 
								+ NPMCapabilityConstants.LOG_SEP 
								+ "Fail to close feed input stream: " + finalFeedFile.getAbsolutePath()
								+ NPMCapabilityConstants.LOG_SEP + "ErrorMessage: " + e.getMessage());
			}
		}
	}
		
		
	Singleton
	=========
	
	// Why Lazy Initialization?
	// Because the singleton instance will not be created until the getCaptain() method is called
	public static MakeACaptain getCaptain() {
        if (_captain == null) {
            _captain = new MakeACaptain();
        }
        return _captain;
    }
	
	

	Using Singleton in Java
	=====================
		
		private static FeedCompareConfig feedCompareConfig = null;
		
		private FeedCompareConfig(){};
		
			public static FeedCompareConfig getInstance() {
				
				if (feedCompareConfig == null)
					feedCompareConfig = new FeedCompareConfig();
				
				return feedCompareConfig;			
			}
			
	Alternative way:
	==============
	private static final DeviceHandler instance 	= new DeviceHandler();

		public static DeviceHandler getInstance()
		{
			return instance;
		}

	Using Singleton with Emum:
	=======================
	
	public enum OrbitHelperEnum {
		INSTANCE;
		
		public void doStuff() {
			System.out.println("Hello World!");
		}
		
		public static void main (String args[]) {
			OrbitHelperEnum.INSTANCE.doStuff();
		}
	--------------------------------------------------------------------------------------
		

	Note if the file is not found, Throw an exception instead of using if else statement
	===========================================================================
	if (args.length == 1) {
		try {
			enprProperties.load(new FileReader(args[0]));
		} catch (FileNotFoundException e1) {
			e1.printStackTrace();
		} catch (IOException e1) {
			e1.printStackTrace();
	}


	Inserting data into HashMap
	=========================
	Foo value = map.get(key);
	if (value != null) {
		...
	} else {
		// Key might be present...
		if (map.containsKey(key)) {
		   // Okay, there's a key but the value is null
		} else {
		   // Definitely no such key
		}
	}

	if (!map.containsKey(key)) {
		map.put(key, value);
	} 

	For Map <String, List <String> mapList
	==================================
	if (!map.containsKey(key)) {
		List <String> list = new ArrayList <String>();
		list.add(value);
		map.put(key, list);
	} else {
		map.get(key).add(value);
	}



	List files recursively
	=====================

	public void walk( String path ) {

			File root = new File( path );
			File[] list = root.listFiles();

			if (list == null) return;

			for ( File f : list ) {
				if ( f.isDirectory() ) {
					walk( f.getAbsolutePath() );
					System.out.println( "Dir:" + f.getAbsoluteFile() );
				}
				else {
					System.out.println( "File:" + f.getAbsoluteFile() );
				}
			}
		}
		
	Clear the content of the file
	==========================
	PrintWriter pw = new PrintWriter("filepath.txt");
	pw.close();


	Using normal Singleton
	=======================

	public class Singleton{
		//initailzed during class loading
		private static final Singleton INSTANCE = new Singleton();
	  
		//to prevent creating another instance of Singleton
		private Singleton(){}

		public static Singleton getSingleton(){
			return INSTANCE;
		}
	}

	Read more: http://javarevisited.blogspot.com/2012/07/why-enum-singleton-are-better-in-java.html#ixzz3tXoQrf3r

	
	For passing comment from property file
	==================================
	if ( line.startsWith("#") )
		continue;
	
	
	Using Singleton with Enum
	=======================

	public enum OrbitHelperEnum {
		INSTANCE;
		
		public void doStuff() {
			System.out.println("Hello World!");
		}
		
		public static void main (String args[]) {
			OrbitHelperEnum.INSTANCE.doStuff();
		}


		
	Read file
	=========
	// File finalFeedFile = new File('insert directory');
	// BufferedReader in = new BufferedReader(new FileReader(finalFeedFile));
	
	public void updateTrailer(File file, int count) throws Exception {
			
			BufferedReader reader	= null;
			
			try {
				String currentLine;
				reader = new BufferedReader(new FileReader(file));
				
				while ((currentLine = reader.readLine()) != null) {
					if (currentLine.startsWith("999")) {
						
						// Insert business logic here
					}
				}
				
			} catch (IOException e) {
				throw e;
			} finally {
				if (reader != null) {
					reader.close();
				}
			}
		}
		
		// Note reader object is outside the try statement
		BufferedReader in 				= null;
		try {
			in 			= new BufferedReader(new InputStreamReader(new FileInputStream(sourceFile), encoding));
		}
		
		
	Write File
	=========
	
	public void writeToFile() {
		
		try {

			String content = "This is the content to write into file";

			File file = new File("/users/mkyong/filename.txt");

			// if file doesnt exists, then create it
			if (!file.exists()) {
				file.createNewFile();
			}

			FileWriter fw = new FileWriter(file.getAbsoluteFile());
			
			// Append lines to a written file
			FileWriter fw = new FileWriter(file.getAbsoluteFile(), true);
			
			BufferedWriter bw = new BufferedWriter(fw);
			bw.write(content);
			bw.close();

			System.out.println("Done");

		} catch (IOException e) {
			e.printStackTrace();
		} finally {
			if (bw != null) {
				bw.close();
			}
		}
		
	}
	
	Insert element at specified position in list
	=======================================
	list.add(0,headerLine);
	
	
	To capture the column index based on the column name:
	==============================================
	
	if (line.startsWith("02")) {
				String[] temp = line.split(_DELIMITER, -1);
				
				for (int i=0; i<temp.length; i++) {
					
					if (temp[i].equals(BT_NE_ID)) {
						elementIndex = i;
						break;
					}
				}
			}
	
	
	Returning a list of roles
	======================
	
	String[] cadNames = { "NM_R_ADM", "NM_R_ADV", "NM_R_CEO", "NM_R_MGR", "NM_R_NOR", "NM_R_RO", "NM_R_CADM",
                "NM_R_CAU", "NM_R_COR", "NM_R_CORA", "NM_R_NETD", "NM_R_RUSR", "NM_R_RADM", "NM_R_IADM" };
    String[] nmdbRoles = { "NMSL_ADMIN", "NMSL_ADV", "NMSL_CEO", "NMSL_MGR", "NMSL_NORMAL", "NMSL_RO",
                "CAPRI_ADMIN", "CAPRI_USER", "CORCI", "CORCI_ADMIN", "NETWORK_DIAGRAMMER", "RASP", "RASP_ADMIN", "NMSL_ISLAND_ADMIN" };
				
		// Get the tallied size of both arrays
		int size = cadNames.length;
        if (size > nmdbRoles.length) {
            size = nmdbRoles.length;
        }
	
	
	if (map == null) {
            map = new HashMap<String, String>();
        }

	
	for (int i = 0; i < size; i++) {
		map.put(cadNames[i], nmdbRoles[i]);
	}
	
	 public List<String> getCorrespondingRoles(List<String> names) {
        if (names != null && !names.isEmpty()) {
            List<String> roles = new ArrayList<String>();
            for (String name : names) {
                String role = getCorrespondingRole(name);
                if (role != null) {
                    roles.add(role);
                }
            }
            return roles;
        }
        return null;
    }
	
	
	
	
	
	
		
	To keep track of the line count in the code
	========================================
	private Map <String, Integer> linecountMap				= new HashMap <String, Integer>();

	// TODO: Update line count directly to file, Prevent storing value.
				if (!linecountMap.containsKey(currentTimestamp)) {
					linecountMap.put(currentTimestamp, lineCount);
				} else {
					Integer value			= linecountMap.get(currentTimestamp);
					if (value == null)
						value = 0;
					
					int currentCount		= value + lineCount;
					linecountMap.put(currentTimestamp, currentCount);
				}
				

		public void insertTrailer() throws Exception {
			
			for (String timestamp : fileMap.keySet()) {
				if (linecountMap.containsKey(timestamp)) {
					int linecount = linecountMap.get(timestamp);
					writeStringToFile(fileMap.get(timestamp), buildTrailer(linecount));
				}
			}
		}
		
	File.separator = '/'
	File.pathSeparator = ';'


	Condition pattern:
	if (subElemList != null && subElemList.size() > 0)  {
	}

	Returns the current working directory of the file instance:
	====================================================
	-> file.getParent();


	To check parse String is a double or not:
	====================================
		boolean isDouble(String str) {
			try {
				Double.parseDouble(str);
				return true;
			} catch (NumberFormatException e) {
				return false;
			}
		}



	To differentiate between 12 a.m. and 12 p.m. data
	============================================
	Notice Use hh instead of HH. The former does this:
	hh - 12 hour format
	-----------------
	Hour in am/pm (1-12)

	HH - 24 hour format
	-----------------
	Hour in day (0-23)


	From runCompleteFeed.sh (line. 50)
	==============================
	java -Dmodel="parameter subsitution"

	Note: '-D' sets a system property for the running java app
	....................................................

		if (System.getProperty("model", null) != null) {
			logger.info("ELEMENT MODEL==>" + System.getProperty("model"));
			completeFeedController.setModel(
					System.getProperty("model").replace("^", " "));
		}

		(System.getProperty("model", null)
		-> the string value of the system property, or the default value if there is no property with that key.
		
		System.getProperty("model")
		-> get the parameter value from the bash scritp with 'java -Dmodel=""'



	Get the file for the current directory where the jar wsa executed:
	===========================================================
	InputStreamReader inputStreamReader = new InputStreamReader(ReportWriterUtil.class.getClassLoader().getResourceAsStream("template.html"));


	To check if the timestamp parsed is later than a day from the currenttimestamp:
	======================================================================

	private boolean isLateFeed(long currentTimestamp, String date) {
			boolean flag			= false;
			SimpleDateFormat sdf	= new SimpleDateFormat("ddMMyyyy");
			Date d1 				= null;
			Date d2 				= null;
			
			try {
				d1				= new Date(currentTimestamp);
				d2				= sdf.parse(date);
				
				long diff		= d1.getTime() - d2.getTime();
				long diffDays	= diff / (24 * 60 * 60 * 1000);
				
				if (diffDays > 1) {
					flag = true;
				}
				
			} catch (ParseException e) {
				logger.error(CLASSNAME + ".isLateFeed()" + NPMCapabilityConstants.LOG_SEP 
						   + "Fail to parse the date for : " + date
						   + NPMCapabilityConstants.LOG_SEP + "ErrorMessage: " + e.getMessage(), e);
			}
			return flag;
		}
		
	Note from above:
	-----------------------------------------------------------------------
	Converts a parsed date to milliseconds:-
	===================================
	String date					= "01012016";
	// Date format should tally with parsed date
	SimpleDateFormat sdf		= new SimpleDateFormat("ddMMyyyy");
	Date d1						= sdf.parse(date);
	d1.getTime();
	-----------------------------------------------------------------------

	To convert epoch time to date:
	===========================
		public static String getDatefromMillis(long epochTime) {
			Date d = new Date(epochTime);
			String dateString = d.toString().split(" ")[3];
			return dateString;
		}





	To list out files recursively:
	==========================

	private void walkLrOutputDirectory(File dir) {
			File root 			= new File(dir.getAbsolutePath());
			File[] list 		= root.listFiles();
			
			for ( File f : list ) {
				if (  f.isDirectory() ) 
					walkLrOutputDirectory( f );
				else
					OrbitFinalFileHelper.setLrOutputFiles(f);
			}
		}
		
		

	To check if the file is empty and header string is not empty, Then write to file:
	=======================================================================
	header 			= buildHeader(runNumber, feedDate);

	if( finalFeedFile.length() == 0 && !StringUtils.isEmpty( header ) ) {
		logger.info(CLASSNAME + ".mergeFiles()" + NPMCapabilityConstants.LOG_SEP + "Writing header.");
		out.write(header);
		out.newLine();
	}


	About StringTokenizer
	===================

	Note:	1) It is a legacy class.
			2) Retained for compatibility reasons 

	String str = "This is String , split by StringTokenizer, created by prajeshananthan"
	StringTokenizer st = new StringTokenizer(str);
	// Splits by space
	 while (st.hasMoreElements()) {
				System.out.println(st.nextElement());
	}


	Loop through an enum:
	===================
		enum Day {
		  SUNDAY, MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY 
		}

		for (Day d: Day.values()) {
		  System.out.println(d.toString());
		}



	List Files in a directory:
	=======================
	File folder = new File("your/path");
	File[] listOfFiles = folder.listFiles();


	Loading property file with exception handling:
	==========================================

		public void loadProperties (File propFile) {
			try {
				prop.load(new FileInputStream(propFile));
			} catch (FileNotFoundException e) {
				logger.error("FeedCompareConfig properties file not found.", e);
			} catch (IOException e) {
				logger.error(e.getMessage(), e);
			}
		}

		
	Example writting an Exception
	===========================

	try {
				
		fstream = new FileReader(finalFeedFile);
		in = new BufferedReader(fstream);

		while ((thisLine = in.readLine()) != null) {
			last = thisLine;
		}

		if(last != null)
			linesCount = Integer.valueOf(last.split(",")[1]) - 2;

		logger.debug(linesCount);
	} catch (FileNotFoundException e) {
		logger.error( CLASSNAME + ".getLineCountFrmFile()" 
				+ NPMCapabilityConstants.LOG_SEP 
				+ "File not found : " + finalFeedFile.getAbsolutePath() 
				+ NPMCapabilityConstants.LOG_SEP + "ErrorMessage: " + e.getMessage(), e);
	} catch (IOException e) {
		logger.error( CLASSNAME + ".getLineCountFrmFile()" 
				+ NPMCapabilityConstants.LOG_SEP 
				+ "Exception found while getting line count from : " + finalFeedFile.getAbsolutePath() 
				+ NPMCapabilityConstants.LOG_SEP + "ErrorMessage: " + e.getMessage(), e);
	} finally {
		if( in != null ) {
			try {
				in.close();
			} catch ( Exception e ) {
				logger.warn( CLASSNAME + ".getLineCountFrmFile()" 
								+ NPMCapabilityConstants.LOG_SEP 
								+ "Fail to close feed input stream: " + finalFeedFile.getAbsolutePath()
								+ NPMCapabilityConstants.LOG_SEP + "ErrorMessage: " + e.getMessage());
			}
		}
	}
		

	Using Singleton in Java
	=====================
		
		private static FeedCompareConfig feedCompareConfig = null;
		
		private FeedCompareConfig(){};
		
			public static FeedCompareConfig getInstance() {
				
				if (feedCompareConfig == null)
					feedCompareConfig = new FeedCompareConfig();
				
				return feedCompareConfig;			
			}
			
	Alternative way:
	==============
	private static final DeviceHandler instance 	= new DeviceHandler();

		public static DeviceHandler getInstance()
		{
			return instance;
		}

	--------------------------------------------------------------------------------------
		

	Note if the file is not found, Throw an exception instead of using if else statement
	===========================================================================
	if (args.length == 1) {
		try {
			enprProperties.load(new FileReader(args[0]));
		} catch (FileNotFoundException e1) {
			e1.printStackTrace();
		} catch (IOException e1) {
			e1.printStackTrace();
	}


	Inserting data into HashMap
	=========================
	Foo value = map.get(key);
	if (value != null) {
		...
	} else {
		// Key might be present...
		if (map.containsKey(key)) {
		   // Okay, there's a key but the value is null
		} else {
		   // Definitely no such key
		}
	}

	if (!map.containsKey(key)) {
		map.put(key, value);
	} 

	For Map <String, List <String> mapList
	==================================
	if (!map.containsKey(key)) {
		List <String> list = new ArrayList <String>();
		list.add(value);
		map.put(key, list);
	} else {
		map.get(key).add(value);
	}



	List files recursively
	=====================

	public void walk( String path ) {

			File root = new File( path );
			File[] list = root.listFiles();

			if (list == null) return;

			for ( File f : list ) {
				if ( f.isDirectory() ) {
					walk( f.getAbsolutePath() );
					System.out.println( "Dir:" + f.getAbsoluteFile() );
				}
				else {
					System.out.println( "File:" + f.getAbsoluteFile() );
				}
			}
		}
		
	Clear the content of the file
	==========================
	PrintWriter pw = new PrintWriter("filepath.txt");
	pw.close();


	Using normal Singleton
	=======================

	public class Singleton{
		//initailzed during class loading
		private static final Singleton INSTANCE = new Singleton();
	  
		//to prevent creating another instance of Singleton
		private Singleton(){}

		public static Singleton getSingleton(){
			return INSTANCE;
		}
	}

	Read more: http://javarevisited.blogspot.com/2012/07/why-enum-singleton-are-better-in-java.html#ixzz3tXoQrf3r


	Using Singleton with Enum
	=======================

	public enum OrbitHelperEnum {
		INSTANCE;
		
		public void doStuff() {
			System.out.println("Hello World!");
		}
		
		public static void main (String args[]) {
			OrbitHelperEnum.INSTANCE.doStuff();
		}


		
	Read and Write to File
	====================
	public void updateTrailer(File file, int count) throws Exception {
			
			BufferedReader reader	= null;
			BufferedWriter writer	= null;
			
			try {
				String currentLine;
				reader = new BufferedReader(new FileReader(file));
				writer = new BufferedWriter(new FileWriter(file, true));
				
				while ((currentLine = reader.readLine()) != null) {
					if (currentLine.startsWith("999")) {
					}
					
				}
				
			} catch (IOException e) {
				throw e;
			} finally {
				if (writer != null) {
					writer.close();
				}
				if (reader != null) {
					reader.close();
				}
			}
		}
		
	To keep track of the line count in the code
	========================================
	private Map <String, Integer> linecountMap				= new HashMap <String, Integer>();

	// TODO: Update line count directly to file, Prevent storing value.
				if (!linecountMap.containsKey(currentTimestamp)) {
					linecountMap.put(currentTimestamp, lineCount);
				} else {
					Integer value			= linecountMap.get(currentTimestamp);
					if (value == null)
						value = 0;
					
					int currentCount		= value + lineCount;
					linecountMap.put(currentTimestamp, currentCount);
				}
				

		public void insertTrailer() throws Exception {
			
			for (String timestamp : fileMap.keySet()) {
				if (linecountMap.containsKey(timestamp)) {
					int linecount = linecountMap.get(timestamp);
					writeStringToFile(fileMap.get(timestamp), buildTrailer(linecount));
				}
			}
		}
		
	Reading from XML File
	===================
	Source: http://viralpatel.net/blogs/java-xml-xpath-tutorial-parse-xml/
		
	String path = "C:/Users/608156369/IdeaProjects/Java Project/XML_Parser/xml/employee.xml";
	FileInputStream file = new FileInputStream(new File(path));
	DocumentBuilderFactory builderFactory = DocumentBuilderFactory.newInstance();
	DocumentBuilder builder = builderFactory.newDocumentBuilder();
	Document xmlFile = builder.parse(file);
	XPath xpath = XPathFactory.newInstance().newXPath();

	String expression = "/Employees/Employee[@emplid='3333']/email";
	String email = xpath.compile(expression).evaluate(xmlFile);
	System.out.println("Email: " + email);
	
	
	
	