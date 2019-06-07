###########################################################################
#
# imageaction.pm -- 
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2009 New Zealand Digital Library Project
#
# This program is free software; you can redistr   te it and/or modify
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

package imageaction;

use strict;

use cgiactions::baseaction;
use util;

@imageaction::ISA = ('baseaction');


my $action_table =
{ 
    "fit-screen" => { 'compulsory-args' => [ "pageWidth", "pageHeight", 
					     "assocDir", "assocFile" ],
		      'optional-args'   => [ "orientation" ] },

};


sub new 
{
    my $class = shift (@_);
    my ($gsdl_cgi,$iis6_mode) = @_;

    my $self = new baseaction($action_table,$gsdl_cgi,$iis6_mode);

    return bless $self, $class;
}



sub get_mime_type
{
    my $self = shift @_;

    my ($file) = @_;

    my %image_mime_re = 
    (
	"gif"   => "image/gif",
	"jpe?g" => "image/jpeg",
	"png"   => "image/png",
	"tiff?" => "image/tiff",
	"bmp"   => "image/bmp"
    );

    my ($ext) = ($file =~ m/^.*\.(.*)?$/);

    foreach my $re (keys %image_mime_re) {
	if ($ext =~ m/^$re$/i) {
	    return $image_mime_re{$re};
	}
    }

    return undef;
}




sub fit_screen
{
    my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdlhome  = $self->{'gsdlhome'};


    if ($baseaction::authentication_enabled) {
	# Ensure the user is allowed to edit this collection
	&authenticate_user($gsdl_cgi, $username, $collect);
    }

    my $site = $self->{'site'};
    my $collect_directory = $gsdl_cgi->get_collection_dir($site);
    #my $collect_directory = &util::filename_cat($gsdlhome, "collect");
#    $gsdl_cgi->checked_chdir($collect_directory);


#    # Make sure the collection isn't locked by someone else
#

    $self->lock_collection($username, $collect);

    # look up additional args

    my $pageWidth  = $self->{'pageWidth'};
    my $pageHeight = $self->{'pageHeight'};
    my $assocDir   = $self->{'assocDir'};
    my $assocFile  = $self->{'assocFile'};

    my $orientation = $self->{'orientation'};
    $orientation = "portrait" if (!defined $orientation);

    my $toplevel_assoc_dir
	= &util::filename_cat($collect_directory,$collect,"index","assoc");
    my $src_full_assoc_filename
	= &util::filename_cat($toplevel_assoc_dir,$assocDir,$assocFile);

    my $dst_width = $pageWidth;
    my $dst_height = $pageHeight;

    my $opt_ls = ($orientation eq "landscape") ? "-r" : "";
    
    my $dst_file = $dst_width."x".$dst_height."$opt_ls-$assocFile";

    my $dst_full_assoc_filename
	= &util::filename_cat($toplevel_assoc_dir,$assocDir,$dst_file);

    # **** What if assoc folder is on read-only medium such as CD-ROM?
    # Should really switch to using some collection specific tmp area
    # => test if top_level assoc dir has write permission?

    if (!-w $toplevel_assoc_dir) {
	$gsdl_cgi->generate_error("Cannot write out resized image $dst_full_assoc_filename.");
    }

    # For now will assume it is writable

    if (!-e $dst_full_assoc_filename) {
	# generate resized image

	# Better to make sure ImageMagick is installed 
	
        my $resize = "-filter Lanczos -resize $dst_width"."x"."$dst_height!";
	# use of "!" forces convert to produce exactly these dimensions, rather
	# than preserving aspect ratio.  In actual fact, it is intended that
	# the width and height values passed in *do* preserve the aspect ratio
	# Doing it this way makes it easier for the web browser to know (ahead of time) the
	# width and height of the image that will be generated (useful for putting into
	# <img> and <div> tags


	my $cmd = "\"".&util::get_perl_exec()."\" -S gs-magick.pl convert \"$src_full_assoc_filename\" ";
	$cmd .= "-rotate 90 " if ($orientation eq "landscape");

	$cmd .= "$resize \"$dst_full_assoc_filename\"";

	`$cmd`;

	# generate resized image in assoc file area (if writable)
	# otherwise in (collection's??) tmp directory
    }

    my $mime_type = $self->get_mime_type($dst_file);
    
    if (defined $mime_type) {
	# now output it with suitable mime header
	print STDOUT "Content-type:$mime_type\n\n";

	if (open(IMGIN,"<$dst_full_assoc_filename")) {
	    binmode IMGIN;
	    binmode STDOUT;
	    
	    my $data;	     
	    while (read(IMGIN,$data,1024) != 0) { 
		print STDOUT $data;
	    } 

	    close(IMGIN);

	    #system("cat \"$dst_full_assoc_filename\"");
	}
	else {
	    $gsdl_cgi->generate_error("Unable to open $dst_full_assoc_filename for output");
	}
    }
    else {
	$gsdl_cgi->generate_error("Unrecognised image mime-type for $dst_file");
    }

}


1;
