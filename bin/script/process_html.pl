#!/usr/bin/perl -w


# Both this script and its associated process_html.pl were written by
# Marcel ?, while a student at Waikato University. Unfortunately he
# was very new to perl at the time so the code is neither as clean nor
# as fast as it could be (I've cleaned up a few of the more serious
# bottlenecks -- it could do with alot more work though).  The code
# does work though, if a little slowly. It's not ready for primetime
# however and is included in the Greenstone source tree mostly so that
# I don't lose it. -- Stefan - 24 Jul 2001


# This script rebuilds the static collection by linking all the downloaded html files
# back together. 
# It searches through html files and replaces links it recognizes from the links.txt file 
# with the apropriate html file name (eg 1.html, 2.html etc)
# This script also updates the links for the pictures.

# This is where all the dl-ed html files are located, eg. 'temp_html/'
my $outputdir  = 'temp_html/';

# This is where all the processed files end up (don't want to overwrite originals ;) eg. 'my_static_collection/'
my $finaldir   = 'envl_collection/';

# If any options where used (such as &u=1) when the html files where dl-ed then please specify them here.
my $option = "&u=1";

# Please ensure these two options match the settings used when downloading the collection :)
my $dir_entries = 250;
my $fix_empty_pages = '&cl=CL1';

#-------------------------------------------------------------------------------------------------

# global arrays used to store links, links-index & html-filenames
my %filez;
my %out_filez;
my %linkz;
my %short_linkz1;
my %short_linkz2;
my %short_linkz3;
my %linkz_index;
#my %remove_these;
my $remove_these = "";

sub processfiles
{
    local($start_here) = @_;

    for my $file($start_here .. $#filez)
    {
	if((-e $filez[$file])&&(-s $filez[$file]))
	{
	    open (FILE, $filez[$file]) or die "can't open ", $filez[$file],": $! \n";
	    
	    print " $filez[$file] ";
	    
	    undef $/;
	    my $content_of_file = <FILE>;
	    $/ = "\n";
	    close(FILE);
	    
	    #quick & nasty fix for the 'open book' link
	    local $quick_fix1 = "&cl=\"";
	    local $quick_fix2 = "&cl=\'";
	    
	    $content_of_file =~ s/$quick_fix1/$fix_empty_pages\"/g;
	    $content_of_file =~ s/$quick_fix2/$fix_empty_pages\'/g;
	    
	    for my $link(0 .. $#linkz)
	    {
		my $new_link = $linkz_index[$link].".html";
		
		if($short_linkz3[$link] ne "")
		{
		    $content_of_file =~ s/$short_linkz1[$link].*?$short_linkz2[$link].*?${short_linkz3[$link]}[^\"\'\s\>]*/$new_link/g;
		}
		else
		{
			$content_of_file =~ s/$short_linkz1[$link].*${short_linkz2[$link]}[^\"\'\s\>]*/$new_link/g;
		}
	    }
    
            $content_of_file =~ s/(["'])$remove_these/$1..\//g;
	    open (TEMP, ">temp.html") or die "can't open temp.html: $! \n";
	    print TEMP $content_of_file;
	    close(TEMP);
	    rename("temp.html", $out_filez[$file]) or die "cannot create", $out_filez[$file],": $! \n";
	    print " --> $out_filez[$file]";
	    print "..done\n";
	}
	else
	{
	    last;    # bomb out of loop. Done.
	}
    }
     print " *** Done, cannot find any more files to process ***\n";
}

# the switch variable there so that I can create a couple of additional arrays without having to write an entirely new function :-)
# 0 = off, 1 = on (puts values into %linkz_index, %short_linkz1 and %short_linkz2)
sub sort_array_by_length
{
    local (*foo, $switch) = @_;
    my $total = $#foo;
    my %temp_linkz;
    my $shortest = 999999;
    my $longest = 0;

    if ($switch != 0)
    {
	print "Processing linkz (chopping, slicing, dicing and sorting :-)...";
    }

    for my $counter(0 .. $total)
    {
	if (length($foo[$counter]) < $shortest)
	{
	    $shortest = length($foo[$counter]);   
	    $temp_linkz[$total] = $foo[$counter];
	}
	if (length($foo[$counter]) > $longest)
	{
	    $longest = length($foo[$counter]);   
	}  
    }        
    
    $backward = $total;
    for my $l($shortest .. $longest)
    {      
	local $numberdir = 0;
	for my $counter(0 .. $total)
	{
	    if ($counter % $dir_entries == 0)
	    {
		$numberdir = $counter;
	    }

	    if(length($foo[$counter]) == $l)
	    {
		$temp_linkz[$backward] = $foo[$counter];
		if ($switch != 0)
		{ 
		    $linkz_index[$backward] = "../".$numberdir."/".$counter;
		    my $d_offset = 0;
		    for my $search(0 .. (length($foo[$counter]) - 3))
		    {
			if((substr($foo[$counter], $search, 3) eq '?e=')||(substr($foo[$counter], $search, 3) eq '&e='))
			{
			    $short_linkz1[$backward] = substr($foo[$counter], 0, $search);
			}
			
			for my $second_search($search .. length($foo[$counter]))
			{
			    if((substr($foo[$counter], $second_search, 3) eq '?d=')||(substr($foo[$counter], $second_search, 3) eq '&d='))
			    {
				$short_linkz3[$backward] = substr($foo[$counter], $second_search);
				$d_offset = $second_search;
				last;
			    }
			}
			
			if(substr($foo[$counter], $search, 3) eq '?a=')
			{
			    $short_linkz1[$backward] = substr($foo[$counter], 0, $search);
			    if($d_offset > 0)
			    {
				$short_linkz2[$backward] = substr($foo[$counter], $search, $d_offset - $search);
			    }
			    else
			    {
				$short_linkz2[$backward] = substr($foo[$counter], $search);
			    }
			}
			
			if(substr($foo[$counter], $search, 3) eq '&a=')
			{
			    if($d_offset > 0)
			    {
				$short_linkz2[$backward] = substr($foo[$counter], $search, $d_offset - $search);
			    }
			    else
			    {
				$short_linkz2[$backward] = substr($foo[$counter], $search);
			    }
			}
		    } 
		}
		$backward--;
	    }
	}
    }    
    # copy the sorted temp_array over the original array (must be a better way of doing this :\ )
    for my $counter(0 .. $total)
    {    
	$foo[$counter] = $temp_linkz[$counter];
    }
    if ($switch != 0)
    {
	print "done!\n";
    }
}

sub how_much_to_chop
{
    local($link) = @_;
    my $bracket_counter = 0;
    my $chop_offset = 0;

    for my $search(0 .. length($link))
    {
	if (substr($link, $search, 1) eq '/')
	{
	    $bracket_counter++;   
	}
	if ($bracket_counter == 2)
	{
	    $chop_offset = $search + 1;
	} 
    }
    return $chop_offset;
}

my $start_time = (times)[0]; 

#-----------------------------------------------------------------------------------------------
# No need to start from scratch everytime, we can recover/continue from wherever we left off
# simply by checking which html files have been created
#-----------------------------------------------------------------------------------------------
my $linknumber = 0;
my $failed     = 0;
my $check_file = "";
my $numberdir = 0;

if($outputdir ne $finaldir)
{
    while ($failed == 0)
    {
	if ($linknumber % $dir_entries == 0) 
	{
	    if (!((-e $finaldir.$linknumber)&&(-d $finaldir.$linknumber)))
	    {
		$failed++;
		mkdir($finaldir.$linknumber, 0777) or die " ** Cannot create ",$finaldir.$linknumber, "!: $!\n";
	    }
	    $numberdir = $linknumber;
	}
	
	$check_file = $finaldir.$numberdir."/".$linknumber.".html";
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
	    print " Will start processing at number $linknumber \n";
	}
    }
}
my $i = 0;
my $that = "";
my $offset = 0;

#read in old links from links text file
open (CHECK, "links.txt") || die " ** Cannot find/open links text file!: $!\n";
while (defined ($that = <CHECK>)) {
    
    if ($i == 0)
    {  
	#chop off the first bit
	$offset = &how_much_to_chop($that); 
	print " Offset has been set to: ",$offset,"\n";
	print " This next bit will be ignored for all links in the links.txt file:\n";
	print "  -->",substr($that,0,$offset),"<--\n";
    }
    
    $that = substr($that, $offset);
    
    #Wipe-out the EOL character
#    if (substr($that, -1) eq "\n") { substr($that, -1) = ""; }
    chomp $that;
    
    #this wipes the options
#    if (length($option) != 0)
#    {	    
#	substr($that, (length($option)) * -1) = "";
#    }
    $that =~ s/$option//;
    
    $linkz[$i] = $that;
    
    $short_linkz1[$i] = "";
    $short_linkz2[$i] = "";
    $short_linkz3[$i] = "";
    
    for my $search(0 .. (length($that) - 3))
    {
	if((substr($that, $search, 3) eq '?e=')||(substr($that, $search, 3) eq '&e='))
	{
	    $short_linkz1[$i] = substr($that, 0, $search);
	}
	
	if(substr($that, $search, 3) eq '?a=')
	{
	    $short_linkz1[$i] = substr($that, 0, $search);
	    $short_linkz2[$i] = substr($that, $search);
	}
	if(substr($that, $search, 3) eq '&a=')
	{
	    $short_linkz2[$i] = substr($that, $search);
	}
    }
    $i++;
    
    if ($i % $dir_entries == 0)
    {
	if (!((-e $finaldir.$i)&&(-d $finaldir.$i)))
	{
	    mkdir($finaldir.$i, 0777) or die " ** Cannot create ",$finaldir.$i, "!: $!\n";
	}
    }
}
close(CHECK);

print " - I found ",$i, " links in the links text file -\n";

&sort_array_by_length(*linkz, 1);

$numberdir = 0;

for my $z(0 .. ($i - 1))
{
    if($z % $dir_entries == 0)
    {
	$numberdir = $z;
    }
    $filez[$z] = $outputdir.$numberdir."/".$z.".html";
    $out_filez[$z] = $finaldir.$numberdir."/".$z.".html";
}

# ..and last but not least, load any image_dirs from image_dirs.txt
my $imd_that = "";
#my $image_dirs_pointer = 0;

my @tmp_arr = ();
open (IMAGE_DIR, "image_dirs.txt") || die " ** HEY! Cannot find/open image_dirs.txt file! : $! **\n";
while(defined ($imd_that = <IMAGE_DIR>))
{
    chomp $imd_that;
    push(@tmp_array, $imd_that);
}
close IMAGE_DIR;

$remove_these = "(" . join ("|", sort {length $b <=> length $a} @tmp_array) . ")"; 

#print " - I found ",($#remove_these + 1)," picture directories in image_dirs.txt -\n";
#&sort_array_by_length(*remove_these, 0);

print "-" x 20, "\n";
print "  Here we go...\n";
print "-" x 20, "\n";

&processfiles($linknumber);

my $end_time = (times)[0];
print "\n\n\n *----------------------------*\n";
print " |  Whew! Task completed! :-D |\n";
print " *----------------------------*\n";
printf"  Script took %.2f CPU seconds to complete ;^)\n", $end_time - $start_time;
print "\n\n"; 
print " Now there's a few things left to do...load up ",$finaldir, "0/0.html in your webbrowser and\n";
print " make sure everything works.\n"; 
print " The grab_collection script will have generated 3 text files that can be removed, namely:\n";
print " - links.txt \n";
print " - images.txt \n";
print " - image_dirs.txt \n\n";
if ($outputdir ne $finaldir)
{
    print "And then finally you can also delete the ",$outputdir," directory.\n\n";
}






