###########################################################################
#
# ParallelInexport.pm -- useful class to support parallel_import.pl
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

package ParallelInexport;

use strict;


# index the files in parallel using MPI farmer to farm off multiple processes
# [hs, 1 july 2010]
sub farm_out_processes
{
   my ($jobs, $epoch, $importdir, $block_hash, $collection, $site) = @_;

   my $tmp_filelist = &util::filename_cat($ENV{'GSDLHOME'}, "tmp", "filelist.txt");

   # create the list of files to import
   open (my $filelist, ">$tmp_filelist");
   foreach my $filename (sort keys %{$block_hash->{'all_files'}})
   {
       my $full_filename = &util::filename_cat($importdir,$filename);
       if ((! exists $block_hash->{'file_blocks'}->{$full_filename}) 
	   && ($filename !~ m/metadata\.xml$/))
       {
	   print $filelist "$filename\n";
       }
   }
   close ($filelist); 
   
   # invoke the farmer to start processing the files
   $site = "localsite" if ((!defined $site) || ($site eq ""));
   my $gsdlhome = $ENV{'GSDLHOME'};
   my $farmer_exe = &util::filename_cat($gsdlhome,"bin",$ENV{'GSDLOS'},"farmer".&util::get_os_exe());

   my $mpi_cmd = "mpirun -np $jobs $farmer_exe $tmp_filelist $epoch $gsdlhome $site $collection";

   system ($mpi_cmd);
}

1;
