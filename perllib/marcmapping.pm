###########################################################################
#
# marcmapping.pm -- code to read in the marc mapping files
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2008 New Zealand Digital Library Project
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

package marcmapping;

sub parse_marc_metadata_mapping
{
    my ($mm_file_or_files, $outhandle) = @_;

    my $metadata_mapping = {};

    if (ref ($mm_file_or_files) eq 'ARRAY') {
	my $mm_files = $mm_file_or_files;

	# Need to process files in reverse order.  This is so in the
	# case where we have both a "collect" and "main" version,
	# the "collect" one tops up the main one

	my $mm_file;
	while ($mm_file = pop(@$mm_files)) {
	    &_parse_marc_metadata_mapping($mm_file,$metadata_mapping, $outhandle);
	}
    }
    else {
	my $mm_file = $mm_file_or_files;
	&_parse_marc_metadata_mapping($mm_file,$metadata_mapping, $outhandle);
    }

    return $metadata_mapping;
}

sub _parse_marc_metadata_mapping
{
    my ($mm_file,$metadata_mapping, $outhandle) = @_;

    if (open(MMIN, "<$mm_file"))
    {
	my $l=0;
	my $line;
	while (defined($line=<MMIN>))
	{
	    $l++;
	    chomp $line;
	    $line =~ s/#.*$//; # strip out any comments, including end of line
	    next if ($line =~ m/^\s*$/); 
	    $line =~ s/\s+$//; # remove any white space at end of line

	    my $parse_error_count = 0;
	    if ($line =~ m/^-(\d+)\s*$/) {
		# special "remove" rule syntax
		my $marc_info = $1;
		if (defined $metadata_mapping->{$marc_info}) {
		    delete $metadata_mapping->{$marc_info};
		}
		else {
		    print $outhandle "Parse Warning: Did not find pre-existing rule $marc_info to remove";
		    print $outhandle " on line $l of $mm_file:\n";
		    print $outhandle "  $line\n";
		}
	    }
	    elsif ($line =~ m/^(.*?)->\s*([\w\.\^]+)$/)
	    {
		my $lhs = $1;
		my $gsdl_info = $2;

		my @fields = split(/,\s*/,$lhs);
		my $f;
		while ($f  = shift (@fields)) {
		    $f =~ s/\s+$//; # remove any white space at end of line

		    if ($f =~ m/^(\d+)\-(\d+)$/) {
			# number range => generate number in range and
			# push on to array
			push(@fields,$1..$2);
			next;
		    }

		    if ($f =~ m/^(\d+)((?:(?:\$|\^)\w)*)\s*$/) {

			my $marc_info = $1;
			my $opt_sub_fields = $2;

			if ($opt_sub_fields ne "") {			
			    my @sub_fields = split(/\$|\^/,$opt_sub_fields);
			    shift @sub_fields; # skip first entry, which is blank

			    foreach my $sub_field (@sub_fields) {
				$metadata_mapping->{$marc_info."\$".$sub_field} = $gsdl_info;
			    }
			}
			else {
			    # no subfields to worry about
			    $marc_info =~ s/\^/\$/;
			    $metadata_mapping->{$marc_info} = $gsdl_info;
			}
		    }
		    else {
			$parse_error_count++;
		    }
		}
	    }
	    else
	    {
		$parse_error_count++;
	    }

	    if ($parse_error_count>0) {
		
		print $outhandle "Parse Error: $parse_error_count syntax error(s) on line $l of $mm_file:\n";
		print $outhandle "  $line\n";
	    }
	}
	close(MMIN);
    }
    else
    {
	print $outhandle "Unable to open $mm_file: $!\n";
    }
}



1;
