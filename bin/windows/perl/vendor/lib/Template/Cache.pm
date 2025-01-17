#============================================================= -*-Perl-*-
#
# Template::Cache
#
# DESCRIPTION
#   Implementation of a basic file cache which handles the loading, 
#   parsing and caching of template documents.  At some point soon
#   this will be reworked into a more generic resource broker facility.
#
# AUTHOR
#   Andy Wardley   <abw@cre.canon.co.uk>
#
# COPYRIGHT
#   Copyright (C) 1996-1999 Andy Wardley.  All Rights Reserved.
#   Copyright (C) 1998-1999 Canon Research Centre Europe Ltd.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#----------------------------------------------------------------------------
#
# $Id: Cache.pm,v 1.17 2000/06/14 13:29:22 abw Exp $
#
#============================================================================

package Template::Cache;

require 5.004;

use strict;
use Template::Constants qw( :error :cache );
use Template::Exception;
use Template::Parser;
use vars qw( $VERSION $PATHSEP $DEBUG );


$VERSION  = sprintf("%d.%02d", q$Revision: 1.17 $ =~ /(\d+)\.(\d+)/);
$PATHSEP  = ':';      # default path separator
$DEBUG    = 0;



#========================================================================
#                      -----  CLASS METHODS -----
#========================================================================

#------------------------------------------------------------------------
# new(\%config)
#
# Constructor method used to instantiate a new Template::Cache object.
#------------------------------------------------------------------------

sub new {
    my $class = shift;
    my $self = bless { }, $class; 
    $self->_init(@_);
    return $self;
}

sub _init {
    my $self    = shift;
    my $params  = shift || { };
    my $path    = $params->{ INCLUDE_PATH } || '.';
    my $abspath = $params->{ ABSOLUTE_PATHS };
       $abspath = 1 unless defined $abspath;   # enabled by default
    my ($delim, $p, $o, @paths);
    my $cache_dir = $params->{ CACHE_DIR } || 0;
    
    # coerce path to an array
    $path = ref($path) eq 'ARRAY' ? $path : [ $path ];
    while (@$path) {
	# path may be represented as 'dir:dir' or array
	$p = shift @$path;
	$p = [ split(/$PATHSEP/, $p) ]
	    unless ref($p) eq 'ARRAY';
	$o = ref($path->[0]) eq 'HASH'
	    ? shift @$path
	    : undef;
	push(@paths, [ $p, $o ]);
    }

    # turn caching on by default
    $params->{ CACHE } = CACHE_ALL
	unless defined $params->{ CACHE };

    $self->{ CONFIG    } = $params,   # pass this onto Parser constructor
    $self->{ PATH      } = \@paths,   # search path(s)
    $self->{ ABSPATH   } = $abspath,  # absolute paths permitted
    $self->{ COMPILED  } = { },	      # compiled template cache
    $self->{ ERROR     } = '',	      # error
}


#========================================================================
#                   -----  PUBLIC OBJECT METHODS -----
#========================================================================

#------------------------------------------------------------------------
# fetch($template, $alias)
#
# Calls _load($template) to locate, load and compile the template file 
# named by the first parameter.  $template may also be a reference to 
# a string, glob or file handle from which the _load() method will read
# the template.  The compiled template may then be stored in the internal 
# cache, depending on the internal caching options or any specific caching
# options associated with the directory from which the file was loaded
# (see new()).  If the options permit it, then it will be cached  using 
# the template name or an optional $alias parameter as the key.  An alias 
# value of "0" will indicate that the compiled template should not be 
# cached, regardless of the cache options.  If the $template parameter is 
# a reference then the template will not be cached unless a non-zero 
# $alias is provided.  Subsequent calls to fetch will return the cached 
# $template.
#
# Returns a reference to a compiled template.  On error, undef is returned
# and $self->{ ERROR } is set to contain a Template::Exception object
# representing the error.  This can be retrieved via the error() method.
#------------------------------------------------------------------------

sub fetch {
    my ($self, $template, $alias) = @_;
    my ($compiled, $optlook, $ok2cache);

    # default caching option - may be modifed by load()
    $self->{ CACHE_OPT } = $self->{ CACHE };

    if (ref($template)) {
	# compile template from text, glob or filehandle reference
	$compiled = $self->_load($template);
    }
    else {
	# load and compile template from file unless already cached
	$compiled = $self->_load($template)
	    unless $compiled = $self->{ COMPILED }->{ $template };

	# cache key ($alias) defaults to filename if not specified
	$alias = $template
	    unless defined $alias;
    }

    # cache a successfully compiled template if an alias exists (or hash been
    # assumed) and the CACHE_OPT allows it
    if ($compiled && $alias) {
	$ok2cache = $self->{ CACHE_OPT };
	$ok2cache = CACHE_ALL unless defined $ok2cache;
	$self->{ COMPILED }->{ $alias } = $compiled
	    if $ok2cache;
    }

    return $compiled;
}



#------------------------------------------------------------------------
# store($template, $alias)
#
# Stores the specified value in the internal cache against the alias.
#------------------------------------------------------------------------

sub store {
    $_[0]->{ COMPILED }->{ $_[2] } = $_[1];
}



#------------------------------------------------------------------------
# error()
#
# Returns the current internal ERROR value.
#------------------------------------------------------------------------

sub error {
    my $self = shift;
    $self->{ ERROR };
}



#========================================================================
#                  -----  PRIVATE OBJECT METHODS -----
#========================================================================

#------------------------------------------------------------------------
# _load($template)
#
# Loads the template from the file named by $file, looking in each of the 
# $self->{ PATH } directories in turn until it can be located.  The 
# contents of the file are then passed to the _compile() method
# which compiles the template into an internal form and returns a 
# Template::Block object.  $file may also reference a handle to a
# file (e.g. IO::Handle, IO::File, FileHandle, etc) opened for reading,
# a GLOB reference (e.g. \*STDIN) or may reference a SCALAR containing
# the template text.
#
# Returns a Template::Block object which represents the parent node of
# the compiled template tree.  On error, undef is returned and 
# $self->{ ERROR } is set to contain a Template::Exception detailing 
# the error condition.
#------------------------------------------------------------------------
 
sub _load {
    my ($self, $template) = @_;
    my ($text, $whence, $type, $cache_opt);
    local $/ = undef;		# read entire files in one go

    $self->{ ERROR     } = '';

    # $file can be a SCALAR reference to the input text...
    if (($type = ref($template)) eq 'SCALAR') {
	$text   = $$template;
	$whence = 'input text';
    }
    # ...or any other reference which we assume is a GLOB or file handle
    elsif ($type) {
	$text   = <$template>;
	$whence = 'input from file handle';
    }
    # ...otherwise, it's a filename so we look for it in $self->{ PATH }
    else {
	my $path =  $self->{ PATH };
	my ($p, $o, $dir, $filepath);
	local *FH;

	OPEN: {
	    # absolute paths (starting '/') allowed if ABSOLUTE_PATHS set
	    if ($template =~ /^\//) {
		return $self->_error(ERROR_FILE,
				     "$template: ABSOLUTE_PATHS not enabled")
		    unless $self->{ ABSPATH };
		$filepath = $template;
		last OPEN
		    if -f $template and open(FH, $template);
		return $self->_error(ERROR_FILE, "$template: $!");
	    }

	    # anything starting "./" is always relative to CWD. 
	    if ($template =~ /^\.\//) {
		$filepath = $template;
		last OPEN				## LAST ##
		    if -f $template and open(FH, $template);
		return $self->_error(ERROR_FILE, "$template: $!");
	    }
		 
	    # look for file in each PATH element : [ \@dirs, \%opts ]
	    foreach (@$path) {
		# $p = \@dirs, $o = \%opts
		($p, $o) = @$_;

		# for now, we're only interested in the CACHE option
		$o = $o->{ CACHE }
		    if defined $o;

		foreach $dir (@$p) {
		    $filepath = "$dir/$template";

		    if (-f $filepath and open(FH, $filepath)) {
			# store file name and cache opts
			$self->{ CACHE_OPT } = $o 
			    if defined $o;
			last OPEN;			    ## LAST ##
		    }
		}
	    }
							    ## RETURN ##
	    return $self->_error(ERROR_FILE, "$template: not found");
	}

	$text   = <FH>;
	$whence = $filepath;
	close(FH);
    }
    
    $self->_compile($text, $whence);
}



#------------------------------------------------------------------------
# _compile($text)
#
# Calls on a Template::Parser to parse and compile the input text passed
# by parameter.  A fatal errors raised by the parser will be trapped and 
# converted to an ERROR_FILE exception by calling $self->_error().
# Returns the compiled template or undef on error.
#------------------------------------------------------------------------

sub _compile {
    my ($self, $text, $whence) = @_;
    my ($parser, $compiled);

    # create a new Template::Parser object if not already defined or use
    # a reference supplied in the config PARSER option
    $parser = $self->{ PARSER } 
	||= $self->{ CONFIG }->{ PARSER } 
        ||  Template::Parser->new($self->{ CONFIG });

    # call parser to compile template
    return $self->_error(ERROR_FILE, "parse error: $whence " 
			     . $parser->error())
	unless $compiled = $parser->parse($text, $self, $whence);

#    if ($DEBUG) {
#	print STDERR "Cache compiled template\n";
#	$compiled->_inspect();
#    }
    
    return $compiled;
}



#------------------------------------------------------------------------
# _error($type, $msg)
#
# Set internal ERROR.
#------------------------------------------------------------------------

sub _error {
    my $self = shift;
    my $type = shift;
    local $" = '';
    $self->{ ERROR } = Template::Exception->new($type, "@_");
    return undef;
}



#------------------------------------------------------------------------
# _dump($where)
#
# Debugging method which prints the internal state of the cache to 
# STDERR or an alternate I/O handle or glob.
#------------------------------------------------------------------------

sub _dump {
    my ($self, $where) = @_;
    my ($key, $value);
    
    $where = \*STDERR unless $where;

    print $where '-' x 72, "\n", "Cache dump   ($self):\n";

    while (($key, $value) = (each %$self)) {
	printf($where "  %-12s => $value\n", $key);
    }

    print "Cache contents:\n";

    while (($key, $value) = (each %{ $self->{ CACHE } })) {
	printf($where "  %-12s => $value\n", $key);
    }
    print $where '-' x 72, "\n";
}



1;

__END__

=head1 NAME

Template::Cache - object for loading, compiling and caching template documents

=head1 SYNOPSIS

    use Template::Cache;

    $cache    = Template::Cache->new({ 
		    INCLUDE_PATH = \@search_path,
		});

    $template = $cache->fetch($filename);
    $template = $cache->fetch($filehandle, $name);
    $template = $cache->fetch(\$text, $name);

    warn $cache->error()
        unless $template;

    $cache->store($template, $name);

=head1 DESCRIPTION

The Template::Cache module defines an object class which is used to find,
load, compile and cache template document files.  A Template::Cache object
is created by, or supplied as a configuration item to a Template::Context 
which calls its fetch() method to request templates as they are required.

The cache can load templates from files specified either by filename or 
by passing a file handle or GLOB reference (e.g. \*STDIN) to the fetch() 
method.  A reference to a text string containing the template text may 
also be passed to fetch(). This method returns a cache version of the 
template document if it exists or calls _load() to load and compile the 
template.  Compiled templates are then cached by their filename or a 
specific alias which can be passed as a second parameter to fetch().
A template whose source is a file handle, glob or text reference (i.e. 
the first parameter is any kind of reference) will not be cached unless
an alias is specifically provided.

The _load() method takes the input source (filename, file handle, text
ref, etc.) as its only parameter and attempts to read the content.  If
a filename has been specified then the method will look in each
directory specified in the PATH configuration option to find the file.
If the PATH has not been specified then the current directory only is
searched.  

Once loaded, the template text is passed to _compile() which delegates
the task of parsing and compiling the document to a Template::Parser
object.  The PARSER configuration option may be specified to provide a
reference to a Template::Parser, or subclass thereof, which should be
used instead.  See L<Template::Parser> for further information.

In some environments it is desirable to share a template cache among
multiple template processors.  In an Apache/mod_perl server, for example,
one may have different template processors rendering different parts of
a web site but sharing the same template repository.  This can be acheived
by explicitly supplying a reference to a Template::Cache as the CACHE
configuration item passed to the Template constructor, new().  This is 
then passed to the Template::Context constructor.

    use Template;

    my $cache = Template::Cache->new({ 
	INCLUDE_PATH => '/user/abw/templates:/usr/local/templates',
    });

    my $tp1 = Template->new({
	CACHE => $cache,
    });

    my $tp2 = Template->new({
	CACHE => $cache,
    });

=head1 PUBLIC METHODS

=head2 new(\%config)

Constructor method which instantiates a new Template::Cache object.
A hash reference may be passed containing the following configuration 
items:

=over 4

=item CACHE

The CACHE option specifies to default behaviour for the cache: whether to 
cache compiled documents or not.  A value of 1 (CACHE_ALL) will cause all
compiled templates to be cached.  A value of 0 (CACHE_NONE) will cause
none of them to be cached and re-parsed on demand.  The default is CACHE_ALL.

The Template::Constants provides a ':cache' export tagset which imports the
definitions for CACHE_ALL and CACHE_NONE.  Other caching strategies may be 
support in the future.

The CACHE option can also be applied on a per-directory basis, as shown 
below.

=item INCLUDE_PATH

The INCLUDE_PATH option specifies one or directories in which to look for
template files.  Multiple directories can be delimited by a ':' (or the
value of the PATH_SEPARATOR) or specified as a reference to a list.  

    my $cache = Template::Cache->new({
	INCLUDE_PATH => '/usr/local/templates:/usr/web/templates',
    });

    my $cache = Template::Cache->new({
	INCLUDE_PATH => [ '/usr/local/templates', '/usr/web/templates' ],
    });

Each directory entry may be followed by a hash array reference containing 
caching options specific to those directories.

    use Template::Cache;
    use Template::Constants qw( :cache );

    my $tcache = Template::Cache->new({
	INCLUDE_PATH => [ 
	    # CACHE_ALL files (default) in these directories
	    '/user/web/elements:/usr/local/web/elements'
	    # CACHE_NONE of the files from this directory
	    '/user/web/templates' => { CACHE => CACHE_NONE },

        ],
    });

=item PARSER

A reference to a Template::Parser object, or sub-class thereof, which
should be used for parsing and compiling templates as they are loaded.
A default Template::Parser object when first used if this option is
not specified.

=back

=head2 fetch($template, $alias)

This method is called to load, parse and compile template documents.
The first parameter should contain the name of a template file
relative to one of the PATH directories, or in the current directory
if PATH wasn't specified.  Alternatively, $template may be a reference
to a SCALAR variable containing the template text, or a reference to a
file handle (e.g. IO::Handle et al) or GLOB from which the template
content should be read.

The compiled template is then cached internally using the template
file name or another alias specified as the second parameter.  If 
$template is a reference then it will only be cached if an $alias is
provided.  The template will not be cache if $alias is set to 0.

Future calls to fetch() where $template matches a cached entry will
return the compiled template without re-compiling it.

    $t = $cache->fetch('myfile');	# compiles template
    $t = $cache->fetch('myfile');	# returns cached version
    $t = $cache->fetch($filehandle);    # read file - don't cache
    $t = $cache->fetch(\*DATA, 'foo');  # read file, cache as 'foo'
    $t = $cache->fetch('foo');          # return cached 'foo'

Calling fetch() with a non-zero alias will always cause the entry to
be cached under that name.  If $template represents an existing template
in the cache then it will cached under the new $alias as well as the 
original cache name.

=head2 store($template, $alias)

Allows a pre-compiled template block ($template) to be added to the cache 
under a given name ($alias).

    if ($compiled = $cache->compile($mytext)) {
	$cache->store($compiled, 'my_compiled_template')
    }

=head2 error()

Returns the current error condition which is represented as a 
L<Template::Exception|Template::Exception> object.

=head1 AUTHOR

Andy Wardley E<lt>cre.canon.co.ukE<gt>

=head1 REVISION

$Revision: 1.17 $

=head1 COPYRIGHT

Copyright (C) 1996-1999 Andy Wardley.  All Rights Reserved.
Copyright (C) 1998-1999 Canon Research Centre Europe Ltd.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template|Template>

=cut

