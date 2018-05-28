# Functions for the ShellDB
# George Bouras
# george.mpouras@yandex.com
# Athens, Greece

package shelldb;
use		JSON;
require Exporter;
our	$VERSION = '1.2.2';
our	@ISA	 = qw/Exporter/;
our	@EXPORT	 = qw/$datadir $input $output &Exit/;
our $datadir = '/var/lib/shelldb';
our $input	 = {};
our $output	 = {error_code=>0, error_message=>'success'};
my	$json	 = JSON->new->utf8(1)->pretty(1)->allow_blessed(0)->allow_nonref(0)->max_depth(256);

Exit(1,"The data directory $datadir is missing") unless -d $datadir;

# Initialize the JSON object from the url parameters 
foreach (split /&|;/, $ENV{QUERY_STRING}) {

	if ( my ($k,$v)= $_ =~/(.*?)=(.*?)$/ ) {
	if ($v =~/(?i)TRUE/) { $json->property($k=>1) } elsif ($v =~/(?i)FALSE/) { $json->property($k=>0) } else { $json->property($k=>$v) }
	}
	else {
	$json->property($k=>1)
	}
}

# Check if the POSTed data are valid JSON 
if ('GET' ne $ENV{REQUEST_METHOD}) {
local $/ = undef;
eval {$input = $json->decode(readline STDIN)};
if ($@) {chop $@; Exit(2,$@)}
}

sub Exit {
if		(1==@_) {	$output->{error_message}=$_[0] }
elsif	(2<=@_) { @{$output}{'error_code','error_message'}=@_[0,1] }
print $json->encode($output);
CORE::exit($output->{error_code})
}

1# END OF MODULE