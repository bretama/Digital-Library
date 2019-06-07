###########################################################################
#
# download.pm -- functions to handle using download modules
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

package download;

use strict; # to pick up typos and undeclared variables...
no strict 'refs'; # ...but allow filehandles to be variables and vice versa
no strict 'subs';

##require util;
use util;
use gsprintf 'gsprintf';


sub load_download {
    my ($download_name,$download_options) = @_;

    my ($download_obj);

    my $coldownloadname ="";

    if ($ENV{'GSDLCOLLECTDIR'}){
   
	$coldownloadname = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 
					      "perllib","downloaders", 
					      "${download_name}.pm");

    }
   
    my $maindownloadname = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},
					       "perllib","downloaders", 
					       "${download_name}.pm");

    if (-e $coldownloadname) { require $coldownloadname;}
    elsif (-e $maindownloadname ) { require $maindownloadname; }
    else {
	&gsprintf(STDERR, "{download.could_not_find_download}\n",
		 $download_name);
	die "\n";
    }

    eval ("\$download_obj = new \$download_name([],\$download_options)");
    die "$@" if $@;
 
    return $download_obj;
}

sub process {
    my ($download_obj,$options) = @_;
    # options: This is a hash map which maps to 
    #                   downloadfrom's arguments
    #                   $options->{'cache_dir'}
    #                   $options->{'download_mode'}
    #                   $options->{'gli_call'}
    #                   $options->{'info'}
    $download_obj->setIsGLI($options->{'gli'});

    ($download_obj->download($options) == 1)?
	return "true":
	return "false";
}

sub get_information {
    my ($download_obj) = @_;
    
    $download_obj->url_information();
}

1;
