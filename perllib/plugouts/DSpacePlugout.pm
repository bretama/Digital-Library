###########################################################################
#
# DSpacePlugout.pm -- the plugout module for DSpace archives
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2006 New Zealand Digital Library Project
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

package DSpacePlugout;

use strict;
no strict 'refs';
use utf8;
eval {require bytes};
use util;
use FileUtils;
use BasePlugout;

sub BEGIN {
    @DSpacePlugout::ISA = ('BasePlugout');
}

my $arguments = [ 
       { 'name' => "metadata_prefix", 
	'desc' => "{DSpacePlugout.metadata_prefix}",
	'type' => "string",   
	'reqd' => "no",
	'hiddengli' => "no"} ];


my $options = { 'name'     => "DSpacePlugout",
		'desc'     => "{DSpacePlugout.desc}",
		'abstract' => "no",
		'inherits' => "yes",
                'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($plugoutlist, $inputargs,$hashArgOptLists) = @_;
    push(@$plugoutlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BasePlugout($plugoutlist,$inputargs,$hashArgOptLists);    

#    print STDERR "***** metadata prefix = \"", $self->{'metadata_prefix'}, "\"\n";

    return bless $self, $class;
}

sub saveas_dspace_metadata
{
    my $self = shift (@_);
    my ($doc_obj,$working_dir,$metadata_file,$docroot,$metadata_prefix) = @_;

    # my $docroot_attributes = ($metadata_prefix eq "dc") ? undef : "schema=\"$metadata_prefix\"";
    my $docroot_attributes = "schema=\"$metadata_prefix\"";
 
    my $doc_dc_file = &FileUtils::filenameConcatenate ($working_dir, $metadata_file);
    $self->open_xslt_pipe($doc_dc_file,$self->{'xslt_file'});

    my $outhandler;
    if (defined $self->{'xslt_writer'}){
	$outhandler = $self->{'xslt_writer'};
    }
    else{
	$outhandler = $self->get_output_handler($doc_dc_file);
     }
   
    $self->output_general_xml_header($outhandler, $docroot, $docroot_attributes);

    my $metadata_hashmap = $doc_obj->get_metadata_hashmap($doc_obj->get_top_section(),
                                                          $metadata_prefix);

    if(defined $metadata_prefix && $metadata_prefix ne "") {
	# merge dc with any ex.dc

	my $ex_dc_metadata_hashmap = $doc_obj->get_metadata_hashmap($doc_obj->get_top_section(),
                                                          "ex.dc");

	foreach my $metaname (keys %$ex_dc_metadata_hashmap) {
	    my $metaname_without_ex_prefix = $metaname;
	    $metaname_without_ex_prefix =~ s/^ex\.(.*)/$1/; # remove any ex from the ex.dc prefix

	    # if there's an ex.dc value for a metaname for which no dc
	    # value was assigned, put the ex.dc value into the hashmap
	    if(!defined $metadata_hashmap->{$metaname_without_ex_prefix}) { 
		$metadata_hashmap->{$metaname_without_ex_prefix} = [];
		push(@{$metadata_hashmap->{$metaname_without_ex_prefix}},@{$ex_dc_metadata_hashmap->{$metaname}}); 
	    }
	}

    }

    foreach my $metaname (keys %$metadata_hashmap) {
      my $metavals = $metadata_hashmap->{$metaname};

      my $qualifier = undef;
      my $element;
      if ($metaname =~ m/^(.*?)\^(.*?)$/) {
        $element = $1;
        $qualifier = $2;
		$qualifier = lc($qualifier);
      }
      else {
        $element = $metaname;
      }
      $element =~ s/^.*?\.//;
	  $element = lc($element);

      foreach my $metaval (@$metavals) {
        
		#if element is empty then no need to export it.
		
		if ($metaval =~ /\S/) {
			print $outhandler "  <dcvalue element=\"$element\"";
			#If no qualifier then add qualifier="none"
			#print $outhandler " qualifier=\"$qualifier\"" if defined $qualifier;
			if (defined $qualifier) {
				print $outhandler " qualifier=\"$qualifier\"" ;
			}
			else {
				print $outhandler " qualifier=\"none\" language=\"\"" ;
			}
			print $outhandler ">$metaval";
			print $outhandler "</dcvalue>\n";
		}
		
		
		
      }
    }
    
    $self->output_general_xml_footer($outhandler,$docroot);
   
    if (defined $self->{'xslt_writer'}){     
	$self->close_xslt_pipe(); 
    }
    else{
	close($outhandler);
    }

}

sub saveas {
    my $self = shift (@_);
    my ($doc_obj,$doc_dir) = @_;

    my $output_dir = $self->get_output_dir();
    &FileUtils::makeAllDirectories ($output_dir) unless -e $output_dir;

    my $working_dir = &FileUtils::filenameConcatenate ($output_dir, $doc_dir);    
    &FileUtils::makeAllDirectories ($working_dir, $doc_dir);

    #########################
    # save the handle file
    #########################
    my $outhandle = $self->{'output_handle'};
  
	my $generate_handle = 0;
	if ($generate_handle) {
		# Genereate handle file 
		# (Note: this section of code would benefit from being restructured)
		my $doc_handle_file = &FileUtils::filenameConcatenate ($working_dir, "handle");
    
		my $env_hp = $ENV{'DSPACE_HANDLE_PREFIX'};
		my $handle_prefix = (defined $env_hp) ? $env_hp : "123456789";

		my $outhandler =  $self->get_output_handler($doc_handle_file);

		my ($handle) = ($doc_dir =~ m/^(.*)(:?\.dir)?$/);

		print $outhandler "$handle_prefix/$handle\n";
    
		close ($outhandler);
    }
	
    #########################
    # save the content file
    #########################
    my $doc_contents_file = &FileUtils::filenameConcatenate ($working_dir, "contents");
    
    my $outhandler =  $self->get_output_handler($doc_contents_file);

    $self->process_assoc_files ($doc_obj, $doc_dir, $outhandler);
    
    $self->process_metafiles_metadata ($doc_obj);

    close($outhandler);

    #############################
    # save the dublin_core.xml file
    ###############################
#      my $doc_dc_file = &FileUtils::filenameConcatenate ($working_dir, "dublin_core.xml");
#      $self->open_xslt_pipe($doc_dc_file,$self->{'xslt_file'});

#      if (defined $self->{'xslt_writer'}){
#  	$outhandler = $self->{'xslt_writer'};
#      }
#      else{
#  	$outhandler = $self->get_output_handler($doc_dc_file);
#       }
   
#      $self->output_general_xml_header($outhandler, "dublin_core");

#      my $all_text = $self->get_dc_metadata($doc_obj, $doc_obj->get_top_section());
#      print $outhandler $all_text;

#      $self->output_general_xml_footer($outhandler,"dublin_core");
   
#      if (defined $self->{'xslt_writer'}){     
#  	$self->close_xslt_pipe(); 
#      }
#      else{
#  	close($outhandler);
#      }

    $self->saveas_dspace_metadata($doc_obj,$working_dir,
                                  "dublin_core.xml","dublin_core","dc");

    my $metadata_prefix_list = $self->{'metadata_prefix'};
#    print STDERR "***!! md prefix = $metadata_prefix_list\n";

    my @metadata_prefixes = split(/,\s*/,$metadata_prefix_list);
    foreach my $ep (@metadata_prefixes) {
      $self->saveas_dspace_metadata($doc_obj,$working_dir,
                                    "metadata_$ep.xml","dublin_core",$ep); 
    }

    $self->{'short_doc_file'} =  &FileUtils::filenameConcatenate ($doc_dir, "dublin_core.xml"); 
    $self->store_output_info_reference($doc_obj);
}

 sub process_assoc_files {
    my $self = shift (@_);
    my ($doc_obj, $doc_dir, $handle) = @_;

    my $outhandler = $self->{'output_handle'};
    
    my $output_dir = $self->get_output_dir();
    return if (!defined $output_dir);

    my $working_dir = &FileUtils::filenameConcatenate($output_dir, $doc_dir);

    my @assoc_files = ();
    my $filename;;

    my $source_filename = $doc_obj->get_source_filename();

    my $collect_dir = $ENV{'GSDLCOLLECTDIR'};

    if (defined $collect_dir) {
	my $dirsep_regexp = &util::get_os_dirsep();

	if ($collect_dir !~ /$dirsep_regexp$/) {
	    $collect_dir .= &util::get_dirsep(); # ensure there is a slash at the end
	}

	# This test is never going to fail on Windows -- is this a problem?
	if ($source_filename !~ /^$dirsep_regexp/) {
	    $source_filename = &FileUtils::filenameConcatenate($collect_dir, $source_filename);
	}
    }
   
    my ($tail_filename) = ($source_filename =~ m/([^\/\\]*)$/);
    
    print $handle "$tail_filename\n";
    
    $filename = &FileUtils::filenameConcatenate($working_dir, $tail_filename);
    &FileUtils::hardLink ($source_filename, $filename, $self->{'verbosity'});
             
    # set the assocfile path (even if we have no assoc files - need this for lucene)
    $doc_obj->set_utf8_metadata_element ($doc_obj->get_top_section(),
					 "assocfilepath",
					 "$doc_dir");
    foreach my $assoc_file_rec (@{$doc_obj->get_assoc_files()}) {
	my ($dir, $afile) = $assoc_file_rec->[1] =~ /^(.*?)([^\/\\]+)$/;
	$dir = "" unless defined $dir;
	    
	
	my $real_filename = $assoc_file_rec->[0];
	# for some reasons the image associate file has / before the full path
	$real_filename =~ s/^\\(.*)/$1/i;
	if (-e $real_filename) {
		# escape backslashes and brackets in path for upcoming regex match
		my $escaped_source_filename = &util::filename_to_regex($source_filename);
	    if ($real_filename =~ m/$escaped_source_filename$/) {
		next;
	    }
	    else {
		my $bundle = "bundle:ORIGINAL";
		
		if ($afile =~ m/^thumbnail\./) {
		    $bundle = "bundle:THUMBNAIL";
		}

		# Store the associated file to the "contents" file. Cover.pdf not needed.
		if ($afile ne "cover.jpg") {
			print $handle "$assoc_file_rec->[1]\t$bundle\n";
	    }
		}
	
	    $filename = &FileUtils::filenameConcatenate($working_dir, $afile);
	    
		if ($afile ne "cover.jpg") {
			&FileUtils::hardLink ($real_filename, $filename, $self->{'verbosity'});
	        $doc_obj->add_utf8_metadata ($doc_obj->get_top_section(),
				 "gsdlassocfile",
				 "$afile:$assoc_file_rec->[2]:$dir");
		}
	} elsif ($self->{'verbosity'} > 2) {
	    print $outhandler "DSpacePlugout::process couldn't copy the associated file " .
		"$real_filename to $afile\n";
	}
    }
}
                          

sub get_new_doc_dir{
   my $self = shift (@_);  
   my($working_info,$working_dir,$OID) = @_; 
  
   return $OID;

}
