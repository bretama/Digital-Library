###########################################################################
#
# LOMPlugin.pm -- plugin for import the collection from LOM
# 
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2005 New Zealand Digital Library Project
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

### Note this plugin currently can't download source documents from outside if you are behind a firewall.
# Unless, you set the http_proxy environment variable to be your proxy server, 
# and set proxy_user and proxy_password in .wgetrc file in home directory. 
# (does that work on windows??)

package LOMPlugin;

use extrametautil;
use ReadTextFile;
use MetadataPass;
use MetadataRead;
use util;
use FileUtils;
use XMLParser;
use Cwd;

# methods with identical signatures take precedence in the order given in the ISA list.
sub BEGIN {
    @ISA = ('MetadataRead', 'ReadTextFile', 'MetadataPass');
}

use strict; # every perl program should have this!
no strict 'refs'; # make an exception so we can use variables as filehandles


my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "string",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      { 'name' => "root_tag",
	'desc' => "{LOMPlugin.root_tag}",
	'type' => "regexp",
	'deft' => q/^(?i)lom$/,
	'reqd' => "no" },
      { 'name' => "check_timestamp",
	'desc' => "{LOMPlugin.check_timestamp}",
	'type' => "flag" },
      { 'name' => "download_srcdocs",
	'desc' => "{LOMPlugin.download_srcdocs}",
	'type' => "regexp",
	'deft' => "",
	'reqd' => "no" }];

my $options = { 'name'     => "LOMPlugin",
		'desc'     => "{LOMPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };



my ($self);
sub new {
    my $class = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);
    
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
   
    $self = new ReadTextFile($pluginlist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about creating the XML parser as all we want is the 
	# list of plugin options
	return bless $self, $class;
    }

    #create XML::Parser object for parsing dublin_core.xml files
    my $parser = new XML::Parser('Style' => 'Stream',
				 'Handlers' => {'Char' => \&Char,
						'Doctype' => \&Doctype
						});
    $self->{'parser'} = $parser;

    $self->{'extra_blocks'} = {};

    return bless $self, $class;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)\.xml$^;
}


sub can_process_this_file {
    my $self = shift(@_);
    my ($filename) = @_;

    if ($self->SUPER::can_process_this_file($filename) && $self->check_doctype($filename)) {
	return 1; # its a file for us
    }
    return 0;
}

sub metadata_read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile,
	$processor, $gli, $aux) = @_;

    my $outhandle = $self->{'outhandle'};

    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file_for_metadata($filename_full_path);

    $file =~ s/^[\/\\]+//; # $file often begins with / so we'll tidy it up
    
    print $outhandle "LOMPlugin: extracting metadata from $file\n"
	if $self->{'verbosity'} > 1;

    my ($dir,$tail) = $filename_full_path =~ /^(.*?)([^\/\\]*)$/;
    $self->{'output_dir'} = $dir;

    eval {
	$self->{'parser'}->parsefile($filename_full_path);
    };
    
    if ($@) {
	print $outhandle "LOMPlugin: skipping $filename_full_path as not conformant to LOM syntax\n" if ($self->{'verbosity'} > 1);
	print $outhandle "\n Perl Error:\n $@\n" if ($self->{'verbosity'}>2);
	return 0;
    }

    $self->{'output_dir'} = undef;

    my $file_re;
    my $lom_srcdoc = $self->{'lom_srcdoc'};

    if (defined $lom_srcdoc) {
	my $dirsep = &util::get_re_dirsep();
	$lom_srcdoc =~ s/^$base_dir($dirsep)//;
	$self->{'extra_blocks'}->{$file}++;
	$file_re = $lom_srcdoc;
    }
    else {
	$file_re = $tail;
    }
	
	# Indexing into the extrameta data structures requires the filename's style of slashes to be in URL format
	# Then need to convert the filename to a regex, no longer to protect windows directory chars \, but for
	# protecting special characters like brackets in the filepath such as "C:\Program Files (x86)\Greenstone".
	$file_re = &util::filepath_to_url_format($file_re);
    $file_re = &util::filename_to_regex($file_re);
    $self->{'lom_srcdoc'} = undef; # reset for next file to be processed

    &extrametautil::addmetakey($extrametakeys, $file_re);
    &extrametautil::setmetadata($extrametadata, $file_re, $self->{'saved_metadata'});
    if (defined $lom_srcdoc) {
	# copied from oaiplugin
	if (!defined &extrametautil::getmetafile($extrametafile, $file_re)) {
		&extrametautil::setmetafile($extrametafile, $file_re, {});
	}
	 #maps the file to full path
	&extrametautil::setmetafile_for_named_file($extrametafile, $file_re, $file, $filename_full_path);
    }
	
    return 1;
}

sub check_doctype {
    $self = shift (@_);
    
    my ($filename) = @_;
    
    if (open(XMLIN,"<$filename")) {
	my $doctype = $self->{'root_tag'};
	## check whether the doctype has the same name as the root element tag
	while (defined (my $line = <XMLIN>)) {
	    ## find the root element
	    if ($line =~ /<([\w\d:]+)[\s>]/){
		my $root = $1;
		if ($root !~ $doctype){
		    close(XMLIN);
		    return 0;
		}
		else {
		    close(XMLIN); 
		    return 1;
		}
	    }
	}
	close(XMLIN);
    }
    
    return undef; # haven't found a valid line
    
}

sub read_file {
    my $self = shift (@_);
    my ($filename, $encoding, $language, $textref) = @_;

    my $metadata_table = $self->{'metadata_table'};

    my $rawtext = $metadata_table->{'rawtext'};

    delete $metadata_table->{'rawtext'};

    $$textref = $rawtext;
}

sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    my $outhandle = $self->{'outhandle'};

    return 0 if (defined $self->{'extra_blocks'}->{$file});

    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);

    $self->{'metadata_table'} = $metadata;

    my $lom_language = $metadata->{'lom_language'};

    my $store_input_encoding;
    my $store_extract_language;
    my $store_default_language;
    my $store_default_encoding;

    if (defined $lom_language) {
	delete $metadata->{'lom_language'};

	$store_input_encoding   = $self->{'input_encoding'};
	$store_extract_language = $self->{'extract_language'};
	$store_default_language = $self->{'default_language'};
	$store_default_encoding = $self->{'default_encoding'};

	$self->{'input_encoding'}   = "utf8";
	$self->{'extract_language'} = 0;
	$self->{'default_language'} = $lom_language;
	$self->{'default_encoding'} = "utf8";
    }

    my $rv = $self->SUPER::read(@_);

    if (defined $lom_language) {	
	$self->{'input_encoding'}   = $store_input_encoding;
	$self->{'extract_language'} = $store_extract_language;
	$self->{'default_language'} = $store_default_language;
	$self->{'default_encoding'} = $store_default_encoding;
    }

    $self->{'metadata_table'} = undef;

    return $rv;
}

# do plugin specific processing of doc_obj
sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    my $cursection = $doc_obj->get_top_section();
    $doc_obj->add_utf8_text($cursection, $$textref);

    return 1;
}

sub Doctype {
    my ($expat, $name, $sysid, $pubid, $internal) = @_;

    my $root_tag = $self->{'root_tag'};

    if ($name !~ /$root_tag/) {	
	die "Root tag $name does not match regular expression $root_tag";
    }
}

sub StartTag {
    my ($expat, $element) = @_;

    my %attr = %_;
    
    my $raw_tag = "&lt;$element";
    map { $raw_tag .= " $_=\"$attr{$_}\""; } keys %attr;
    $raw_tag .= "&gt;";

    if ($element =~ m/$self->{'root_tag'}/) {
	$self->{'raw_text'} = $raw_tag;

	$self->{'saved_metadata'} = {};
	$self->{'metaname_stack'} = [];
	$self->{'lom_datatype'} = "";
	$self->{'lom_language'} = undef;
	$self->{'metadatatext'} = "<table class=\"metadata\" width=\"_pagewidth_\" >\n";
    }
    else {
	my $xml_depth = scalar(@{$self->{'metaname_stack'}});
	$self->{'raw_text'} .= "\n"; 
	$self->{'raw_text'} .= "&nbsp;&nbsp;" x $xml_depth; 
	$self->{'raw_text'} .= $raw_tag;

	my $metaname_stack = $self->{'metaname_stack'};
	push(@$metaname_stack,$element);
	if (scalar(@$metaname_stack)==1) {
	    # top level LOM category
	    my $style = "class=\"metadata\"";
	    my $open_close
		= "<a id=\"${element}opencloselink\" href=\"javascript:hideTBodyArea('$element')\">\n";
	    $open_close
		.= "<img id=\"${element}openclose\" border=\"0\" src=\"_httpopenmdicon_\"></a>\n";

	    my $header_line = "  <tr $style ><th $style colspan=\"3\">$open_close \u$element</th></tr>\n";
	    my $md_tbody = "<tbody id=\"$element\">\n";

	    $self->{'mdheader'}     = $header_line;
	    $self->{'mdtbody'}      = $md_tbody;
	    $self->{'mdtbody_text'} = "";
	}
    }
}

sub EndTag {
    my ($expat, $element) = @_;

    my $raw_tag = "&lt;/$element&gt;";
    
    if ($element =~ m/$self->{'root_tag'}/) {
	$self->{'raw_text'} .= $raw_tag;

	my $metadatatext = $self->{'metadatatext'};
	$metadatatext .= "</table>";

	my $raw_text = $self->{'raw_text'};

	$self->{'saved_metadata'}->{'MetadataTable'} =  $metadatatext;
	$self->{'metadatatext'} = "";

	$self->{'saved_metadata'}->{'rawtext'} =  $raw_text;
	$self->{'raw_text'} = "";

	if (defined $self->{'lom_language'}) {
	    $self->{'saved_metadata'}->{'lom_language'} = $self->{'lom_language'};
	    $self->{'lom_language'} = undef;
	}
    }
    else {
	my $metaname_stack = $self->{'metaname_stack'};

	if (scalar(@$metaname_stack)==1) {
	    my $header_line = $self->{'mdheader'};
	    my $tbody_start = $self->{'mdtbody'};
	    my $tbody_text  = $self->{'mdtbody_text'};
	    if ($tbody_text !~ m/^\s*$/s) {
		my $tbody_end = "</tbody>\n";
		my $table_chunk 
		    = $header_line.$tbody_start.$tbody_text.$tbody_end;

		$self->{'metadatatext'} .= $table_chunk;
	    }
	    $self->{'mdtheader'}    = "";
	    $self->{'mdtbody'}      = "";
	    $self->{'mdtbody_text'} = "";
	}

	pop(@$metaname_stack);

	my $xml_depth = scalar(@{$self->{'metaname_stack'}});
	$self->{'raw_text'} .= "\n"; 
	$self->{'raw_text'} .= "&nbsp;&nbsp;" x $xml_depth; 
	$self->{'raw_text'} .= $raw_tag;
    }
}

sub process_datatype_info
{
    my $self = shift(@_);
    my ($metaname_stack,$md_content) = @_;

    my @without_dt_stack = @$metaname_stack; # without datatype stack

    my $innermost_element = $without_dt_stack[$#without_dt_stack];

    # Loose last item if encoding datatype information
    if ($innermost_element =~ m/^(lang)?string$/) {
	$self->{'lom_datatype'} = $innermost_element;

	pop @without_dt_stack;
	$innermost_element = $without_dt_stack[$#without_dt_stack];
    }
    elsif ($innermost_element =~ m/^date(Time)?$/i) { 
	if ($innermost_element =~ m/^date$/i) {
	    $self->{'lom_datatype'} = "dateTime";
	}
	else {
	    $self->{'lom_datatype'} = $innermost_element;

	    pop @without_dt_stack;
	    $innermost_element = $without_dt_stack[$#without_dt_stack];
	}

	if ($md_content =~ m/^(\d{1,2})\s*(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s*(\d{4})/i) {
	    my ($day,$mon,$year) = ($1,$2,$3);
	    
	    my %month_lookup = ( 'jan' =>  1, 'feb' =>  2, 'mar' =>  3,
				 'apr' =>  4, 'may' =>  5, 'jun' =>  6,
				 'jul' =>  7, 'aug' =>  8, 'sep' =>  9,
				 'oct' => 10, 'nov' => 11, 'dec' => 12 );

	    my $mon_num = $month_lookup{lc($mon)};

	    $md_content = sprintf("%d%02d%02d",$year,$mon_num,$day);
	}

	$md_content =~ s/\-//g;
    }

    if ($innermost_element eq "source") {
	$self->{'lom_source'} = $md_content;
    }
    elsif ($innermost_element eq "value") {
	$self->{'lom_value'} = $md_content;
    }

    return (\@without_dt_stack,$innermost_element,$md_content);
}

sub reset_datatype_info
{
    my $self = shift(@_);

    $self->{'lom_datatype'} = "";
}


sub pretty_print_text
{
    my $self = shift(@_);
    
    my ($pretty_print_text) = @_;

##    $metavalue_utf8 = &util::hyperlink_text($metavalue_utf8);
    $pretty_print_text = &util::hyperlink_text($pretty_print_text);
	
####    $pretty_print_text =~ s/(BEGIN:vCard.*END:vCard)/<pre>$1<\/pre>/sg;

    if ($self->{'lom_datatype'} eq "dateTime") {
	if ($pretty_print_text =~ m/^(\d{4})(\d{2})(\d{2})$/) {
	    $pretty_print_text = "$1-$2-$3";
	}
    }

    return $pretty_print_text;
}

sub pretty_print_table_tr
{
    my $self = shift (@_);
    my ($without_dt_stack) = @_;

    my $style = "class=\"metadata\"";

    my $innermost_element = $without_dt_stack->[scalar(@$without_dt_stack)-1];
    my $outermost_element = $without_dt_stack->[0];

    # Loose top level stack item (already named in pretty print table)
    my @pretty_print_stack = @$without_dt_stack;
    shift @pretty_print_stack; 

    if ($innermost_element eq "source") {
	return if (!defined $self->{'lom_value'});
    }

    if ($innermost_element eq "value") {
	return if (!defined $self->{'lom_source'});
    }

    my $pretty_print_text = "";

    if (($innermost_element eq "value") || ($innermost_element eq "source")) {
	my $source = $self->{'lom_source'};
	my $value  = $self->pretty_print_text($self->{'lom_value'});

	$self->{'lom_source'} = undef;
	$self->{'lom_value'} = undef;

	pop @pretty_print_stack;
	
	$pretty_print_text = "<td $style>$source</td><td $style>$value</td>";
    }
    else {
	$pretty_print_text = $self->pretty_print_text($_);
	$pretty_print_text = "<td $style colspan=2>$pretty_print_text</td>";
    }
    my $pretty_print_fmn = join(' : ',map { "\u$_"; } @pretty_print_stack);


    # my $tr_attr = "id=\"$outermost_element\" style=\"display:block;\"";
    my $tr_attr = "$style id=\"$outermost_element\"";

    my $mdtext_line = "  <tr $tr_attr><td $style><nobr>$pretty_print_fmn</nobr></td>$pretty_print_text</tr>\n";
    $self->{'mdtbody_text'} .= $mdtext_line;
}


sub check_for_language
{
    my $self = shift(@_);
    my ($innermost_element,$md_content) = @_;

    # Look for 'language' tag
    if ($innermost_element eq "language") {
	my $lom_lang = $self->{'lom_language'};
	
	if (defined $lom_lang) {
	    my $new_lom_lang = $md_content;
	    $new_lom_lang =~ s/-.*//; # remove endings like -US or -GB

	    if ($lom_lang ne $new_lom_lang) {
		my $outhandle = $self->{'outhandle'};
		
		print $outhandle "Warning: Conflicting general language in record\n";
		print $outhandle "         $new_lom_lang (previous value for language = $lom_lang)\n";
	    }
	    # otherwise, existing value OK => do nothing
	}
	else {
	    $lom_lang = $md_content;
	    $lom_lang =~ s/-.*//; # remove endings like -US or -GB
	    
	    $self->{'lom_language'} = $lom_lang;
	}
    }
}

sub found_specific_identifier
{
    my $self = shift(@_);
    my ($specific_id,$full_mname,$md_content) = @_;

    my $found_id = 0;
    if ($full_mname eq $specific_id) {
	if ($md_content =~ m/^(http|ftp):/) {
	    $found_id = 1;
	}
    }

    return $found_id;
}

sub download_srcdoc
{
    my $self = shift(@_);
    my ($doc_url) = @_;

    my $outhandle  = $self->{'outhandle'};
    my $output_dir = $self->{'output_dir'};

    $output_dir = &FileUtils::filenameConcatenate($output_dir,"_gsdldown.all");

    if (! -d $output_dir) {
	mkdir $output_dir;
    }

    my $re_dirsep = &util::get_re_dirsep();
    my $os_dirsep = &util::get_dirsep();

    my $file_url = $doc_url;
    $file_url =~ s/$re_dirsep/$os_dirsep/g;
    $file_url =~ s/^(http|ftp):\/\///;
    $file_url .= "index.html" if ($file_url =~ m/\/$/);

    my $full_file_url = &FileUtils::filenameConcatenate($output_dir,$file_url);
    # the path to srcdoc will be used later in extrametadata to associate
    # the lom metadata with the document. Needs to be relative to current
    # directory.
    my $srcdoc_path = &FileUtils::filenameConcatenate("_gsdldown.all", $file_url);
    my $check_timestamp = $self->{'check_timestamp'};
    my $status;

    if (($check_timestamp) || (!$check_timestamp && !-e $full_file_url)) {
	if (!-e $full_file_url) {
	    print $outhandle "Mirroring $doc_url\n";
	}
	else {
	    print $outhandle "Checking to see if update needed for $doc_url\n";
	}

	# on linux, if we pass an absolute path as -P arg to wget, then it 
	# stuffs up the 
	# URL rewriting in the file. Need a relative path or none, so now
	# we change working directory first.
	my $changed_dir = 0;
	my $current_dir = cwd();
	my $wget_cmd = "";
	if ($ENV{'GSDLOS'} ne "windows") {
	    $changed_dir = 1;
	    
	    chdir "$output_dir";
	    $wget_cmd = "wget -nv  --timestamping -k -p \"$doc_url\"";
	} else {
	    $wget_cmd = "wget -nv -P \"$output_dir\" --timestamping -k -p \"$doc_url\""; 
	}
	##print STDERR "**** wget = $wget_cmd\n";
	
	# the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
	&util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set
	
	$status = system($wget_cmd);
	if ($changed_dir) {
	    chdir $current_dir;
	}
	if ($status==0) {
	    $self->{'lom_srcdoc'} = $srcdoc_path; 	
	}
	else {
	    $self->{'lom_srcdoc'} = undef;
	    print $outhandle "Error: failed to execute $wget_cmd\n";
	}
    }
    else {
	# not time-stamping and file already exists
	$status=0;
	$self->{'lom_srcdoc'} = $srcdoc_path; 	
    }

    return $status==0;
    
}


sub check_for_identifier
{
    my $self = shift(@_);
    my ($full_mname,$md_content) = @_;

    my $success = 0;

    my $download_re = $self->{'download_srcdocs'};
    if (($download_re ne "") && $md_content =~ m/$download_re/) {
	
	if ($self->found_specific_identifier("general^identifier^entry",$full_mname,$md_content)) {
	    $success = $self->download_srcdoc($md_content);
	}

	if (!$success) {
	    if ($self->found_specific_identifier("technical^location",$full_mname,$md_content)) {
		$success = $self->download_srcdoc($md_content);
	    }
	}
    }

    return $success;
}


sub Text {
    if ($_ !~ m/^\s*$/) {
	#
	# Work out indentations and line wraps for raw XML
	#
	my $xml_depth = scalar(@{$self->{'metaname_stack'}})+1;
	my $indent = "&nbsp;&nbsp;" x $xml_depth; 
	
	my $formatted_text = "\n".$_;

	# break into lines < 80 chars on space
	$formatted_text =~ s/(.{50,80})\s+/$1\n/mg; 
	$formatted_text =~ s/^/$indent/mg;
	## $formatted_text =~ s/\s+$//s;

	$self->{'raw_text'} .= $formatted_text;
    }

    my $metaname_stack = $self->{'metaname_stack'};
    if (($_ !~ /^\s*$/) && (scalar(@$metaname_stack)>0)) {

	my ($without_dt_stack,$innermost_element,$md_content)
	    = $self->process_datatype_info($metaname_stack,$_);

	$self->pretty_print_table_tr($without_dt_stack);

	my $full_mname = join('^',@{$without_dt_stack});
	$self->set_filere_metadata(lc($full_mname),$md_content);

	$self->check_for_language($innermost_element,$md_content);
	$self->check_for_identifier($full_mname,$md_content); # source doc

	$self->reset_datatype_info();
    }
}

# This Char function overrides the one in XML::Parser::Stream to overcome a
# problem where $expat->{Text} is treated as the return value, slowing
# things down significantly in some cases.
sub Char {
  $_[0]->{'Text'} .= $_[1];
  return undef;
}

1;
