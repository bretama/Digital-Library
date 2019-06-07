###########################################################################
#
# MP3Plugin.pm -- Plugin for MP3 files (MPEG audio layer 3).
#
# A component of the Greenstone digital library software from the New
# Zealand Digital Library Project at the University of Waikato, New
# Zealand.
#
# Copyright (C) 2001 New Zealand Digital Library Project
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###########################################################################


package MP3Plugin;

use BaseImporter;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
no strict 'subs';

use MP3::Info;

require giget;

sub BEGIN {
    @MP3Plugin::ISA = ('BaseImporter');
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      { 'name' => "assoc_images",
        'desc' => "{MP3Plugin.assoc_images}",
        'type' => "flag",
        'deft' => "",
        'reqd' => "no" },
      { 'name' => "applet_metadata",
	'desc' => "{MP3Plugin.applet_metadata}",
	'type' => "flag",
	'deft' => "" },
      { 'name' => "metadata_fields",
	'desc' => "{MP3Plugin.metadata_fields}",
	'type' => "string",
	'deft' => "Title,Artist,Genre" },
      { 'name' => "file_rename_method",
	'desc' => "{BaseImporter.file_rename_method}",
	'type' => "enum",
	'deft' => &get_default_file_rename_method(), # by default rename imported files and assoc files using this encoding
	'list' => $BaseImporter::file_rename_method_list,
	'reqd' => "no"
      } ];

my $options = { 'name'     => "MP3Plugin",
		'desc'     => "{MP3Plugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

sub get_default_process_exp {
    return q^(?i)\.mp3$^;
}

# rename imported files and assoc files using base64 encoding by default
# so that the urls generated will always work with media files even when
# opened in external applications (when wmv file names contain spaces in
# them and they get url-encoded, wmv player fails to open the doubly url-
# encoded url reference to the url-encoded filename). 
sub get_default_file_rename_method() {
    return "base64";
}

# we don't want to hash on the file
sub get_oid_hash_type {
    my $self = shift (@_);
    return "hash_on_ga_xml";
}

sub process {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);

    # associate the file with the document
    if ($self->associate_mp3_file($filename_full_path, $filename_no_path, $doc_obj) != 1)
    {
	print "MP3Plugin: couldn't process \"$filename_full_path\"\n";
	return 0;
    }
   
    my $text = &gsprintf::lookup_string("{BaseImporter.dummy_text}",1);
    if ($self->{'assoc_images'}) {
	$text .= "[img1]<br>";
	$text .= "[img2]<br>";
    }
    $doc_obj->add_utf8_text($doc_obj->get_top_section(), $text);
    $doc_obj->add_metadata ($doc_obj->get_top_section(), "NoText",    "1");

}

sub gen_mp3applet {

    my ($mp3_filename) = @_;

    my $applet_html = '
<OBJECT classid="clsid:8AD9C840-044E-11D1-B3E9-00805F499D93"
        WIDTH = "59"
        HEIGHT = "32"
        codebase="http://java.sun.com/products/plugin/1.3/jinstall-13-win32.cab#Version=1,3,0,0">
<PARAM NAME = CODE VALUE = "javazoom.jlGui.TinyPlayer" >
<PARAM NAME = ARCHIVE VALUE = "_httpcollection_/tinyplayer.jar,_httpcollection_/jl10.jar" >
<PARAM NAME="type" VALUE="application/x-java-applet;version=1.3">
<PARAM NAME="scriptable" VALUE="false">
<PARAM NAME = "skin" VALUE ="_httpcollection_/skins/Digitalized">
<PARAM NAME = "autoplay" VALUE ="yes">
<PARAM NAME = "bgcolor" VALUE ="638182">
<PARAM NAME = "audioURL" VALUE ="MP3FILENAME">
<COMMENT>
<EMBED type="application/x-java-applet;version=1.3"
       CODE = "javazoom.jlGui.TinyPlayer"
       ARCHIVE = "_httpcollection_/tinyplayer.jar,_httpcollection_/jl10.jar"
       WIDTH = "59"
       HEIGHT = "32"
       skin = "_httpcollection_/skins/Digitalized"
       autoplay = "yes"
       bgcolor = "638182"
       audioURL = "MP3FILENAME"
       scriptable=false
       pluginspage="http://java.sun.com/products/plugin/1.3/plugin-install.html">
<NOEMBED>
</COMMENT>
</NOEMBED></EMBED>
</OBJECT>
';

    $applet_html =~ s/MP3FILENAME/$mp3_filename/g;

    return $applet_html;
}



# Associate the mp3 file with the new document

sub associate_mp3_file {
    my $self = shift (@_);
    my $filename = shift (@_);   # filename with full path
    my $file = shift (@_);       # filename without path
    my $doc_obj = shift (@_);
    
    my $verbosity = $self->{'verbosity'};
    my $outhandle = $self->{'outhandle'};

    # check the filename is okay
    return 0 if ($file eq "" || $filename eq "");

    # Add the file metadata.
    # $assoc_url will be the srcurl. Since it is URL encoded here, it will be
    # able to cope with special characters--including spaces--in mp3 filenames.
    # the assocfilename generated will be a URL encoded version of the utf8 filename
    my $assoc_url = $doc_obj->get_sourcefile(); 
    my $dst_file = $doc_obj->get_assocfile_from_sourcefile();

    # Add the file as an associated file ...
    my $section = $doc_obj->get_top_section();
    my $mime_type = $self->{'mime_type'} || "audio/mp3";
    my $assoc_field = $self->{'assoc_field'} || "mp3";
    my $assoc_name = $file;
    $assoc_name =~ s/\.mp3$//;

    $doc_obj->associate_file($filename, $dst_file, $mime_type, $section);
    $doc_obj->add_metadata ($section, $assoc_field, $assoc_name);
    $doc_obj->add_metadata ($section, "srcurl", $assoc_url);

    my $mp3_info = get_mp3info($filename);
    my $mp3_tags = get_mp3tag($filename,0,2);

    my $metadata_fields = $self->{'metadata_fields'};

    if ($metadata_fields eq "*") {
	# Locate all info and tag metadata

	foreach my $ki ( keys %$mp3_info ) {
	    my $mp3_metavalue = $mp3_info->{$ki};

	    if ($mp3_metavalue !~ m/^\s*$/s) {
		my $mp3_metaname = "ex.id3.".lc($ki);
		$doc_obj->add_metadata ($section, $mp3_metaname, $mp3_metavalue);
	    }
	}

	foreach my $kt ( keys %$mp3_tags ) {
	    my $mp3_metavalue = $mp3_tags->{$kt};
	    
	    if ($mp3_metavalue !~ m/^\s*$/s) {
		my $kt_len = length($kt);
		my $kt_initial_cap = uc(substr($kt,0,1)).lc(substr($kt,1,$kt_len-1));
		my $mp3_metaname = "ex.id3.".$kt_initial_cap;
		
		$doc_obj->add_metadata ($section, $mp3_metaname, $mp3_metavalue);
	    }
	}
    }
    else {

	# Restrict metadata to that specifically given
	foreach my $field (split /,/, $metadata_fields) {

	    # check info
	    if (defined $mp3_info->{$field}) {

		my $mp3i_metavalue = $mp3_info->{$field};
		
		if ($mp3i_metavalue !~ m/^\s*$/s) {
		    my $mp3i_metaname = "ex.id3.".lc($field);
		    $doc_obj->add_metadata ($section, $mp3i_metaname, $mp3i_metavalue);
		}
	    }

	    # check tags
	    if (defined $mp3_tags->{uc($field)}) {

		my $mp3t_metavalue = $mp3_tags->{uc($field)};
		
		if ($mp3t_metavalue !~ m/^\s*$/s) {
		    my $mp3t_metaname = "ex.id3.".$field;
		    
		    $doc_obj->add_metadata ($section, $mp3t_metaname, $mp3t_metavalue);
		}
	    }
	    
	}
    }

    $doc_obj->add_metadata ($section, "FileFormat", "MP3");
    
    $doc_obj->add_metadata ($section, "srcicon", "_iconmp3_");
    # srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
    $doc_obj->add_metadata ($section, "srclink_file", $assoc_url);
    $doc_obj->add_metadata ($section, "srclinkFile", $assoc_url);
    my $applet_metadata = $self->{'applet_metadata'};
    if (defined $applet_metadata && $applet_metadata ) {
	my $applet_html 
	    = gen_mp3applet("_httpprefix_/collect/[collection]/index/assoc/[assocfilepath]/[srcurl]");
	$doc_obj->add_metadata ($section, "mp3applet", $applet_html);
    }

    my $assoc_images = $self->{'assoc_images'};
    if (defined $assoc_images && $assoc_images) {
	my @search_terms = ();

	my $title  = $mp3_tags->{'TITLE'};
	my $artist = $mp3_tags->{'ARTIST'};

	if (defined $title && $title ne "") {

	    push(@search_terms,$title);

	    if (defined $artist && $artist ne "") {
		push(@search_terms,$artist);
	    }
	}
	else {
	    push(@search_terms,$assoc_name);
	}

	push(@search_terms,"song");

	my $output_dir = $filename;
	$output_dir =~ s/\.\w+$//;

	my ($imgref_urls) = giget(\@search_terms,$output_dir);

	my $gi_base = gi_url_base();
	my $gi_query_url = gi_query_url(\@search_terms);

	$doc_obj->add_metadata ($section, "giquery", "<a href=\"$gi_base$gi_query_url\" target=giwindow>");
	$doc_obj->add_metadata ($section, "/giquery", "</a>");

	for (my $i=1; $i<=2; $i++) {
	    my $img_filename = "$output_dir/img_$i.jpg";
	    my $dst_file = "img_$i.jpg";

	    if (-e $img_filename) {
		$doc_obj->associate_file($img_filename, $dst_file, "image/jpeg", $section);

		my $srcurl = "src=\"_httpprefix_/collect/[collection]/index/assoc/[assocfilepath]/$dst_file\"";

		$doc_obj->add_metadata ($section, "img$i", 
					"<img $srcurl>");
		$doc_obj->add_metadata ($section, "smallimg$i", 
					"<img $srcurl width=100>");

		my $imgref_url = $imgref_urls->[$i-1];

		$doc_obj->add_metadata ($section, "imgref$i", "<a href=\"$imgref_url\" target=giwindow>");
		$doc_obj->add_metadata ($section, "/imgref$i", "</a>");
	    }

	}


    }

    return 1;
}


# we want to use ex.id3.Title if its there, otherwise we'll use BaseImporter method
sub title_fallback
{
    my $self = shift (@_);
    my ($doc_obj,$section,$file) = @_;

    if (!defined $doc_obj->get_metadata_element ($section, "Title")) {
	my $mp3_title = $doc_obj->get_metadata_element ($section, "ex.id3.Title");
	if (defined $mp3_title) {
	    $doc_obj->add_metadata ($section, "Title", $mp3_title);
	}
	else {
	    $self->BaseImporter::title_fallback($doc_obj, $section, $file);
	}
    }
}


1;











