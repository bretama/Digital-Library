###########################################################################
#
# SourceCodePlugin.pm -- source code plugin
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
# John McPherson Nov 2000
# originally based on TEXTPlug

# filename is currently used for Title ( optionally minus some prefix )

# Current languages:
#   text: READMEs/Makefiles
#   C/C++   (currently extracts #include statements and C++ class decls)
#   Perl    (currently only done as text)
#   Shell   (currently only done as text)

package SourceCodePlugin;

use ReadTextFile;
use MetadataRead;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @SourceCodePlugin::ISA = ('MetadataRead', 'ReadTextFile');
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" } ,
      { 'name' => "block_exp",
	'desc' => "{CommonUtil.block_exp}",
	'type' => "regexp",
	'deft' => &get_default_block_exp(),
	'reqd' => "no" },
      { 'name' => "remove_prefix",
	'desc' => "{SourceCodePlugin.remove_prefix}",
	'type' => "regexp",
	'deft' => "^.*[/\\]",
	'reqd' => "no" } ];

my $options = { 'name'     => "SourceCodePlugin",
		'desc'     => "{SourceCodePlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
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

sub get_default_block_exp {
    my $self = shift (@_);

    return q^(?i)\.(o|obj|a|so|dll)$^;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(Makefile.*|README.*|(?i)\.(c|cc|cpp|C|h|hpp|pl|pm|sh))$^;
}



# do plugin specific processing of doc_obj
sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};
    
    my $cursection = $doc_obj->get_top_section();

    my $filetype="text";  # Makefiles, READMEs, ...
    if ($file =~ /\.(cc|h|cpp|C)$/) {$filetype="C++";} # assume all .h files...
    elsif ($file =~ /\.c$/)         {$filetype="C";}
    elsif ($file =~ /\.p(l|m)$/)    {$filetype="perl";}
    elsif ($file =~ /\.sh$/)        {$filetype="sh";}

    # modify '<' and '>' for GML... (even though inside <pre> tags!!)
    $$textref =~ s/</&lt;/g;
    $$textref =~ s/>/&gt;/g;
    $$textref =~ s/_/&#95;/g;
    # try _escape_text($text) from doc.pm....

    # don't want mg to turn escape chars into actual values
    $$textref =~ s/\\/\\\\/g;

    # use filename (minus any prefix) as the title.
    my $title;
    if ($self->{'remove_prefix' ne ""}) {
	($title = $file) =~ s/^$self->{'remove_prefix'}//;
    } else {
	($title = $file) =~ s@^.*[/\\]@@; # remove pathname by default
    }
    $doc_obj->add_utf8_metadata ($cursection, "Title", $title);
    $doc_obj->add_metadata ($cursection, "FileFormat", "SRC");

    # remove the gsdl prefix from the filename
    my $relative_filename=$file;
    $relative_filename =~ s@^.*?gsdl[/\\]@@;
    $doc_obj->add_utf8_metadata ($cursection, "filename", $relative_filename);

    # class information from .h and .cc and .C and .cpp files
    if ($filetype eq "C++") 
    {
	process_c_plus_plus($textref,$pluginfo, $base_dir, 
				   $file, $metadata, $doc_obj);
    } elsif ($filetype eq "C")
    {
	get_includes_metadata($textref, $doc_obj);
    }


     # default operation...
     # insert preformat tags and add text to document object
    $doc_obj->add_utf8_text($cursection, "<pre>\n$$textref\n</pre>");
    
    return 1;
}




sub get_includes_metadata {
    my ($textref, $doc_obj) = @_;
    
    my $topsection = $doc_obj->get_top_section();

    # Get '#include' directives for metadata
    if ($$textref !~ /\#\s*include\b/) {
	return;
    }

    my @includes =
	($$textref =~ m/^\s*\#\s*include\s*(?:\"|&lt;)(.*?)(?:\"|&gt;)/mg);
    
    my $incs_done_ref=$doc_obj->get_metadata($topsection, "includes");
    my @incs_done;
    if (defined($incs_done_ref)) {
	@incs_done=@$incs_done_ref;
    } else {
	@incs_done=();
    }

    foreach my $inc (@includes) {
	# add entries, but only if they don't already exist
	if (!join('', map {$_ eq "$inc"?1:""} @incs_done)) {
	    push @incs_done, $inc;
	    $doc_obj->add_utf8_metadata($topsection, "includes", $inc);
	}
    }
}



sub process_c_plus_plus {
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj) = @_;

    my $topsection = $doc_obj->get_top_section();


    # Check for include metadata
    get_includes_metadata($textref, $doc_obj);



    # Get class declarations (but not forward declarations...) as metadata
    if ($$textref =~ /\bclass\b/ ) {
	my $classnames=$$textref;
	
	# remove commented lines
	$classnames =~ s@/\*.*?\*/@@sg;
	$classnames =~ s@//.*$@@mg;
	while ($classnames =~ /\bclass\b/) {

	    # delete all lines up to the next "class"
	    while ($classnames !~ /^[^\n]*\bclass\b[^\n]*\n/)
	    {$classnames =~ s/.*\n//;}
	    
#	    $classnames =~ s/^([^c][^l])*(.)?$//mg; # delete unneccessary lines

	    # get the line including the next "class" and remove it from
	    # our tmp text.
	    $classnames =~ s/^(.*\bclass\b.*)$//m;

	    # don't index if merely a reference/fwd decl. of another class
	    if ($1 !~ /(friend\Wclass)|(class\W\w+\W?\;)|(\/\/.*class)/) {
		# $1 is still the whole line - eg:
		# "class StaffSystem: public BaseStaffSystem"
		my $wholeline=$1;
		my $classname=$1;
		$classname =~ s/.*class\W(\w+).*/$1/;
		my $classes=$doc_obj->get_metadata($topsection, "class");
		foreach my $elem (@$classes) {
		    if ("$elem" eq "$classname") {goto class_done;}
		}
		$doc_obj->add_utf8_metadata($topsection, "class", $classname);
	      class_done:
		$doc_obj->add_utf8_metadata($topsection, "classdecl", $wholeline);
	    }
	}
    } # end of "class"

    return 1;
}

1;

