###########################################################################
#
# PostScriptPlugin.pm -- plugin to process PostScript files
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

package PostScriptPlugin;

use ConvertBinaryFile;
use ReadTextFile; # for read_file in convert_post_process. do we need it?
use sorttools;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @PostScriptPlugin::ISA = ('ConvertBinaryFile', 'ReadTextFile');
}

my $convert_to_list =
    [ {	'name' => "auto",
	'desc' => "{ConvertBinaryFile.convert_to.auto}" },
      {	'name' => "text",
	'desc' => "{ConvertBinaryFile.convert_to.text}" },
      { 'name' => "pagedimg_jpg",
	'desc' => "{ConvertBinaryFile.convert_to.pagedimg_jpg}" },
      { 'name' => "pagedimg_gif",
	'desc' => "{ConvertBinaryFile.convert_to.pagedimg_gif}" },
      { 'name' => "pagedimg_png",
	'desc' => "{ConvertBinaryFile.convert_to.pagedimg_png}" }
      ];

my $arguments =
    [ { 'name' => "convert_to",
	'desc' => "{ConvertBinaryFile.convert_to}",
	'type' => "enum",
	'reqd' => "yes",
	'list' => $convert_to_list, 
	'deft' => "text" },
      { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      { 'name' => "block_exp",
	'desc' => "{CommonUtil.block_exp}",
	'type' => 'regexp',
	'deft' => &get_default_block_exp() },
      { 'name' => "extract_date",
	'desc' => "{PostScriptPlugin.extract_date}",
	'type' => "flag" },
      { 'name' => "extract_pages",
	'desc' => "{PostScriptPlugin.extract_pages}",
	'type' => "flag" },
      { 'name' => "extract_title",
	'desc' => "{PostScriptPlugin.extract_title}",
	'type' => "flag" } ];

my $options = { 'name'     => "PostScriptPlugin",
		'desc'     => "{PostScriptPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'srcreplaceable' => "yes", # Source docs in postscript format can be replaced with GS-generated html
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@$inputargs,"-title_sub");
    push(@$inputargs,'^(Page\s+\d+)?(\s*1\s+)?');
    
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
    
    my $self = new ConvertBinaryFile($pluginlist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    $self->{'file_type'} = "PS";

    if ($self->{'convert_to'} eq "auto") {
	$self->{'convert_to'} = "text";
    }

    # set convert_to_plugin and convert_to_ext
    $self->set_standard_convert_settings();
    my $secondary_plugin_name = $self->{'convert_to_plugin'};
    my $secondary_plugin_options = $self->{'secondary_plugin_options'};

    if (!defined $secondary_plugin_options->{$secondary_plugin_name}) {
	$secondary_plugin_options->{$secondary_plugin_name} = [];
    }
    my $specific_options = $secondary_plugin_options->{$secondary_plugin_name};

    # following title_sub removes "Page 1" added by ps2ascii, and a leading
    # "1", which is often the page number at the top of the page. Bad Luck
    # if your document title actually starts with "1 " - is there a better way?
    push(@$specific_options, "-title_sub", '^(Page\s+\d+)?(\s*1\s+)?');
    push(@$specific_options, "-file_rename_method", "none");
    
    if ($secondary_plugin_name eq "TextPlugin") {
	push(@$specific_options, "-input_encoding", "utf8");
	push(@$specific_options,"-extract_language") if $self->{'extract_language'};
    } elsif ($secondary_plugin_name eq "PagedImagePlugin") {
	push(@$specific_options, "-processing_tmp_files");
    }

    $self = bless $self, $class;
    # used for convert_post_process
    $self->{'input_encoding'} = "auto";
    $self->{'default_encoding'} = "utf8";

    $self->load_secondary_plugins($class,$secondary_plugin_options, $hashArgOptLists);

    return $self;
}


sub get_default_block_exp {
    my $self = shift (@_);

    return q^(?i)\.(eps)$^;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)\.ps$^;
}

# this has been commented out in other plugins. do we need it here?
# ps files are converted to images (item file should be in utf8) or text (uses pstoascii), so we shouldn't need to ensure utf8
sub convert_post_process
{
    my $self = shift (@_);
    my ($conv_filename) = @_;
    
    my $outhandle=$self->{'outhandle'};
    
    my ($language, $encoding) = $self->textcat_get_language_encoding ($conv_filename);
    
    # read in file ($text will be in utf8)
    my $text = "";
    $self->read_file ($conv_filename, $encoding, $language, \$text);
    
    # turn any high bytes that aren't valid utf-8 into utf-8.
    unicode::ensure_utf8(\$text);
    
    # Write it out again!
    $self->utf8_write_file (\$text, $conv_filename);
}

sub extract_metadata_from_postscript {
    my $self = shift (@_);

    my ($filename,$doc) = @_;

    my $section = $doc->get_top_section();

    my $title_found = 0;
    my $pages_found = 0;
    my $date_found = 0;

    print STDERR "PostScriptPlugin: extracting PostScript metadata from \"$filename\"\n" 
	if $self->{'verbosity'} > 1;

    open(INPUT, "<$filename");
    my $date;

    while(my $line =<INPUT>) {
	if ($self->{'extract_title'} && !$title_found) {
	    foreach my $word ($line =~ m|Title: ([-A-Za-z0-9@/\/\(\):,. ]*)|g) {
		my $new_word = $word; 
		$new_word =~ s/\(Untitled\)//i;
		$new_word =~ s/\(Microsoft Word\)//i;
		$new_word =~ s/Microsoft Word//i;
		$new_word =~ s/^\(//i;
		$new_word =~ s/\)$//i;
		$new_word =~ s/^ - //i;
		if ($new_word ne "") {
		    $doc->add_utf8_metadata($section, "Title", $new_word );
		    $title_found = 1;
		}
	    }
	}
	if ($self->{'extract_date'} && !$date_found) {
            foreach my $word ($line =~ m/(Creation[-A-Za-z0-9@\/\(\):,. ]*)/g) {
                if ($word =~ m/ ([A-Za-z][A-Za-z][A-Za-z]) ([0-9 ][0-9])  ?[0-9: ]+ ([0-9]{4})/) {
                    $date = &sorttools::format_date($2,$1,$3);
		    if (defined $date) {
			$doc->add_utf8_metadata($section, "Date", $date );
		    }
                }
                if ($word =~ m/D:([0-9]{4})([0-9]{2})([0-9]{2})[0-9]{6}\)/) {
                    $date = &sorttools::format_date($3,$2,$1);
		    if (defined $date) {
			$doc->add_utf8_metadata($section, "Date", $date );
		    }
                }
                if ($word =~ m/CreationDate: ([0-9]{4}) ([A-Za-z][A-Za-z][A-Za-z]) ([0-9 ][0-9]) [0-9:]*/) {
                    $date = &sorttools::format_date($3,$2,$1);
		    if (defined $date) {
			$doc->add_utf8_metadata($section, "Date", $date );
		    }
                }
		$date_found = 1;
            }
	}
	if ($self->{'extract_pages'} && !$pages_found) {
	    foreach my $word ($line =~ m/(Pages: [0-9]*)/g) {
                my $digits = $word;
                $digits =~ s/[^0-9]//g;
		if ($digits ne "" && $digits ne "0") {
		    $doc->add_utf8_metadata($section, "Pages", $digits );
		    $pages_found = 1;
		}
            }
	}
    }
}

# do plugin specific processing of doc_obj 
sub process {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    my $filename = &util::filename_cat($base_dir,$file);
    $self->extract_metadata_from_postscript($filename, $doc_obj);

    return $self->SUPER::process(@_);

}


1;

