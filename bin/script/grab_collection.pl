#!/usr/bin/perl -w

use util;

# Both this script and its associated process_html.pl were written by
# Marcel ?, while a student at Waikato University. Unfortunately he
# was very new to perl at the time so the code is neither as clean nor
# as fast as it could be (I've cleaned up a few of the more serious
# bottlenecks -- it could do with alot more work though).  The code
# does work though, if a little slowly. It's not ready for primetime
# however and is included in the Greenstone source tree mostly so that
# I don't lose it. -- Stefan - 24 Jul 2001


# This script will download an entire collection (and its associated pictures and files) 
# and store them in a temporary directory ($outputdir). 
# A second script (process_html.pl) can be then be used to 'rebuild' the collection and link all the
# downloaded pages and pictures together into a usable static collection.

# This script will generate a number of text files required by the second script
# and for possible recovery, namely:
# - links.txt        - contains all the http links that were downloaded
# - images.txt       - contains a list of all the images that were downloaded  
# - image_dirs.txt   - contains a list of all the image-prefixes that need to be wiped from the html files
#                      (otherwise you won't get to see any pictures)

# Both this script and the html processing script have a recovery feature built in, they can continue from wherever
# they left off, but this only works if $outputdir and $finaldir are set to different values.
   
# This is where all the downloaded html files end up, eg. 'temp_html/'
my $outputdir  = 'temp_html/';
# This is where all the processed html files (and the pictures) will end up eg. 'my_static_collection/'
my $finaldir   = 'envl_collection/';

# This is where we start our mirroring
$address = 'http://nowhere.com/cgi-bin/library?a=p&p=about&c=demo&u=1';


# whatever is specified in $option will be attached to the end of each html link before it is downloaded.
# eg. "&u=1" to disable various features in the greenstone collections that are not needed with a static
#            collection.
# another example : "&l=nl" to set the entire collection to dutch (NetherLands :)  
my $option = "&u=1";

# Most OS have a limit on the maximum amount of files per directory (or folder).
# A static collection can easily contain >3000 html files. Putting all those files
# into one single directory is just asking for trouble. It's also very unwieldy ;^)
# Hence...this value will set how much html files will be stored in one directory. 
# These directories themselves will be numbered, 
# so if $dir_entries = 500 then the directories will be "0/", "500/", "1000/", "1500/", "2000/", etc. 
my $dir_entries = 250;

# Occasionally a page occurs which contains no data (because &cl is not set) This option fixes that. 
my $fix_empty_pages = "&cl=CL1";

# These are the files that wget will download.
# more can be added if necessary.
my @graphic_formats = ('.gif','.jpg','.bmp','.png','.pdf','.mov','.mpeg','.jpeg','.rm');

# ---------------------------------------[ System specific options ]----------------------------------------------------

# The lynx variable specifies the command line for the lynx web browser
# -- This is what I use under dos/win32
# my $lynx = 'e:\lynx_w32\lynx -cfg=e:\lynx_w32\lynx.cfg';

# -- This is what I use under linux
my $lynx = 'lynx';

# and the same for the wget utility
my $wget = 'wget';

# NB: There is one other linux specific command all the way at the end of this script, where I've used 'cp' to copy a file.       

# Another NB: When saving the dl-ed html files to disk, I've set lynx to dump the html-source to the standard output,
#             which I then simply redirect to a target file, BUT
#             this does not work under DOS/win32. Redirecting standard output in a script causes it to be displayed on
#             the screen instead. The easiest way to get around this I found was by doing the actual redirection in a simple
#             batch file (say grab.bat), which contains the following line:
#             @e:\lynx_w32\lynx -cfg=e:\lynx_w32\lynx.cfg -dump -source "%1" > %2 
#
#             Then replace line nr 326 -> 'system ("$kommand > $target");' with 'system("grab.bat $address $target");'
#             Not a very elegant solution, but it works :) 

#------------------------------------------------------------------------------------------------------------------------

my %image_list;
my $image_pointer = 0;

my %linkz_list;
my %short_linkz_list;
my $linkz_pointer = 0;

my %image_dirs_list;
my $image_dirs_pointer = 0;

my $numberdir = 0;

my $start_time = (times)[0];

# check if directories exist and create them if necessary..
if ((-e $outputdir)&&(-d $outputdir)) 
{ 
    print " ** ",$outputdir," directory already exists..\n"; 
}
else
{
    print " ** Creating ",$outputdir," directory..\n";
    mkdir($outputdir, 0777) or die " Cannot create output directory: $!\n";
}

if ((-e $finaldir)&&(-d $finaldir))
{ 
    print " ** ",$finaldir," directory already exists..\n";
}
else
{
    print " ** Creating ",$finaldir," directory..\n";
    mkdir($finaldir, 0777) or die " Cannot create final directory: $!\n";
}

#-----------------------------------------------------------------------------------------------
# No need to start from scratch everytime, we can recover/continue from wherever we left off
# simply by checking which html files have been created
#-----------------------------------------------------------------------------------------------

$linknumber    = 0;                    # used to name/number the dl-ed html files

my $failed     = 0;
while ($failed == 0)
{
    if ($linknumber % $dir_entries == 0) 
	{
	    if (!((-e $outputdir.$linknumber)&&(-d $outputdir.$linknumber)))
	    {
		$failed++;
		mkdir($outputdir.$linknumber, 0777) or print " ** Cannot create ",$outputdir.$linknumber, "!: $!\n";
	    }
	    $numberdir = $linknumber;
	}

    $check_file = $outputdir.$numberdir."/".$linknumber.".html";
    if ((-e $check_file)&&($failed == 0)) 
    { 
	$linknumber++;
    } 
    else
    {
	$failed++;
	# I'm subtracting 1 from the starting link, 
	# just in case it only loaded half the page ;^)
	if($linknumber>0) 
	{ 
	    $linknumber--; 
	}
	print " Will start downloading at number $linknumber \n";
    }
}

# if we're starting from scratch, then we might as well nuke the links file
#if ($linknumber == 0) 
#{ 
#    print " Starting from scratch - clobbering the old text files...\n";
#    if (-e 'links.txt')
#    {
#	print "   Removing links.txt...\n";   
#	unlink <links.txt> or print " ** Cannot delete links textfile: $!\n";
#    }
#    if (-e 'images.txt')
#    {
#	print "   Removing images.txt...\n";
#	unlink <images.txt> or print " ** Cannot delete images textfile: $!\n";
#    }
#    if (-e 'image_dirs.txt')
#    {
#	print "   Removing image_dirs.txt...\n";
#	unlink <image_dirs.txt> or print " ** Cannot delete image_dirs textfile: $!\n";
#    }
#}

# if we're NOT starting from scratch, then read in old links from links text file
# and grab the old image-links as well...
if ($linknumber != 0)
{
    # load the old links from links.txt, if it doesn't exist, then give up :(
    my $this = "";
    my $that = "";
    open (CHECK, "links.txt") or die " ** Cannot find/open links.txt file!: $! **\n";
    while(eof CHECK == 0)
    {
	while($this ne "\n")
	{
	    read CHECK, $this ,1;
	    $that = $that.$this;   
	}
	$linkz_list[$linkz_pointer] = $that;
	
	for my $search(0 .. (length($that) - 3))
	{
	    if((substr($that, $search, 3) eq '?a=')||(substr($that, $search, 3) eq '&a='))
	    {
		$short_linkz_list[$linkz_pointer] = substr($that, $search);
		last;
	    }
	}
	$linkz_pointer++;
	$that = ""; $this = "";
    }
    close(CHECK);
    print "- I found ",($#linkz_list + 1)," links in links.txt -\n";
    
    #make sure that we start dl-ing the correct first page 
    $address = $linkz_list[$linknumber];

    # load the old image links from image.txt (if it doesn't exist, no big deal ;)
    my $im_this = "";
    my $im_that = "";
    open (IMAGES, "images.txt") || print " ** Cannot find/open images.txt file! : $! **\n";
    while(eof IMAGES == 0)
    {
	while($im_this ne "\n")
	{
	    read IMAGES, $im_this ,1;
	    $im_that = $im_that.$im_this;   
	}
	$image_list[$image_pointer] = $im_that;
	$image_pointer++;
	$im_that = ""; $im_this = "";
    }
    close(IMAGES);
    print "- I found ",($#image_list + 1)," picture-links in images.txt -\n";

    #..and last but not least, load any image_dirs from image_dirs.txt
    # again, if its not there, no big deal :)
    my $imd_this = "";
    my $imd_that = "";
    open (IMAGE_DIR, "image_dirs.txt") || print " ** Cannot find/open image_dirs.txt file!: $! **\n";
    while(eof IMAGE_DIR == 0)
    {
	while($imd_this ne "\n")
	{
	    read IMAGE_DIR, $imd_this ,1;
	    $imd_that = $imd_that.$imd_this;   
	}
	$image_dirs_list[$image_dirs_pointer] = $imd_that;
	$image_dirs_pointer++;
	$imd_that = ""; $imd_this = "";
    }
    close(IMAGE_DIR);
    print "- I found ",($#image_dirs_list + 1)," picture directories in image_dirs.txt -\n";
}

#  Just keep going till we can find no more new links
while(($#linkz_list < 0)||($#linkz_list+1 > $linknumber)) 
{

    # This line specifies the command line for the lynx web browser
    my $kommand = $lynx.' -dump -image_links "'.$address.'"';

    # dump page into text-array and find starting-point of the references/links
    chomp(@data=`$kommand`);
    for my $i(0 .. $#data)
    {
	if ($data[$i] eq "References") {
	    $here = $i;}
    }
    $here = $here+2;

    # process references/links
    for $i($here .. $#data){

	$its_an_image = 0;	     	
    
	#chop-off refs leading number&spaces (eg. '1. http://www.cs.waikato.ac.nz')
	#                                          ^^^
	
#	$temp = substr($data[$i],3);
#	@temp = split(/ /, $temp, 2);
    
	#check if the last 4 characters of the link equal .gif .jpg .png .bmp .pdf .mov .mpeg etc etc
    
#	for my $g(0 .. $#graphic_formats)
#	{
#	    if(substr($temp[1],(length($graphic_formats[$g]) * -1)) eq $graphic_formats[$g])
#	    {
#		$its_an_image = 1;
#	    }
#	}

	$data[$i] =~ s/^\s*\d+\.\s+//;
	if ($data[$i] =~ /\.(gif|jpe?g|png|bmp|pdf|mov|mpe?g|rm)$/i) {
	    $its_an_image = 1;
	}

	# ignore mailto urls
	if ($data[$i] !~ /mailto:/i) {
	
	    #----------- the link is NOT an image ----------------		
	    if ($its_an_image == 0)
	    { 
		&its_a_link($data[$i], $outputdir);
	    }

	    #----------- the link IS an image ----------------
	    if ($its_an_image != 0)
	    { 
		&its_an_image($data[$i], $finaldir); 
	    }
	}
    }	

    # save the web page to disk (in the appropriate numbered directory)
    $kommand = $lynx.' -dump -source "'.$address.'"';

    if ($linknumber % $dir_entries == 0) 
    {
	if ((-e $outputdir.$linknumber)&&(-d $outputdir.$linknumber))
	{
	    print " ** ",$outputdir.$linknumber, " - Directory allready exists.\n";
	}
	else
	{
	    mkdir($outputdir.$linknumber, 0777) or print " ** Cannot create ",$outputdir.$linknumber, "!: $!\n";
	    mkdir($finaldir.$linknumber, 0777)  or print " ** Cannot create ",$outputdir.$linknumber, "!: $!\n";
	}
	$numberdir = $linknumber;
    }
    my $target = $outputdir.$numberdir."/".$linknumber.".html";

    #---------------------------------------------------------------------------------------------------------------
    # NOTE: This next command will NOT work under win32/dos, as redirecting standard output in a script causes it to
    #       be dumped straight to the screen as opposed to into the target file.
    #---------------------------------------------------------------------------------------------------------------
    system ("$kommand > $target");
    #---------------------------------------------------------------------------------------------------------------

    print " Saved $target\n";

    $linknumber++;

    $address = $linkz_list[$linknumber];
}

my $end_time = (times)[0];

print "\n\n\n *----------------------------*\n";
print " |  Whew! Task completed! :-D |\n";
print " *----------------------------*\n";
printf"  Script took %.2f CPU seconds to complete ;^)\n", $end_time - $start_time;
print "\n\n"; 
print "  Now execute the  process_html.pl  script to link the downloaded collection together.\n";
print "  Please do make sure that it is executed with the same options as this script ;-)\n";

sub its_a_link 
{
    local($found) = @_;
#    local($ok = 0, $kommand);
    local($kommand);
    local $short_link = "";

    return if ($found =~ /\#.*$/);

    # attach the custom options
    $found .= $option;
    
    #little bit of trickery here - check if there is a &d= option present in the link
    #if there is, then wipe the &cl= option!
    #This should cut down multiple copies by 75%!!
    
    #but, if there is no &d option, and the &cl option is not set, then we have to set the &cl option to something
    #otherwise we get pages which contain no data :\

    if ($found =~ /[&\?]a=d/) {
	if ($found =~ /[&\?]d=/) {
	    $found =~ s/[&\?]cl=[^&]*//;
	} elsif ($found !~ /[&\?]cl=/) {
	    $found .= $fix_empty_pages;
	}
    }

    # we also want to sort out any xxx.pr OIDs that we come across
    $found =~ s/([&\?](cl|d)=.*?)\.\d+\.pr/$1/g;

    # attach the EOL character.
    $found = $found."\n";


    # the hard way !!!
#    for my $search(0 .. (length($found) - 3))
#    {
#	if((substr($found, $search, 3) eq '?d=')||(substr($found, $search, 3) eq '&d='))
#	{
#	    for my $second_search(0 .. (length($found) - 4))  
#	    {
#		if((substr($found, $second_search, 4) eq '?cl=')||(substr($found, $second_search, 4) eq '&cl='))
#		{
#		    for my $third_search(($second_search + 3) .. (length($found) - 1))
#		    {
#			if((substr($found, $third_search, 1)) eq '&')
#			{
#			    substr($found, $second_search, $third_search - $second_search) = ""; 
#			    last;
#			}
#		    }
#		    last;
#		}
#	    } 
#	    last;
#	}
#	else
#	{
#	    if( $search == (length($found) - 3))
#	    {
#		for my $second_search(0 .. (length($found) - 4))  
#		{
#		    if((substr($found, $second_search, 4) eq '?cl=')||(substr($found, $second_search, 4) eq '&cl='))
#		    {
#			for my $third_search(($second_search + 3) .. (length($found) - 1))
#			{
#			    if((substr($found, $third_search, 1)) eq '&')
#			    {
#				if (substr($found, $second_search, $third_search - $second_search) eq '&cl=')
#				{
#				    substr($found, $second_search, $third_search - $second_search) = $fix_empty_pages;	
#				}
#				last;
#			    }
#			}
#			last;
#		    }
#		} 
#	    }
#	}
#    }
    
    # grab the last part of the link (ignoring the start and the &e option)
#    for my $search(0 .. (length($found) - 3))
#    {
#	if((substr($found, $search, 3) eq '?a=')||(substr($found, $search, 3) eq '&a='))
#	{
#	    $short_link = substr($found, $search);
#	    last;
#	}
#    }

    ($short_link) = $found =~ /\?(.*)$/;
    $short_link =~ s/(^|&)e=[^&]*/$1/;

    
    # this filters out multiple copies of for example the help page, which has #something at the end of its links
    # now do this first with regular expression above -- Stefan

#    for my $search(0 .. length($found))
#    {
#	if ((substr($found, $search, 1)) eq '#')
#	{
#	    $ok++;
#	    last;
#	}
#    }
 

   
    # compare the found link to the links we've stored in the arrays (compares both full link and partial link)
    for my $search(0 .. $#linkz_list)
    {
	return if ($found eq $linkz_list[$search]);
	return if ($short_link eq $short_linkz_list[$search]);
    }
		    
    # if found link is not in links array, add it
    open (DUMP, ">>links.txt") or die " ** Can't open links.txt!: $!\n";
    print DUMP $found;
    close(DUMP);
    
    $linkz_list[$linkz_pointer] = $found;
    $short_linkz_list[$linkz_pointer] = $short_link;
    $linkz_pointer++;
}

sub do_image_dirs
{
    local($found) = @_;
    my $count = 0;
    my @br_index;
    my $image_dir = "";
    my $new_dir = 0;

    for my $search(1 .. (length($found) - 1 ))
    {
	$bracket = substr($found, ($search * - 1), 1);
	if ($bracket eq '/')
	{
	    $count++;
	    $br_index[$count] = $search;
	}
	if($count == 2) 
	{
	    $image_dir = substr($found, ($br_index[2] * -1) , ($br_index[2] - $br_index[1]));
	}
    }
    
    my $dirs_to_wipe = substr($found, $br_index[$#br_index - 2] * - 1, $br_index[$#br_index - 2] - $br_index[2] + 1)."\n";
    
    for my $counter(0 .. $#image_dirs_list)
    {
	if($dirs_to_wipe eq $image_dirs_list[$counter])
	{
	    $new_dir++;
	}
    }
    
    if ($new_dir == 0)
    {
	open (IMAGE_DIRS, ">>image_dirs.txt") or die " ** Can't open image_dirs.txt!: $!\n";
	print IMAGE_DIRS $dirs_to_wipe;
	close(IMAGE_DIRS);
	$image_dirs_list[$image_dirs_pointer] = $dirs_to_wipe;
	$image_dirs_pointer++;
    }

    print "   ",substr($finaldir, 0 ,length($finaldir) - 1).$image_dir.substr($found, ($br_index[1] * - 1), length($found) - (length($found) - $br_index[1])),"\n";	    
    
    return $image_dir;
}

sub its_an_image 
{
    local($found, $outpdir) = @_;
    local($kommand);
    my $new = 0;
    
    my $temp_found = $found . "\n";

    # check if the image is in the list
    for my $counter(0 .. $#image_list)
    {
	if($temp_found eq $image_list[$counter])
	{
	    $new++;
	}
    }
    
    # only download the image if its not in the list..
    if($new == 0)
    {    
	my $image_dir = &do_image_dirs;
	my $temp_outputdir = $outpdir;
	if (substr($temp_outputdir, -1, 1) eq "/")
	{
	    substr($temp_outputdir, -1, 1) = "";
	}
	
	# the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
	&util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set

	# wget is set to 'q - quiet' and 'nc - dont clobber existing files'
	$kommand = $wget.' -qnc --directory-prefix='.$temp_outputdir.$image_dir.' "'.$found.'"';
	system ("$kommand");
        
	open (IMAGES, ">>images.txt") or die " ** Can't open images.txt!: $!\n";
	print IMAGES $temp_found;
	close(IMAGES);
	
	$image_list[$image_pointer] = $temp_found;
	$image_pointer++;
	
        # grab corresponding ON pictures for navigation bar if we've just dl-ed the OFF picture
	if(substr($found , -6) eq "of.gif") 
	{
	    substr($found, -6, 6) = "on.gif";
	    &its_an_image($found, $outpdir);
	}
    }    
}
