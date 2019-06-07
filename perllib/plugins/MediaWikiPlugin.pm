###########################################################################
#
# MediaWikiPlugin.pm -- html plugin with extra facilities for wiki page 
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999 New Zealand Digital Library Project
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###########################################################################
# This plugin is to process an HTML file from a MediaWiki website which downloaded by 
# the MediaWikiDownload plug. This plugin will trim MediaWiki functional sections like 
# login, discussion, history, etc. Only the navigation and search section could be preserved. 
# Searchbox will be modified to search the Greenstone collection instead of the website.
# It also can automatically add the table of contents on the website's Main_Page to the 
# collection's Home page. 

package MediaWikiPlugin;

use HTMLPlugin;
use unicode;
use util;
use FileUtils;

use strict; # every perl program should have this!
no strict 'refs'; # make an exception so we can use variables as filehandles


sub BEGIN {
    @MediaWikiPlugin::ISA = ('HTMLPlugin');        
}

my $arguments = 
    [          
     # show the table of contents on collection's home page
     { 'name' => "show_toc",
       'desc' => "{MediaWikiPlugin.show_toc}",
       'type' => "flag",
       'reqd' => "no"},
     # set to delete the table of contents section on each MediaWiki page
     { 'name' => "delete_toc",
       'desc' => "{MediaWikiPlugin.delete_toc}",
       'type' => "flag",
       'reqd' => "no"},
     # regexp to match the table of contents
     { 'name' => "toc_exp",
       'desc' => "{MediaWikiPlugin.toc_exp}",
       'type' => "regexp",
       'reqd' => "no",
       'deft' => "<table([^>]*)id=(\\\"|')toc(\\\"|')(.|\\n)*?</table>\\n" },        
     # set to delete the navigation section
     { 'name' => "delete_nav",
       'desc' => "{MediaWikiPlugin.delete_nav}",
       'type' => "flag",
       'reqd' => "no",
       'deft' => ""}, 
     # regexp to match the navigation section    
     { 'name' => "nav_div_exp",
       'desc' => "{MediaWikiPlugin.nav_div_exp}",
       'type' => "regexp",
       'reqd' => "no",
       'deft' => "<div([^>]*)id=(\\\"|')p-navigation(\\\"|')(.|\\n)*?<\/div>" },
     # set to delete the searchbox section
     { 'name' => "delete_searchbox",
       'desc' => "{MediaWikiPlugin.delete_searchbox}",
       'type' => "flag",
       'reqd' => "no",
       'deft' => ""},
     # regexp to match the searchbox section
     { 'name' => "searchbox_div_exp",
       'desc' => "{MediaWikiPlugin.searchbox_div_exp}",
       'type' => "regexp",
       'reqd' => "no",
       'deft' => "<div([^>]*)id=(\\\"|')p-search(\\\"|')(.|\\n)*?<\/div>"},     
     # regexp to match title suffix
     # can't use the title_sub option in HTMLPlugin instead
     # because title_sub always matches from the begining      
     { 'name' => "remove_title_suffix_exp",
       'desc' => "{MediaWikiPlugin.remove_title_suffix_exp}",
       'type' => "regexp",
       'reqd' => "no",
       'deft' => ""}
     ];

my $options = { 'name'     => "MediaWikiPlugin",
		'desc'     => "{MediaWikiPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);
    
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
    
    my $self = new HTMLPlugin($pluginlist, $inputargs, $hashArgOptLists);    
    return bless $self, $class;
}



sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    my @head_and_body = split(/<body/i,$$textref);
    my $head = shift(@head_and_body);
    my $body_text = join("<body", @head_and_body);      
    
    $head =~ m/<title>(.+)<\/title>/i;
    my $doctitle = $1 if defined $1;    
    
    if (defined $self->{'metadata_fields'} && $self->{'metadata_fields'}=~ /\S/) {
	my @doc_properties = split(/<xml>/i,$head);
	my $doc_heading = shift(@doc_properties);
	my $rest_doc_properties = join(" ", @doc_properties);
	
	my @extracted_metadata = split(/<\/xml>/i, $rest_doc_properties);
	my $extracted_metadata = shift (@extracted_metadata);
	$self->extract_metadata($extracted_metadata, $metadata, $doc_obj);
    }
    
    # set the title here if we haven't found it yet
    if (!defined $doc_obj->get_metadata_element ($doc_obj->get_top_section(), "Title")) {    
	if (defined $doctitle && $doctitle =~ /\S/) {        	    
            # remove suffix in title if required
            my $remove_suffix_exp = $self->{'remove_title_suffix_exp'};
	    if (defined $remove_suffix_exp && $remove_suffix_exp =~ /\S/){
	       $doctitle =~ s/$remove_suffix_exp//i;
	    }	    
	    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Title", $doctitle);
	} else {
	    $self->title_fallback($doc_obj,$doc_obj->get_top_section(),$file);
	}
    }

    # we are only interested in the column-contents div <div id="column-content">
    # remove header section, it may contain header images or additional search boxes
    my $header_exp = "<div([^>]*)id=(\"|')container(\"|')([^>]*)>(.|\\n)*<div([^>]*)id=(\"|')column-content";
    if($body_text =~ /$header_exp/){
	    $body_text =~ s/$header_exp/<div$1id='container'$4><div$6id='column-content/isg;
	} else {				
		$header_exp = "(.|\\n)*?<div([^>]*)?id=(\"|')column-content";
                if($body_text =~ /$header_exp/){
                  $body_text =~ s/$header_exp/<div$2id='column-content/i;                
                }
	}
    
    # remove timeline
    $body_text =~ s/<div([^>]*)class=("|')smwtimeline("|')[\s\S]*?<\/div>//mg;
    
    # remove extra bits
    my $extra_bits = "Retrieved from(.+)</a>\"";
    $body_text =~ s/$extra_bits//isg;
    
    $body_text =~ s/(<p[^>]*><span[^>]*><o:p>&nbsp;<\/o:p><\/span><\/p>)//isg;
    $body_text =~ s/(<p[^>]*><o:p>&nbsp;<\/o:p><\/p>)//isg;
    $body_text =~ s/<!\[if !vml\]>/<![if vml]>/g; 
    $body_text =~ s/(&nbsp;)+/&nbsp;/sg;
    
    # get rid of the [edit] buttons
    $body_text =~ s/\[<a([^>]*)>edit<\/a>]//g;
    # get rid of the last time edit information at the bottom
    $body_text =~ s/<a href="([^>]*)edit([^>]*)"([^>]*?)>(\w+)<\/a> \d\d:\d\d,([\s|\w]*?)\(PST\)//g;    
    # get rid of the (Redirected from ...)
    $body_text =~ s/\(Redirected from <a ([^>]*)>(\w|\s)*?<\/a>\)//isg;  
    
    # escape texts macros
    $body_text =~ s/_([^\s]*)_/_<span>$1<\/span>_/isg;
    # may change the links, like Greenstone_Documentation_All.html, then change back
    $body_text =~ s/<a([^>]*)_<span>([^>]*)<\/span>_/<a$1_$2_/isg;
    
    # define file delimiter for different platforms
    my $file_delimiter;
    if ($ENV{'GSDLOS'} =~ /^windows$/i) {
       $file_delimiter = "\\";
    } else {
       $file_delimiter = "/";	        
    }    
    
    # IMPORTANT: different delimiter for $base_dir and $file
    # $base_dir use forward slash for both windows and linux
    # print "\nbase_dir : $base_dir\n\n"; # windows: C:/Program Files/Greenstone2.73/collect/wiki/import    
                                        # linux: /research/lh92/greenstone/greenstone2.73/collect/wiki/import
    # $file use different delimiters : forward slash for linux; backward slash for windows
    # print "\nfile : $file\n\n";         # windows: greenstone.sourceforge.net\wiki\index.php\Access_Processing_using_DBPlugin.html    
                                        # linux: greenstone.sourceforge.net/wiki/index.php/Using_GreenstoneWiki.html
    
    # get the base url for the MediaWiki website
    my $safe_delimiter = &safe_escape_regexp($file_delimiter);
    my @url_dirs=split($safe_delimiter, $file);
    my $url_base = $url_dirs[0];    
        
    # Re-check css files associated with MediaWiki pages
    if(defined $base_dir && $base_dir ne ""){ 	
	my @css_files;
	my $css_file_count = 0;
	
	# find all the stylesheets imported with @import statement	
	while($head =~ m"<style type=\"text/css\"(.+)import \"(.+)\""ig){
	    $css_files[$css_file_count++] = $2 if defined $2;
	}

	# Set the env for wget once, outside the for loop
	# the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
	&util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set
	    
	# download the stylesheets if we haven't downloaded them yet
        # add prefix to each style elmement, comment out the body element
        # and copy the files to collection's style folder 
	for ($css_file_count = 0; $css_file_count < scalar(@css_files); $css_file_count++) {	    
	    
	    my $css_file = $css_files[$css_file_count];	      
	    
	    # remove prefix gli/cache directory	                
            $css_file =~ s/^(.+)gli(\\|\/)cache(\\|\/)//i;
                        
            # change the \ delimiter in $css_file to / for consistency
            $css_file =~ s/\\/\//isg;
            if($css_file !~ /$url_base/) {
              $css_file = $url_base . $css_file;  
            }
            
            # trim the ? mark append to the end of a stylesheet
	    $css_file =~ s/\?(.+)$//isg;  
	   
            my $css_file_path = &FileUtils::filenameConcatenate($base_dir, $css_file);	    
	    
	    # do nothing if we have already downloaded the css files
	    if (! -e $css_file_path) {		
	     
             # check the stylesheet's directory in the import folder
             # if the directory doesn't exist, create one            
	     my @dirs = split(/\//i,$css_file);	    
	     my $path_check = "$base_dir/";            
	     for (my $i = 0; $i < (scalar(@dirs)-1); $i++) {
		$path_check .= $dirs[$i] . "/";	
		mkdir($path_check) if (! -d $path_check );
	     }

             # NOTE: wget needs configuration to directly access Internet
             # These files should already downloaded if we used the MediaWikiDownload             
	     # downloading            
	     $css_file = "http://$css_file";	    
             print "\ndownloading : " . $css_file . "\n\n";
	     system("wget", "--non-verbose", "$css_file", "--output-document=$css_file_path");
	     if ($? != 0) {
              print "[ERROR] Download Failed! Make sure WGet connects to Internet directly \n";
              print "[ERROR] OR ues the MediaWikiDownload in the GLI DownloadPanel to download from a MediaWiki website\n";
              unlink("$css_file_path");
             }
            } # done with download
		
	    # add a prefix "#wikispecificstyle" to each element
	    # because we want to preserve this website's formats and don't want to mess up with Greenstone formats
            # so we will wrap the web page with a div with id = wikispecificstyle
            my $css_content;
	    if(open(INPUT, "<$css_file_path")){		
		while(my $line = <INPUT>){
                    # comment out the body element because we change the body to div
                    $line =~ s/^(\s*)body(\s*){(\s*)$/$1\/*body$2*\/{$3/isg;
                    
                    if($line =~ m/^(.+)\{/i || $line =~ m/^(\s)*#/i){                    
                      if($line !~ m/wikispecificstyle/i){
                        $line = "#wikispecificstyle " . $line;
                      } 
                    }
                    
		    $css_content .= $line;
		}
		close(INPUT);			
		open(OUTPUT, ">$css_file_path");
		print OUTPUT $css_content;
		close(OUTPUT);
	    }
            
            # Copy the modified stylesheets to collection's style folder
            # for future customization
            my $style_dir = $base_dir;
            $style_dir =~ s/import$/style/;
            $css_file =~ m/(.*)\/(.*)$/;
            $style_dir = &FileUtils::filenameConcatenate($style_dir, $2);            
            
            if(open(OUTPUT, ">$style_dir")){	
              print OUTPUT $css_content;
              close(OUTPUT);
            }
	}
    }    
    
    
    # by default, only preserve navigation box and search box
    # others like toolbox, interaction, languages box, will be removed  
    
    # extract the larger part -- footer section
    my $print_footer = "<div class=\"printfooter\">(.|\n)+</body>";
    $body_text =~ /$print_footer/;
    my $footer = "";
    $footer = $& if defined $&;
    $footer =~ s/<\/body>//isg;
    
    # trim the comments first    
    $footer =~ s/<!--[\s\S]*?--[ \t\n\r]*>//isg;
    
    # contain sections that are to be preserved
    my $preserve_sections = "";   
    
    # process the navigation section    
    my $nav_match_exp = "<div([^>]*)id=(\"|')p-navigation(\"|')(.|\n)*?<\/div>";
    if (defined $self->{'nav_div_exp'}) {
      $nav_match_exp = $self->{'nav_div_exp'} if ($self->{'nav_div_exp'} =~ /\S/) ;
    }
        
    if (defined $self->{'delete_nav'} && ($self->{'delete_nav'} eq "1")) {	
        # do nothing	
    } else {      
      if ($footer =~ m/$nav_match_exp/ig) {
        $preserve_sections = $& ;
      } else {
        print $outhandle "Can't find the navigation section with : $nav_match_exp\n";
      }
      # if($preserve_sections =~/\S/){
      #  $preserve_sections .= "</div>";
      # }            
    }          
            
    # process the searchbox section        
    my $searchbox_exp = "<div([^>]*)id=(\"|')p-search(\"|')(.|\\n)*?<\/div>";
    if(defined $self->{'searchbox_div_exp'}) {                
        $searchbox_exp = $self->{'searchbox_div_exp'} if ($self->{'searchbox_div_exp'} =~ /\S/);
    }    
                        
    my $searchbox_section = "";    
    $footer =~ m/$searchbox_exp/ig;
    $searchbox_section = $& if defined $&;    
    
    # make the searchbox form work in Greenstone
    if($searchbox_section =~ /\S/){        
        # replace action
        $searchbox_section =~ s/action="([^>]*)"/action="_gwcgi_"/isg;
                
        # remove buttons
        $searchbox_section =~ s/name="search"/name="q"/isg;
        $searchbox_section =~ s/name="go"//isg;
        $searchbox_section =~ s/name="fulltext"//isg;
                
        # get collection name from $base_dir for c param        
        $base_dir =~ m/\/collect\/(.+)\//i;
        my $collection_name = "";
        $collection_name = $1 if defined $1;
        
        # add Greenstone search params
        my $hidden_params = "<input type=\"hidden\" name=\"a\" value=\"q\"/>\n" 
            ."<input type=\"hidden\" name=\"c\" value=\"$collection_name\"/>\n";
            # ."<input type=\"hidden\" name=\"fqf\" value=\"TX\"/>\n"
            # ."<input type=\"hidden\" name=\"r\" value=\"1\">\n";
        
        $searchbox_section =~ s/<form([^>]*)>/<form$1>\n$hidden_params/isg;         
        
        # $searchbox_section .= "</div>";
    } else {
      print $outhandle "Can't find the searchbox section with : $searchbox_section\n";
    }        
    
    # either delete or replace the searchbox 
    if(defined $self->{'delete_searchbox'} && $self->{'delete_searchbox'} eq "1") {
        # do nothing        
    } else {
        $preserve_sections .= "\n$searchbox_section\n";
    } 
    
    if($preserve_sections ne ""){
      $preserve_sections = "<div id=\"column-one\">\n" . $preserve_sections . "\n</div>\n";
    }
    $preserve_sections = "</div></div></div>\n" . $preserve_sections . "\n</body>";   
            
    $body_text =~ s/$print_footer/$preserve_sections/isg;
    
    
    # delete other forms in the page
    my @forms;
    my $form_count = 0;
    while($body_text =~ m/<form([^>]*)name=("|')([^>"']*)?("|')/isg){
        next if($3 eq "searchform");
        $forms[$form_count++] = $&;        
    }
    foreach my $form (@forms) {      
      $body_text =~ s/$form[\s\S]*?<\/form>//m;
    }
    
    # process links. 
    # because current WGET 1.10 the -k and -E option doesn't work together
    # need to 'manually' convert the links to relative links
    # Dealing with 3 types of links:
    # -- outgoing links
    #   -- if we have downloaded the target files, link to the internal version (relative link)
    #   -- otherwise, link to the external version (absolute links)
    # -- in-page links (relative link)
    
    # NOTE: (important)
    #   must use the MediaWikiDownload in GLI Download Panel to download files from a MediaWiki website
    #   otherwise, the internal links may have problems
    
    # remove the title attribute of <a> tag
    $body_text =~ s/<a([^>]*)title="(.*?)"/<a$1/isg;
    
    # extract all the links
    my @links;
    my $link_count = 0;    
    while($body_text =~ m/(href|src)="([^>\s]*)$url_base\/([^>\s]*)"/ig){        
        $links[$link_count++] = "$1=\"$2$url_base/$3\"";		
    }
    
    foreach my $cur_link (@links) {     
        # escape greedy match + character
        $cur_link =~ s/\+/\\+/isg;
        
        $cur_link =~ m/(.+)"([^>]*)$url_base\/([^>\s]*)"/;          
        my $external_file_path = "$1\"http://$url_base/$3\"";
           
        $body_text =~ s/$cur_link/$external_file_path/i; 
    }
             
    # tag links to new wiki pages as red    
    $body_text =~ s/<a([^>]*)class="new"([^>]*)>/<a$1style="color:red"$2)>/gi;
    
    # tag links to pages external of the MediaWiki website as blue
    $body_text =~ s/<a([^>]*)class='external text'([^>]*)>/<a$1style="color:blue"$2)>/gi;
        
    
    # process the table-of-contents section
    # if 'show_toc' is set, add Main_Page's toc to the collection's About page, change extra.dm file     
    # 1. read _content_ macro from about.dm
    # 2. append the toc, change all links to the Greenstone internal format for relative links 
    # 3. write to the extra.dm
    # TODO: we assume the _about:content_ hasn't been specified before
    #	    so needs to add function to handle when the macro is already in the extra.dm	   
    if($self->{'show_toc'}==1 && $file =~ m/Main_Page.(html|htm)$/){
    
      # extract toc of the Main_Page           	 
      my $mainpage_toc = "";  
      my $toc_exp = "<table([^>]*)id=(\"|')toc(\"|')(.|\\n)*</table>\\n";
      if($self->{'toc_exp'} =~ /\S/){
         $toc_exp = $self->{'toc_exp'};	     
      }
      if($body_text =~ /$toc_exp/){                      	
        $mainpage_toc = $&;
      }
        
      if($mainpage_toc =~ /\S/) {
        
        # change the in-page links to relative links, for example, change <a href="#section1"> to 
        # <a href="_httpquery_&a=extlink&rl=1&href=http://www.mediawikisite.com/Main_Page.html#section1">           
        my $file_url_format = $file;
        $file_url_format =~ s/\\/\//isg; 
	$file_url_format = "http://" . $file_url_format;
	   
        # encode as URL, otherwise doesn't work on Windows
        $file_url_format =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
	$mainpage_toc =~ s/<a href="([^>"#]*)#([^>"]*)"/<a href="_httpquery_&a=extlink&rl=1&href=$file_url_format#$2"/isg;
        
        
        # read the collection's extra.dm    
        my $macro_path = $base_dir;
        $macro_path =~ s/import$/macros/;    	
    	my $extradm_file = &FileUtils::filenameConcatenate($macro_path, "extra.dm");        
        
        my $extra_dm = "";
        if(open(INPUT, "<$extradm_file")){    	            
	    while(my $line = <INPUT>){
		$extra_dm .= $line;
	    }	    	
        } else {
            print $outhandle "can't open file $extradm_file\n";
        }
        close(INPUT);
        
        # check whether we have changed the macros
        my @packages = split("package ", $extra_dm);
        my $about_package = "";
        foreach my $package (@packages) {
          $about_package = "package " . $package if($package =~ /^about/);
        }      
                
        my $update_extra_dm = 0;        
        
        if( $about_package =~ /\S/ && $about_package =~ m/_content_(\s*){/ && $about_package =~ m/$mainpage_toc/){  
	   print $outhandle "_content_ macro already changed!!!!\n";
	}
        # if extra.dm doesn't have an "about package"
        elsif ($about_package !~ /\S/) {          
          # read _content_ macro from $GSDLHOME/macros/about.dm file          
	  my $global_about_package = $self->read_content_from_about_dm();	    
            
          # create the extra _content_ macro for this collection           
          # add the original content of the _content_ macro
          $global_about_package =~ m/{(.|\n)*<\/div>\n\n/;
          
          # append the new about package to extra.dm
          $extra_dm .= "\n\npackage about\n_content_$&\n\n";
          $extra_dm .= "<div class=\"section\">\n$mainpage_toc\n</div>\n</div>\n}";
          
          $update_extra_dm = 1;
        } 
        # the about package exists, but either doesn't have the _content_ macro or 
        # the _content_ macro doesn't contain the toc
        else {        
          # check if there is a content macro   
          my $content_macro_existed = 0;
          $content_macro_existed = ($about_package =~ /(\s*|\n)_content_(\s*){/);
            
          # if there is one
          # append a new section div for toc to the end of the document section                    
          if($content_macro_existed ==1) {
            $about_package =~ /(\s*|\n)_content_(\s*){(.|\n)*?}/;
            my $content_macro = $&;                          
            my $new_content_macro = $content_macro;
            $new_content_macro =~ s/<div[^>]*class="document">(.|\n)*<\/div>/<div$1class="document">$2\n\n<div class="section">\n$mainpage_toc\n<\/div>\n<\/div>/;              
            $extra_dm =~ s/$content_macro/$new_content_macro/mg;                                    
          }
          # otherwise, append _content_ macro to the about package
          else {
            my $new_about_package = $about_package;            
            my $content_macro = &read_content_from_about_dm();
            $content_macro =~ m/{(.|\n)*<\/div>\n\n/;            
            
            $new_about_package .= "\n\n_content_$&\n\n";
            $new_about_package .= "<div class=\"section\">\n$mainpage_toc\n</div>\n</div>\n}";              
            $extra_dm =~ s/$about_package/$new_about_package/mg;   
          } 
          
          # either the case, we need to update the extra.dm         
          $update_extra_dm = 1;
         }          
                  
         if($update_extra_dm==1){
            # write to the extra.dm file of the collection
            if (open(OUTPUT, ">$extradm_file")) {
                print OUTPUT $extra_dm;
            } else {
                print "can't open $extradm_file\n";
            }
            close(OUTPUT);
         }
      } else {
        print $outhandle "Main_Page doesn't have a table-of-contents section\n";
      }
    }
	
    # If delete_toc is set, remove toc and tof contents.    
    if (defined $self->{'delete_toc'} && ($self->{'delete_toc'} == 1)){
	if (defined $self->{'toc_exp'} && $self->{'toc_exp'} =~ /\S/){		
          # print "\nit matches toc_exp !!\n" if $body_text =~ /$self->{'toc_exp'}/;
          if ($body_text =~ /$self->{'toc_exp'}/) {
	    $body_text =~ s/$self->{'toc_exp'}//i;	    
          }
	}
    }        
    
    $$textref = "<body" . $body_text;
    
    # Wrap the whole page with <div id="wikispecificstyle"></div>
    # keep the style of this website and don't mess up with the Greenstone styles
    $$textref =~ s/<body([^>]*)>/$&\n<div id="wikispecificstyle">\n/is;
    $$textref =~ s/<\/body>/<\/div><\/body>/is;     
	       
    $self->SUPER::process(@_);
    
    return 1;
}


sub extract_metadata 
{
    my $self = shift (@_);
    my ($textref, $metadata, $doc_obj) = @_;
    my $outhandle = $self->{'outhandle'};
    
    return if (!defined $textref);

    # metadata fields to extract/save. 'key' is the (lowercase) name of the
    # html meta, 'value' is the metadata name for greenstone to use
    my %find_fields = ();
    my ($tag,$value);

    my $orig_field = "";
    foreach my $field (split /,/, $self->{'metadata_fields'}) {
	# support tag<tagname>
	if ($field =~ /^(.*?)<(.*?)>$/) {
	    # "$2" is the user's preferred gs metadata name
	    $find_fields{lc($1)}=$2; # lc = lowercase
	    $orig_field = $1;
	} else { # no <tagname> for mapping
	    # "$field" is the user's preferred gs metadata name
	    $find_fields{lc($field)}=$field; # lc = lowercase
	    $orig_field = $field;
	}

	if ($textref =~ m/<o:$orig_field>(.*)<\/o:$orig_field>/i){
	    $tag = $orig_field;
	    $value = $1;
	    if (!defined $value || !defined $tag){
		#print $outhandle "MediaWikiPlugin: can't find VALUE in \"$tag\"\n";
		next;
	    } else {
		# clean up and add
		chomp($value); # remove trailing \n, if any
		$tag = $find_fields{lc($tag)};
		#print $outhandle " extracted \"$tag\" metadata \"$value\"\n" 
		#    if ($self->{'verbosity'} > 2);
		$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), $tag, $value);
	    }
	}
    }
}

sub safe_escape_regexp
{
  my $regexp = shift (@_);
  
  # if ($ENV{'GSDLOS'} =~ /^windows$/i) {
    $regexp =~ s/\\/\\\\/isg;    
  #} else {
    $regexp =~ s/\//\\\//isg;         
  #}
  return $regexp;
}

sub read_content_from_about_dm
{
    my $self = shift(@_);

  my $about_macro_file = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "macros", "about.dm");
  my $about_page_content = "";
  if (open(INPUT, "<$about_macro_file")){
    while (my $line=<INPUT>){
      $about_page_content .= $line;
    }
  } else {
      my $outhandle = $self->{'outhandle'};
    print $outhandle "can't open file $about_macro_file\n";
  }    		
  close(INPUT);
            
  # extract the _content_ macro
  $about_page_content =~ m/_content_ \{(.|\n)*<\/div>\n\n<\/div>\n}/i;
  $about_page_content = $&;
  
  return $about_page_content;
}

1;
