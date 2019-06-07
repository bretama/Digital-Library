###########################################################################
#
# MetadataPass.pm -- class to enhance plugins with generic metadata capabilities
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

package MetadataPass;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use PrintInfo; # uses PrintInfo, but is not inherited


my $options = { 'name'     => "MetadataPass",
		'desc'     => "{MetadataPass.desc}",
		'abstract' => "yes",
		'inherits' => "no" };


sub new {
    my $class = shift (@_);
    my $plugin_name = shift (@_);

    my $self = {};
    $self->{'plugin_type'} = "MetadataPass";

    $self->{'option_list'} = [ $options ];

    return bless $self, $class;
}

sub init {
}

sub print_xml_usage
{
    PrintInfo::print_xml_usage(@_);
}

sub print_xml
{
    PrintInfo::print_xml(@_);
}

sub set_incremental
{
    PrintInfo::set_incremental(@_);
}

sub reset_saved_metadata {
    my $self = shift(@_);

    $self->{'saved_metadata'} = {};
}


sub get_saved_metadata {
    my $self = shift(@_);
    
    return $self->{'saved_metadata'};
}

sub open_prettyprint_metadata_table
{
    my $self = shift(@_);

    my $att   = "width=100% cellspacing=2";
    my $style = "style=\'border-bottom: 4px solid #000080\'";

    $self->{'ppmd_table'} = "\n<table $att $style>";
}

sub add_prettyprint_metadata_line 
{
    my $self = shift(@_);
    my ($metaname, $metavalue_utf8) = @_;

    $metavalue_utf8 = &util::hyperlink_text($metavalue_utf8);

    $self->{'ppmd_table'} .= "  <tr bgcolor=#b5d3cd>\n";
    $self->{'ppmd_table'} .= "    <td width=30%>\n";
    $self->{'ppmd_table'} .= "      $metaname\n";
    $self->{'ppmd_table'} .= "    </td>\n";
    $self->{'ppmd_table'} .= "    <td>\n";
    $self->{'ppmd_table'} .= "      $metavalue_utf8\n";
    $self->{'ppmd_table'} .= "    </td>\n";
    $self->{'ppmd_table'} .= "  </tr>\n";

}

sub close_prettyprint_metadata_table
{
    my $self = shift(@_);
    $self->{'ppmd_table'} .= "</table>\n";

    $self->set_filere_metadata("prettymd",$self->{'ppmd_table'});
    $self->{'ppmd_table'} = undef;
}

sub set_filere_metadata
{
    my $self = shift(@_);
    my ($full_mname,$md_content) = @_;

    if (defined $self->{'saved_metadata'}->{$full_mname}) {
	# accumulate - add value to existing value(s)
	if (ref ($self->{'saved_metadata'}->{$full_mname}) eq "ARRAY") {
	    push (@{$self->{'saved_metadata'}->{$full_mname}}, $md_content);
	} else {
	    $self->{'saved_metadata'}->{$full_mname} = 
		[$self->{'saved_metadata'}->{$full_mname}, $md_content];
	}
    } else {
	# accumulate - add value into (currently empty) array
	$self->{'saved_metadata'}->{$full_mname} = [$md_content];
    }
}


sub get_filere_metadata
{
    my $self = shift(@_);
    my ($full_mname) = @_;

    return $self->{'saved_metadata'}->{$full_mname};
}

sub get_filere_metadata_head
{
    my $self = shift(@_);
    my ($full_mname) = @_;
    
    return $self->{'saved_metadata'}->{$full_mname}->[0];
}



1;
