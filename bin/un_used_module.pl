package UnUsedModules;

use strict;
use warnings;

use PPI;
use List::MoreUtils qw/uniq any/;

use parent qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/ ppi_doc lib_path_list use_list/);

sub new {
    my ($class, $arg) = @_;
    my %arg = %{$arg};
    return $class->SUPER::new({
        ppi_doc       => $arg->{code_stdin} ?
            _get_ppi_doc_from_stdin() : _get_ppi_doc($arg->{file}),
        lib_path_list => _get_lib_path_list($arg->{additional_lib}),
    });
}

sub _get_ppi_doc {
    my $doc = PPI::Document->new(shift);
    $doc->prune(q{PPI::Token::Comment});
    $doc->prune(q{PPI::Token::Pod});
    $doc;
}

sub _get_ppi_doc_from_stdin {
    my $code = '';
    while (<>) {
        $code .= $_;
    }
    my $doc = PPI::Document->new(\$code);
    $doc->prune(q{PPI::Token::Comment});
    $doc->prune(q{PPI::Token::Pod});
    $doc;
}

sub _get_lib_path_list {
    my @additional_lib_list = split /,/, shift;
    return [uniq sort (@INC, @additional_lib_list)];
}

sub run {
    my $self = shift;
    my @candidates = $self->find_candidates;
    @candidates    = $self->convert2exists_modules(@candidates);
    # for case of Hoge::static_method
    return $self->filter_by_use_list(@candidates);
}

sub find_candidates {
    my $self = shift;
    my $doc = $self->ppi_doc;
    my @use_list = $self->find_use_list;
    my @modules = ();
    for my $node(@{$doc->find(q{PPI::Token::Word})}){
        next unless $node->content =~ /^[\w:]+/;
        next unless $node->content =~ /^[A-Z]/;
        # remove require code
        next if($node->can('parent') && $node->parent->isa('PPI::Statement::Include'));
        next if($node->can('parent') && $node->parent->isa('PPI::Statement::Package'));
        next if includes($node->content, \@use_list);
        push @modules, $node->content;
    }
    return uniq sort @modules;
}

sub filter_by_use_list {
    my ($self, @candidates) = @_;
    my @use_list = $self->find_use_list;
    return grep {!includes($_, \@use_list)} @candidates;
}

sub convert2exists_modules {
    my ($self, @candidates) =  @_;
    my @converted_candidates = ();
    for my $candidate (@candidates) {
        my $candidate_path = $candidate;
        $candidate_path =~ s/::/\//g;
        $candidate_path .= '.pm';
        for my $lib_path (@{$self->lib_path_list}) {
            chomp $lib_path;
            if (-e sprintf("%s/%s", $lib_path, $candidate_path)) {
                push @converted_candidates, $candidate;
                last;
            } else {
                my $candidate_path_cpy = $candidate_path;
                $candidate_path_cpy =~ s/\/[^(\/)]*\.pm$/.pm/g;
                if (-e sprintf("%s/%s", $lib_path, $candidate_path_cpy)) {
                    $candidate =~ s/(::)[^(::)]*$//g;
                    push @converted_candidates, $candidate;
                    last;
                }
            }
        }
    }
    return uniq sort @converted_candidates;
}


sub find_use_list {
    my $self = shift;
    return @{$self->use_list} if defined $self->use_list;
    my $doc = $self->ppi_doc;
    my @list = ();
    my $package_nodes = $doc->find(q{PPI::Statement::Package}) || [];
    for my $node (@$package_nodes) { push @list,  $node->namespace;}
    my $use_nodes = $doc->find(q{PPI::Statement::Include}) || [];
    for my $node (@$use_nodes) {
        next if ($node->type ne 'use' && $node->type ne 'require');
        if ($node->module eq 'constant'){
            for my $sub_node ($node->children){
                next unless $sub_node->isa('PPI::Structure::Constructor');
                for my $sub_sub_node ($sub_node->children){
                    next unless $sub_sub_node->isa('PPI::Statement::Expression');
                    push @list, map { $_->content} @{$sub_sub_node->find('PPI::Token::Word')};
                }
            }
        } else {
            push @list, $node->module;
        }
    }

    $self->use_list([uniq sort @list]);
    @{$self->use_list};
}

sub includes {
    my ($value, $aref ) = @_;
    return any { $value eq $_ } @$aref;
}

package main;

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

my %options = (
    file           => '',
    code_stdin     => 0,
    additional_lib => 'lib',
);

GetOptions(
    "file=s"           => \$options{file},
    "code_stdin"       => \$options{code_stdin},
    "additional_lib=s" => \$options{additional_lib},
) or pod2usage;
pod2usage if !$options{file} && !defined $options{code_stdin};

my $parser = UnUsedModules->new({
    %options,
});

my @modules = $parser->run;
for my $module (@modules) {
    print "use $module;\n";
}

=pod

=head1 NAME

un_used_module.pl - print use list which used and do not write use module declaration in perl code.

=head1 SYNOPSIS

 un_used_module.pl --file $finename --additional_lib inc,/path/to/lib

 options:

     --file  perl file name you want to check.
     --code_stdin  flag which get code from stdin. 
     --additional_lib optional. additional include paths with comma(,) separated which you want to search modules.

=head1 DESCRIPTION
  --file or --code_stdin is required.

  cant correspond to the case that code include like this line.
  Hoge->require;

=cut
