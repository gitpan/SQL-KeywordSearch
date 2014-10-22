package SQL::KeywordSearch;
use Params::Validate qw(:all);
require Exporter;
@ISA = qw(Exporter);

our $VERSION = 1.11;

# Make the functions available by default
our @EXPORT = qw(
  sql_keyword_search
);

use warnings;
use strict;

=head1 NAME

SQL::KeywordSearch - generate SQL for simple keyword searches


=head1 SYNOPSIS

  use SQL::KeywordSearch;

  my ($search_sql,@bind) =
      sql_keyword_search(
        keywords   => 'cat,brown,whiskers',
        columns    => ['pets','colors','names']
      );

  my $sql = "SELECT title from articles
                WHERE user_id = 5 AND ".$search_sql;

=head1 About keyword searching

The solution provided here is I<simple>, suitable for relatively
small numbers of rows and columns. It is also simple-minded in that
it I<can't> sort the results based on their relevance.

For large data sets and more features, a full-text indexing and searching
solution is recommended to be used instead. Tsearch2 for PostgreSQL,
L<http://www.sai.msu.su/~megera/postgres/gist/tsearch/V2/> is one such solution.

=head1 Database Support

This module was developed for use with PostgreSQL. It can work with other
databases by specifying the regular expression operator to use. The 'REGEXP'
operator should work for MySQL.

Since a regular expression for word boundary checking is about the only fancy
database feature we used, other databases should work as well.

=head1 Functions

=head2 sql_keyword_search()

 ($sql,@bind) = sql_keyword_search(...);
 (@interp)    = sql_keyword_search(interp => 1, ...);

B<sql_keyword_search> builds a sql statement based on a keyword field containing a
list of comma, space, semicolon or colon separated keywords. This prepares a
case-insensitive regular expression search.

 ($sql, @bind) =
      sql_keyword_search(
         keywords          => 'cat,brown',
         columns           => ['pets','colors'],
         every_colum       => 1,
         every_word        => 1,
         whole_word        => 1,
         operator          => 'REGEXP'
     );

Now the result would look like:

  $sql = qq{(
    (lower(pets) ~ lower(?)
     OR lower(colors) ~ lower(?)
    )
     OR
    (lower(pets) ~ lower(?)
     OR lower(colors) ~ lower(?)
    ))};

  @bind = ('cat','cat','brown','brown');

You can control the use of AND, OR and other aspects of the SQL generation
through the options below.

=over 4

=item B<keywords>

A string of comma,space,semicolon or color separated keywords. Required.

=item B<columns>

An anonymous array of columns to perform the keyword search on. Required.

=item B<every_column> (default: false)

If you would like all words to match in all columns, you set this to 1.

By default, words can match in one or more columns.

=item B<every_word> (default: false)

If you would like all words to match in particular column for it to be
considered a match, set this value to 1

By default, one or more words can match in a particular column.

=item B<whole_word> (default: false)

Set this to true to do only match against whole words. A substring search is
the default.

=item B<operator> (default: ~)

Set to 'REGEXP' if you are using MySQL. The default works for PostgreSQL.

=item B<interp> (default: off)

    # integrate with DBIx::Interpolate
    my $articles = $dbx->selectall_arrayref_i("
        SELECT article_id, title, summary
            FROM articles
            WHERE ",
              sql_keyword_search(
                  keywords   => $q->param('q'),
                  columns    => [qw/title summary/]
                  interp     => 1,
            )
            ,attr(Slice=>{}));

Turn this on to return an array of SQL like L<SQL::Interpolate> or
L<DBIx::Interpolate> expect as input.

=back

=cut

sub sql_keyword_search {
    my %p = validate(@_,{
        keywords     => { type => SCALAR },
        every_column => { default => 0 },
        every_word   => { default => 0 },
        whole_word   => { default => 0 },
        columns      => { type => ARRAYREF },
        operator     => { default => '~' },
        interp       => { default => 0 },
    });

    my (@sql,@bind);

    my @list = split /[\s\,\;\:]+/ , $p{keywords};
    my @columns = @{ $p{columns} };

    push @sql, "(\n";
    foreach (my $j = 0; $j <= $#list; $j++) {
        push @sql, "(";
        foreach  (my $i = 0; $i <= $#columns; $i ++) {
            my $word = $list[$j];
            if (defined $word) {
                if ($p{whole_word}) {
                    $word = "(^|[[:<:]])".$word.'([[:>:]]|$)';
                }
                push @sql, "lower($columns[$i]) $p{operator} ";
                if ($p{interp}) {
                    push @sql, "lower(",\$word,")";
                }
                else {
                    push @sql, "lower(?)\n";
                    push @bind, $word;
                }
            }
            push @sql, " ".($p{every_column} ? 'AND' : 'OR' )." " if $i != $#columns;
        }
        push @sql, ")";
        push @sql, "\n ".($p{every_word} ? 'AND' : 'OR' )." \n" if $j != $#list;
    }
    push @sql, "\n)\n";

    if ($p{interp}) {
        return @sql,
    }
    else {
        return ((join '', @sql),@bind);
    }
}

1;

__END__

=head1 AUTHOR

mark@summersault.com, C<< <mark at summersault.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-sql-keywordsearch at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SQL-KeywordSearch>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SEE ALSO

=over

=item * search.cpan.org

L<http://search.cpan.org/dist/SQL-KeywordSearch>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2006 Mark Stosberg, <mark@summersault.com>, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.



