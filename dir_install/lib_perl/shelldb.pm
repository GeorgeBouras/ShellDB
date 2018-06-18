# Functions for the ShellDB
#
# Supports http REST api when exists the envriroment variable QUERY_STRING
# or direct access bypassing the http layer
#
# George Bouras
# george.mpouras@yandex.com
# Athens/Greece

package shelldb;
use		JSON;
require Exporter;

our	$VERSION = '2.2.0';
our	@ISA	 = qw/Exporter/;
our	@EXPORT	 = qw/$datadir $input $output &Exit/;
our $datadir = '/var/lib/shelldb';
our $input	 = {};
our $output	 = {error_code=>0, error_message=>'success'};
my	$json	 = JSON->new->utf8(1)->pretty(1)->allow_blessed(0)->allow_nonref(0)->max_depth(256);
sub Exit{
if		(1==@_) {	$output->{error_message}=$_[0] }
elsif	(2<=@_) { @{$output}{'error_code','error_message'}=@_[0,1] }
print $json->encode($output);
CORE::exit $output->{error_code}
}

-d $datadir || Exit 1,"The data directory $datadir is missing";


# web usage
if (exists $ENV{QUERY_STRING}){

	# Initialize the JSON object from the url parameters
	foreach (split /&|;/,$ENV{QUERY_STRING}){
		if ( my ($k,$v)= $_ =~/(.*?)=(.*?)$/ ){
		if ($v =~/(?i)TRUE/) { $json->property($k=>1) } elsif ($v =~/(?i)FALSE/) { $json->property($k=>0) } else { $json->property($k=>$v) }
		}
		else{
		$json->property($k=>1)
		}
	}

	# Check if the data are valid JSON 
	if ('GET' ne $ENV{REQUEST_METHOD}){
	local $/ = undef;
	$input = eval {$json->decode(readline STDIN)};	
	if ($@) {chop $@; Exit 2,$@}
	}
}



# local usage
else{

	# Initialize the JSON object from the url parameters
	if (exists $ARGV[1]){
		foreach (split /&|;/,$ARGV[1]){
			if ( my ($k,$v)= $_ =~/(.*?)=(.*?)$/ ){
			if ($v =~/(?i)TRUE/) { $json->property($k=>1) } elsif ($v =~/(?i)FALSE/) { $json->property($k=>0) } else { $json->property($k=>$v) }
			}
			else{
			$json->property($k=>1)
			}
		}
	}
	else{
	$json->property(canonical=>0)
	}

	# input data
	if (exists $ARGV[0]) {

		# json input as file
		if (-f $ARGV[0]){
		local $/ = undef;
		open FILE, '<', $ARGV[0] or Exit 3,"Could not read local input json file $ARGV[0] because $!";
		$input = eval {$json->decode(<FILE>)};	
		close FILE
		}

		# json input as string
		else{
		$input = eval {$json->decode($ARGV[0])}
		}

	if ($@) {chop $@; Exit 4,$@}
	}
}


1