package AutoLoadConverters;

use strict;
no strict 'refs';
no strict 'subs';

use PrintInfo;

use gsprintf 'gsprintf';

sub BEGIN {
    @AutoLoadConverters::ISA = ('PrintInfo');
}

# the dynamic conversion args will get added here
my $arguments = [];

my $options = { 'name'     => "AutoLoadConverters",
		'desc'     => "{AutoLoadConverters.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args'     => $arguments };

sub dynamically_load_converter
{
    my ($autoPackage, $calling_class) = @_;

    my $settings = {};
    
    my ($autoName)  = ($autoPackage =~ m/(^.*)Converter$/);
    my $autoVar = lc($autoName);
    $settings->{'converter_name'} = $autoName;
    $settings->{'converter_var'} = $autoVar;
    
    eval("require $autoPackage");
    if ($@) {
	# Useful debugging statement if there is a syntax error in the plugin
	#print STDERR "$@\n";
	$settings->{'converter_installed'} = 0;
	$settings->{'conversion_available'} = 0;
    }
    else {
	# found the converter
	$settings->{'conversion_installed'} = 1;
	print STDERR "AutoLoadConverters: $autoName Extension to Greenstone detected for $calling_class\n";
	# but can it run???
	if (eval "\$${autoPackage}::${autoVar}_conversion_available") {
	    $settings->{'conversion_available'} = 1;
	    push(@AutoLoadConverters::ISA, $autoPackage);

	} else {
	    $settings->{'conversion_available'} = 0;
	    print STDERR "... but it appears to be broken\n";
	    &gsprintf(STDERR, "AutoLoadConverters: {AutoloadConverter.noconversionavailable}");
	    my $dictentry_reason = eval "\$${autoPackage}::no_${autoVar}_conversion_reason";

	    &gsprintf(STDERR, " ({$autoPackage\.$dictentry_reason})\n");

	}
    }

    if ($settings->{'conversion_available'}) {

	my $opt_conversion_args = 
	    [ { 'name' => "$autoVar\_conversion",
		'desc' => "{$autoPackage.$autoVar\_conversion}",
		'type' => "flag",
		'reqd' => "no" } ];

	$settings->{'converter_arguments'} = $opt_conversion_args;

    }
    return $settings;


}

####
# This plugin takes an extra initial parameter in its constructor (compared 
#   with the norm).  The extra parameter is an array of converters 
# it should  try to dynamically load
#####

sub new {

    # Start the AutoExtractMetadata Constructor
    my $class = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists,$autoPackages, $auxiliary) = @_;
    
    push(@$pluginlist, $class);
    my $classPluginName = $pluginlist->[0];

    push(@{$hashArgOptLists->{"OptList"}},$options);

    # this static list is just for pluginfo on AutoLoadConverters - we will try to explicitly load all packages 
    $autoPackages = ["OpenOfficeConverter", "PDFBoxConverter"] unless defined $autoPackages;

    my @self_array = ();
    my $temporary_self = {};
    $temporary_self->{'converter_list'} = [];
    push (@self_array, $temporary_self);
    foreach my $packageName (@$autoPackages) {
	my $package_settings = &dynamically_load_converter($packageName, $classPluginName);
	my $available_var = $package_settings->{'converter_var'}."_available";
	if ($package_settings->{'conversion_available'}) {
	    push(@$arguments, @{$package_settings->{'converter_arguments'}});
	    my $package_self = eval "new $packageName(\$pluginlist, \$inputargs, \$hashArgOptLists,1);";
	    push (@self_array, $package_self);
	    $temporary_self->{$available_var} = 1;
	    push(@{$temporary_self->{'converter_list'}}, $packageName);
	} else {
	    $temporary_self->{$available_var} = 0;
	}
    }
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    my $self;
    my $pi_self = new PrintInfo($pluginlist, $inputargs, $hashArgOptLists, 1);
    push (@self_array, $pi_self);
    $self = BaseImporter::merge_inheritance(@self_array);

    return bless $self, $class;
}

sub init {
    my $self = shift (@_);

    foreach my $converter (@{$self->{'converter_list'}}) {
	eval "\$self->${converter}::init(\@_);";
    }

}

sub begin {
    my $self = shift (@_);

    foreach my $converter(@{$self->{'converter_list'}}) {
	eval "\$self->${converter}::begin(\@_);";
    }
}

sub deinit {
    my $self = shift (@_);

    foreach my $converter (@{$self->{'converter_list'}}) {
	eval "\$self->${converter}::deinit(\@_);";
    }

}

sub tmp_area_convert_file {
    my $self = shift (@_);
    my ($output_ext, $input_filename, $textref) = @_;

    foreach my $converter(@{$self->{'converter_list'}}) {
	my ($var) = ($converter =~ m/(^.*)Converter$/);
	$var = lc($var);
	if ($self->{"${var}_conversion"}) {
	    my ($result, $result_str, $new_filename) 
		= eval "\$self->${converter}::convert(\$input_filename, \$output_ext);";
	    if ($result != 0) {
		return $new_filename;
	    }
	    my $outhandle=$self->{'outhandle'};
	    print $outhandle "$converter Conversion error\n";
	    print $outhandle $result_str;
	    return "";
	}
    }
    
    # if got here, no converter was specified in plugin args
    return $self->ConvertBinaryFile::tmp_area_convert_file(@_);
    
}
