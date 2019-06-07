###########################################################################
#
# cfgread.pm --
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

# reads in configuration files

package cfgread;

use strict; no strict 'refs';


sub read_cfg_line {
    my ($handle) = @_;
    my $line = "";
    my @line = ();
    my $linecontinues = 0;

    while (defined($line = <$handle>)) {
	$line =~ s/^\#.*$//;   # remove comments
	$line =~ s/\cM|\cJ//g; # remove end-of-line characters
	$line =~ s/^\s+//;     # remove initial white space
	# Merge with following line if a quoted phrase is left un-closed.
	if ($line =~ m/^([\"\'])/ || $line =~ m/[^\\]([\"\'])/) {
	    my $quote=$1;

	    # Improve speed substantially by not doing the regular expression on $line in the while loop
	    #   (since $line gets longer each iteration, the regular expression gets slower and slower)
	    # Instead we just check each new line to see if it finishes the quoted multi-line value
	    if ($line !~ m/$quote(.*?[^\\])?(\\\\)*$quote/)
	    {
		my $nextline;
		while (defined($nextline = <$handle>))
		{
		    $nextline =~ s/\r?\n//; # remove end-of-line
		    $line .= " " . $nextline;

		    # Break out of the while loop if we've found the end of the multi-line value
		    last if ($nextline =~ m/^(.*?[^\\])?(\\\\)*$quote/);
		}
	    }
	}
	$linecontinues = $line =~ s/\\$//;

	while ($line =~ s/\s*(\".*?[^\\](\\\\)*\"|\'.*?[^\\](\\\\)*\'|\S+)\s*//) {
	    if (defined $1) {
		# remove any enclosing quotes
		my $entry = $1;
		$entry =~ s/^([\"\'])(.*)\1$/$2/;

		# substitute an environment variables
##		$entry =~ s/\$(\w+)/$ENV{$1}/g;
		$entry =~ s/\$\{(\w+)\}/$ENV{$1}/g;
		push (@line, $entry);
	    } else {
		push (@line, "");
	    }
	}

	if (scalar(@line) > 0 && !$linecontinues) {
#	    print STDERR "line: \"" . join ("\" \"", @line) . "\"\n";
	    return \@line;
	}
    }

    return undef;
}

sub write_cfg_line {
    my ($handle, $line) = @_;
    print $handle join ("\t", @$line), "\n";
}


# stringexp, arrayexp, hashexp,arrayarrayexp and hashhashexp
# should be something like '^(this|that)$'
sub read_cfg_file {
    my ($filename, $stringexp, $arrayexp, $hashexp, $arrayarrayexp,
	$hashhashexp) = @_;
    my ($line);
    my $data = {};

    if (open (COLCFG, $filename)) {
	while (defined ($line = &read_cfg_line('COLCFG'))) {
	    if (scalar(@$line) >= 2) {
		my $key = shift (@$line);
		if (defined $stringexp && $key =~ /$stringexp/) {
		    $data->{$key} = shift (@$line);

		} elsif (defined $arrayexp && $key =~ /$arrayexp/) {
		    push (@{$data->{$key}}, @$line);

		} elsif (defined $hashexp && $key =~ /$hashexp/) {
		    my $k = shift @$line;
		    my $v = shift @$line;
		    $data->{$key}->{$k} = $v;
		} elsif (defined $arrayarrayexp && $key =~ /$arrayarrayexp/) {
		    if (!defined $data->{$key}) {
			$data->{$key} = [];
		    }
		    push (@{$data->{$key}}, $line);
		}
		elsif (defined $hashhashexp && $key =~ /$hashhashexp/) {
		    my $k = shift @$line;
		    my $p = shift @$line;
		    my $v = shift @$line;
		    if (!defined $v) {
			$v = $p;
			$p = 'default';
		    }
		    $data->{$key}->{$k}->{$p} = $v;
		}
	    }
	}
	close (COLCFG);

    } else {
	print STDERR "cfgread::read_cfg_file couldn't read the cfg file $filename\n";
    }

    return $data;
}

# If the cfg file contains unicode characters, use this method to read from it
# Used by HFileHierarchy classifier, since an HFile is read as a cfg file, but 
# can contain unicode characters.
sub read_cfg_file_unicode {
    my ($filename, $stringexp, $arrayexp, $hashexp, $arrayarrayexp,
	$hashhashexp) = @_;
    my ($line);
    my $data = {};

    if (open (COLCFG, $filename)) {
	binmode(COLCFG,":utf8");
	while (defined ($line = &read_cfg_line('COLCFG'))) {
	    if (scalar(@$line) >= 2) {

		#map { decode("utf8",$_) } @$line; #use Encode;

		my $key = shift (@$line);
		
		# OIDtype and OIDmetadata may be present in collect.cfg as "oidtype" and "oidmetadata"
		# but rest of perl code expects it to be OIDtype/OIDmetadata and uses these as indexes into hashes
		# so convert any lowercase version to uppercase here
		if($key =~ m/^oid(type|metadata)/) {			
			$key =~ s/^oid/OID/;
		}
		if (defined $stringexp && $key =~ /$stringexp/) {
		    $data->{$key} = shift (@$line);

		} elsif (defined $arrayexp && $key =~ /$arrayexp/) {
		    push (@{$data->{$key}}, @$line);

		} elsif (defined $hashexp && $key =~ /$hashexp/) {
		    my $k = shift @$line;
		    my $v = shift @$line;
		    $data->{$key}->{$k} = $v;
		} elsif (defined $arrayarrayexp && $key =~ /$arrayarrayexp/) {
		    if (!defined $data->{$key}) {
			$data->{$key} = [];
		    }
		    push (@{$data->{$key}}, $line);
		}
		elsif (defined $hashhashexp && $key =~ /$hashhashexp/) {
		    my $k = shift @$line;
		    my $p = shift @$line;
		    my $v = shift @$line;
		    if (!defined $v) {
			$v = $p;
			$p = 'default';
		    }
		    $data->{$key}->{$k}->{$p} = $v;
		}
	    }
	}
	close (COLCFG);

    } else {
	print STDERR "cfgread::read_cfg_file_unicode couldn't read the cfg file $filename\n";
    }

    return $data;
}


# stringexp, arrayexp, hashexp and arrayarrayexp 
# should be something like '^(this|that)$'
sub write_cfg_file {
    my ($filename, $data, $stringexp, $arrayexp, $hashexp, $arrayarrayexp,
	$hashhashexp) = @_;

    if (open (COLCFG, ">$filename")) {
	foreach my $key (sort(keys(%$data))) {
	    if ($key =~ /$stringexp/) {
		&write_cfg_line ('COLCFG', [$key, $data->{$key}]);
	    } elsif ($key =~ /$arrayexp/) {
		&write_cfg_line ('COLCFG', [$key, @{$data->{$key}}]);
	    } elsif (defined $hashexp && $key =~ /$hashexp/) {
		foreach my $k (keys (%{$data->{$key}})) {
		    &write_cfg_line ('COLCFG', [$key, $k, $data->{$key}->{$k}]);
		}
	    } elsif (defined $arrayarrayexp && $key =~ /$arrayarrayexp/) {
		foreach my $k (@{$data->{$key}}) {
		    &write_cfg_line ('COLCFG', [$key, @$k]);
		}
	    } elsif (defined $hashhashexp && $key =~ /$hashhashexp/) {
		foreach my $k (keys (%{$data->{$key}})) {
		    foreach my $p (keys (%{$data->{$key}->{$k}})) {
			if ($p =~ /default/) {
			    &write_cfg_line ('COLCFG', 
					     [$key, $k, $data->{$key}->{$k}]);
			}
			else {
			    &write_cfg_line ('COLCFG', 
			       [$key, $k, $p, $data->{$key}->{$k}->{$p}]);
			}
		    }
		}
	    }
	}
	close (COLCFG);
    } else {
	print STDERR "cfgread::write_cfg_file couldn't write the cfg file $filename\n";
    }
}


1;
