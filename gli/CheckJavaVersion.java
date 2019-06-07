import java.util.regex.Pattern;


public class CheckJavaVersion {
	static final String MINIMUM_VERSION_PREFIX = "1.4";
	
	/**
	 * @param args, arg[0] is the minium version of Java required
	 * to run the program. arg[1] is the name of the program.
	 * If arg[1] is left out, then no distinct program name is
	 * mentioned. If arg[0] is left out as well, then Greenstone3's
	 * minimum default version of 1.4.x is assumed.
	 * The program exits with 1 if the Java version being used is 
	 * incompatible and with 2 if it is acceptable.
	 */
	public static void main(String[] args) {
		String minimumVersion = MINIMUM_VERSION_PREFIX;
		String programName = "this program"; 
		// the version of java that's in use
		String runningJavaVersion = System.getProperty("java.version");
		
		if(args.length > 0) {
			minimumVersion = args[0];
		}
		if(args.length > 1) {
			programName = args[1];
		}
		
		System.out.println("\nChecking for a compatible Java version..."
				+ "\nLooking for minimum version: " + minimumVersion);
		
		// Version numbers can be of the form "1.5.0_2" 
		// We want to split version numbers into the individual numbers
		// For example: splitting 1.5.0_2 will give us {1,5,0,2},
		// while splitting 1.5.0_10 will give us {1,5,0,10}.
		// The comparison then is straightforward.
		
		// We will split version strings into the individual numbers
		// using regular expressions. However, the tokens . and _ are
		// reserved in regular expressions and need to be escaped: 
		// Period: \Q.\E;  underscore: \Q_\E.
		// Once escaped, it should be indicated in the regular expression
		// that the two characters are separate tokens by using |, so 
		// that the regex becomes: ".|_" -> \Q.\E|\Q_\E.
		String period = "\\Q.\\E";
		String underscore = "\\Q_\\E";
			 // Can't use Pattern.quote() since it is not there in Java 1.4.*
		     //String period = Pattern.quote(".");
		     //String underscore = Pattern.quote("_");
		
		String[] minVersionNums = minimumVersion.split(period+"|"+underscore);
		String[] runningVersionNums =runningJavaVersion.split(period+"|"+underscore);
		
		boolean acceptable = true;
		// only keep looping while we haven't gone past the end of either array
		int i=0;
		for(; i < minVersionNums.length && i < runningVersionNums.length; i++)
		{
			int min = Integer.parseInt(minVersionNums[i]);
			int run = Integer.parseInt(runningVersionNums[i]);
			if(run > min) { 
			        // certain success: one of the higher positional numbers 
			        // of the running version is greater than the corresponding
			        // number of the minimum version, meaning we've finished.
				break;
			} else if(run < min) { 
				// fail: running version number is lower than corresponding 
				// minimum version number
				acceptable = false;
				break;
			} 
		}
		
		// Consider minVersion = 1.5.0_10 and runningVersion = 1.5.0
		// this means the runningversion is still insufficient. 
		// HOWEVER, minVersion being longer does not always mean it is
		// a later version, consider: min=1.5.0_9.12 and run=1.5.0_10
		// This should be acceptable since 10 > 9 even though min is longer.
		// SOLUTION: If the last values for both were the same, the running 
		// Version is not compatible if the minVersionNums array is longer
		int min = Integer.parseInt(minVersionNums[i-1]);
		int run = Integer.parseInt(runningVersionNums[i-1]);
		
		// if the last values were the same, check whether min is longer
		// in which case the running version is not acceptable
		if(min == run && minVersionNums.length > runningVersionNums.length) 
		{
			acceptable = false;
		}
		
		if(acceptable) {
			System.out.println("Found compatible Java version " +runningJavaVersion);
			System.exit(2); // acceptable case
		} else {
			System.out.println("The current Java version " + 
				runningJavaVersion + " is insufficient to run " + programName);
			System.exit(1);
		} 
	}
}