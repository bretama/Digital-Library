###########################################################################
#
# plugout.pm -- functions to handle using plugouts
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

package plugout;

use strict; # to pick up typos and undeclared variables...
no strict 'refs'; # ...but allow filehandles to be variables and vice versa
no strict 'subs';

require util;
use FileUtils;
use gsprintf 'gsprintf';

# global variables
my $stats = {'num_processed' => 0,
	     'num_blocked' => 0,
	     'num_not_processed' => 0,
	     'num_not_recognised' => 0,
	     'num_archives' => 0
	     };

#globaloptions contains any options that should be passed to all plugouts
my ($verbosity, $outhandle, $failhandle, $globaloptions);

# - significantly rewritten to support plugouts in extensions [jmt12]
sub load_plugout{
    my ($plugout) = shift @_;
    my $plugout_name = shift @$plugout;
    my $plugout_suffix = &FileUtils::filenameConcatenate('perllib', 'plugouts', $plugout_name . '.pm');
    my $plugout_found = 0;

    # add collection plugout directory to INC unless it is already there
    my $colplugdir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},'perllib','plugouts');
    if (-d $colplugdir)
    {
      my $found_colplugdir = 0;
      foreach my $path (@INC)
      {
        if ($path eq $colplugdir)
        {
          $found_colplugdir = 1;
          last;
        }
      }
      if (!$found_colplugdir)
      {
        unshift (@INC, $colplugdir);
      }
    }

    # To find the plugout we check a number of possible locations
    # - any plugout found in the collection itself is our first choice, with
    #   those located in 'custom' having precedence
    if (defined($ENV{'GSDLCOLLECTION'}))
    {
      my $collect_dir = $ENV{'GSDLCOLLECTION'};

      # (needed for Veridian?)
      my $custom_plugout = &FileUtils::filenameConcatenate($collect_dir, "custom", $collect_dir, $plugout_suffix);
      if (&FileUtils::fileExists($custom_plugout))
      {
        require $custom_plugout;
        $plugout_found = 1;
      }
      else
      {
        # typical collection override
        my $collection_plugout = &FileUtils::filenameConcatenate($collect_dir, $plugout_suffix);
        if (&FileUtils::fileExists($collection_plugout))
        {
          require $custom_plugout;
          $plugout_found = 1;
        }
      }
    }
    # - we then search for overridden version provided by any registered GS3
    #   extensions (check in order of extension definition)
    if (!$plugout_found && defined $ENV{'GSDL3EXTS'})
    {
      my $ext_prefix = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'}, "ext");
      my @extensions = split(/:/,$ENV{'GSDL3EXTS'});
      foreach my $e (@extensions)
      {
        my $extension_plugout = &FileUtils::filenameConcatenate($ext_prefix, $e, $plugout_suffix);
        if (&FileUtils::fileExists($extension_plugout))
        {
          require $extension_plugout;
          $plugout_found = 1;
        }
      }
    }
    # - similar for GS2 extensions
    if (!$plugout_found && defined $ENV{'GSDLEXTS'})
    {
      my $ext_prefix = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "ext");
      my @extensions = split(/:/,$ENV{'GSDLEXTS'});
      foreach my $e (@extensions)
      {
        my $extension_plugout = &FileUtils::filenameConcatenate($ext_prefix, $e, $plugout_suffix);
        if (&FileUtils::fileExists($extension_plugout))
        {
          require $extension_plugout;
          $plugout_found = 1;
        }
      }
    }
    # - and the default is the main Greenstone version of the plugout
    if (!$plugout_found)
    {
      my $main_plugout = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, $plugout_suffix);
      if (&FileUtils::fileExists($main_plugout))
      {
        require $main_plugout;
        $plugout_found = 1;
      }
    }

    # - no plugout found with this name
    if (!$plugout_found)
    {
      gsprintf($outhandle, "{plugout.could_not_find_plugout}\n", $plugout_name);
      die "\n";
    }

    # - create a plugout object
    my ($plugobj);

    eval ("\$plugobj = new \$plugout_name([],\$plugout)");
    die "$@" if $@;

    return $plugobj;
}

1;
