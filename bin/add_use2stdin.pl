use strict;
use warnings;

use FindBin;
use Getopt::Long;

my %options = (
    file           => '',
    additional_lib => 'lib',
);

GetOptions(
    "file=s"           => \$options{file},
    "additional_lib=s" => \$options{additional_lib},
);
my $data = '';
while (<>) {
    $data .= $_;
}
my $current = $FindBin::Bin;
# cant keep @INC to carton. so execute perl directory
my @use_list = `perl -I../local/lib/perl5 bin/un_used_module.pl --file $options{file} --additional_lib $options{additional_lib}`;
for my $use (@use_list) {
    next if $data =~ /$use/;
    $data .= "$use";
}
chomp $data;
print $data;
