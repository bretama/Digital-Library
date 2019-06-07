###########################################################################
#
# TextPlugin.pm -- simple text plugin
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

# creates simple single-level document. Adds Title metadata 
# of first line of text (up to 100 characters long).

package TextPlugin;

use ReadTextFile;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
no strict 'subs';

sub BEGIN {
    @TextPlugin::ISA = ('ReadTextFile');
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" } ,
      { 'name' => "title_sub",
	'desc' => "{TextPlugin.title_sub}",
	'type' => "regexp",
	'deft' => "",
	'reqd' => "no" } ];

my $options = { 'name'     => "TextPlugin",
		'desc'     => "{TextPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'srcreplaceable' => "yes", # Source docs in regular txt format can be replaced with GS-generated html
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new ReadTextFile($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)\.te?xt$^;
}

# do plugin specific processing of doc_obj
sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};
    
    my $cursection = $doc_obj->get_top_section();
    # get title metadata
    # (don't need to get title if it has been passed
    # in from another plugin)
    if (!defined $metadata->{'Title'}) {
	my $title = $self->get_title_metadata($textref);
	$doc_obj->add_utf8_metadata ($cursection, "Title", $title);
    }
    # Add FileFormat metadata
    $doc_obj->add_metadata($cursection, "FileFormat", "Text");

    # insert preformat tags and add text to document object    
    $self->text_to_html($textref); # modifies the text
    $doc_obj->add_utf8_text($cursection, $$textref);

    return 1;
}

sub get_title_metadata {
    my $self = shift (@_);
    my ($textref) = @_;
    
    my ($title) = $$textref;
    $title =~ /^\s+/s;
    if (defined $self->{'title_sub'} && $self->{'title_sub'}) {
	$title =~ s/$self->{'title_sub'}//;
    }
    $title =~ /^\s*([^\n]*)/s; $title=$1;
    $title =~ s/\t/ /g;
    $title =~ s/\r?\n?$//s; # remove any carriage returns and/or line feeds at line end, 
       # else the metadata won't appear in GLI even though it will appear in doc.xml
    if (length($title) > 100) {
	$title = substr ($title, 0, 100) . "...";
    }
    $title =~ s/\[/&\#91;/g;
    $title =~ s/\[/&\#93;/g;
    $title =~ s/\</&\#60;/g;
    $title =~ s/\>/&\#62;/g;
    
    return $title;
}

sub text_to_html {
    my $self = shift (@_);
    my ($textref) = @_;
    
    # we need to escape the escape character, or else mg will convert into
    # eg literal newlines, instead of leaving the text as '\n'
    $$textref =~ s/\\/\\\\/g; # macro language
    $$textref =~ s/_/\\_/g; # macro language
    $$textref =~ s/</&lt;/g;
    $$textref =~ s/>/&gt;/g;
    
    # insert preformat tags and add text to document object
    $$textref = "<pre>\n$$textref\n</pre>";
}


# replace_srcdoc_with_html.pl requires all subroutines that support src_replaceable
# to contain a method called tmp_area_convert_file - this is indeed the case with all
# Perl modules that are subclasses of ConvertToPlug.pm, but as we want TextPlugin to also
# be srcreplaceable and because TextPlugin does not inherit from ConvertToPlug.pm, we have
# a similar subroutine with the same name here.
sub tmp_area_convert_file {
    my $self = shift (@_);
    my ($output_ext, $input_filename) = @_;
    
    my $outhandle = $self->{'outhandle'};
    #my $failhandle = $self->{'failhandle'};
    
    # derive output filename from input filename
    my ($tailname, $dirname, $suffix)
	= &File::Basename::fileparse($input_filename, "\\.[^\\.]+\$");

    # Softlink to collection tmp dir
    # First find a temporary directory to create the output file in
    my $tmp_dirname = $dirname;
    if(defined $ENV{'GSDLCOLLECTDIR'}) {
	$tmp_dirname = $ENV{'GSDLCOLLECTDIR'};
    } elsif(defined $ENV{'GSDLHOME'}) {
	$tmp_dirname = $ENV{'GSDLHOME'};
    }
    $tmp_dirname = &FileUtils::filenameConcatenate($tmp_dirname, "tmp");
    &FileUtils::makeDirectory($tmp_dirname) if (!-e $tmp_dirname);

    # convert to utf-8 otherwise we have problems with the doc.xml file
    # later on
    $tailname = $self->SUPER::filepath_to_utf8($tailname) unless &unicode::check_is_utf8($tailname);

    $suffix = lc($suffix);
    my $tmp_filename = &FileUtils::filenameConcatenate($tmp_dirname, "$tailname$suffix"); 
    
    # Make sure we have the absolute path to the input file
    # (If gsdl is remote, we're given relative path to input file, of the form import/tailname.suffix
    # But we can't softlink to relative paths. Therefore, we need to ensure that
    # the input_filename is the absolute path.
    my $ensure_path_absolute = 1; # true

    # Now make the softlink,  so we don't accidentally damage the input file
    # softlinking creates a symbolic link to (or, if that's not possible, it makes a copy of) the original
    &FileUtils::softLink($input_filename, $tmp_filename, $ensure_path_absolute);
     
    my $verbosity = $self->{'verbosity'};
    if ($verbosity > 0) {
	# need this output statement, as GShell.java's runRemote() sets status to CANCELLED
	# if there is no output! (Therefore, it only had this adverse affect when running GSDL remotely)
	print $outhandle "Converting $tailname$suffix to html\n";
    }

    #my $output_filename = $tailname$output_ext; #output_ext has to be html!
    my $output_filename = &FileUtils::filenameConcatenate($tmp_dirname, $tailname.".html");
    
    # Read contents of text file line by line into an array
    # create an HTML file from the text file
    # Recreate the original file for writing the updated contents
    unless(open(TEXT, "<$tmp_filename")) { # open it as a new file for writing
	print STDERR "TextPlugin.pm: Unable to open and read from $tmp_filename for converting to html...ERROR: $!\n";
	return ""; # no file name
    }

    # Read the entire file at once
    my $text;
    { 
	local $/ = undef; # Now can read the entire file at once. From http://perl.plover.com/local.html
	$text = <TEXT>;   # File is read in as one single 'line'
    }
    close(TEXT); # close the file

    # Get the title before embedding the text in pre tags
    my $title = $self->get_title_metadata(\$text);   

    # Now convert the text 
    $self->text_to_html(\$text);
    
    # try creating this new file writing and try opening it for writing, else exit with error value
    unless(open(HTML, ">$output_filename")) {  # open the new html file for writing
	print STDERR "TextPlugin.pm: Unable to create $output_filename for writing $tailname$suffix txt converted to html...ERROR: $!\n";
	return ""; # no filename
    }
    # write the html contents of the text (which is embedded in <pre> tags) out to the file with proper enclosing tags
    print HTML "<html>\n<head>\n<title>$title</title>\n</head>\n<body>\n";
    print HTML $text;
    print HTML "\n</body>\n</html>";
    close HTML;

    # remove the copy of the original file/remove the symbolic link to original file
    &FileUtils::removeFiles($tmp_filename);

    return $output_filename; # return the output file path
}


1;
