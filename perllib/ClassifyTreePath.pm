###########################################################################
#
# ClassifyTreePath.pm --
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2006-2010  DL Consulting Ltd
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


package ClassifyTreePath;

use strict;


# /** Construct a new tree path object based on the given value path.
#  *
#  *  @param  $class  The name of the class to bless as a string
#  *  @param  $path   The path as a pip delimited string
#  *  @return A reference to the ClassifyTreePath object
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub new()
  {
    my ($class, $path) = @_;
    my $debug = 0;
    print STDERR "ClassifyTreePath.new(\"$path\")\n" unless !$debug;
    # Store the variables
    my $self = {};
    $self->{'debug'} = $debug;
    $self->{'path'} = $path;
    # Bless me father for I have sinned
    bless $self, $class;
    return $self;
  }
# /** new() **/

# /** Adds a new path component on to the end of the current path.
#  *
#  *  @param  $component The new component to add as a string
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub addPathComponent()
  {
    my ($self, $component) = @_;
    print STDERR "ClassifyTreePath.addPathComponent(\"$component\")\n" unless !$self->{'debug'};
    if($self->{'path'} =~ /\w+/)
      {
        $self->{'path'} .= "|" . $component;
      }
    else
      {
        $self->{'path'} = $component;
      }
  }
# /** addPathComponent() **/

# /** Compare this path against another for equality.
#  *
#  *  @param  $other_path_obj The path object to compare to
#  *  @return 1 if the paths match, 0 otherwise
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub equals()
  {
    my ($self, $other_path_obj) = @_;
    print STDERR "ClassifyTreePath.equals()\n" unless !$self->{'debug'};
    return $self->{'path'} eq $other_path_obj->toString();
  }
# /** equals() **/

# /** Extracts the first path component from the path.
#  *
#  * @return The first path component as a string
#  *
#  * @author John Thompson, DL Consulting Ltd.
#  */
sub getFirstPathComponent()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreePath.getFirstPathComponent()\n" unless !$self->{'debug'};
    my @path = split(/\|/, $self->{'path'});
    return $path[0];
  }
# /** getFirstPathComponent() **/

# /** Extracts the last path component from the path.
#  *
#  * @return The last path component as a string
#  *
#  * @author John Thompson, DL Consulting Ltd.
#  */
sub getLastPathComponent()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreePath.getLastPathComponent()\n" unless !$self->{'debug'};
    my @path = split(/\|/, $self->{'path'});
    return @path[scalar(@path) - 1];
  }
# /** getLastPathComponent() **/

# /** Return a path object which is the parent path of this one.
#  *
#  * @return The parent path object
#  *
#  * @author John Thompson, DL Consulting Ltd.
#  */
sub getParentPath()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreePath.getParentPath()\n" unless !$self->{'debug'};
    my $result = 0;
    my @path = split(/\|/, $self->{'path'});
    if (scalar(@path) > 0)
      {
        pop(@path);
        $result = new ClassifyTreePath(join("|", @path));
      }
    return $result;
  }
# /** getParentPath() **/

# /** Retrieves the path component located at the indicated index.
#  *
#  *  @param  $index  The index of the component as an integer
#  *  @return The component as a string, or 0 if index out of range
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getPathComponent()
  {
    my ($self, $index) = @_;
    print STDERR "ClassifyTreePath.getPathComponent($index)\n" unless !$self->{'debug'};
    my $result = 0;
    my @path = split(/\|/, $self->{'path'});
    # Check index is in range
    if(0 <= $index && $index < scalar(@path))
      {
        $result = $path[$index];
      }
    return $result;
  }
# /** getPathComponent() **/

# /** Determine is this path is the root node one - which it must be if it has
#  *  one or fewer path components.
#  *
#  *  @return true if this is the root path, false otherwise
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub isRootPath()
  {
    my ($self, $index) = @_;
    print STDERR "ClassifyTreePath.isRootPath()\n" unless !$self->{'debug'};
    my @path = split(/\|/, $self->{'path'});
    return (scalar(@path) <= 1);
  }
# /** isRootPath() **/

# /** Represent this path as a string.
#  *
#  * @return The string representation of this path
#  *
#  * @author John Thompson, DL Consulting Ltd.
#  */
sub toString()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreePath.toString()\n" unless !$self->{'debug'};
    return $self->{'path'};
  }
# /** toString() **/

1;
