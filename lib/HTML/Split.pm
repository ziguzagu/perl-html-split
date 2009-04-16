package HTML::Split;

use strict;
use warnings;
use 5.8.1;
our $VERSION = '0.03';

use base qw( Class::Accessor::Fast );
__PACKAGE__->mk_ro_accessors(qw( total_pages prev_page next_page ));

use Encode;
use HTML::Parser;

my %_is_empty_tag = map { $_ => 1 } qw( br hr img br/ hr/ );

sub split {
    my $class = shift;
    my %param = @_;

    my $html        = $param{html}   or return;
    my $max_length  = $param{length} or return ($html);
    my $extend_tags = $param{extend_tags} || [];

    my $is_utf8 = Encode::is_utf8($html);

    Encode::_utf8_on($html) unless $is_utf8;
    return ( $param{html} ) if length $html <= $max_length;

    my (@pages, @tags, $last_tag, $forwarded_tags);
    my $page = '';
    my $find_end_tag = '';

    ## page generator
    my $create_page = sub {
        # append unclosed tags forwarded from previous page to beginning of page.
        $page = $forwarded_tags . $page if $forwarded_tags;

        # append unclosed tags to the end of page.
        $page .= join '', map { '</'.$_->{tagname}.'>' } reverse @tags;

        return unless $page;
        push @pages, $page;
        $forwarded_tags = join '', map { $_->{text} } @tags;
        $page = '';
    };

    my $start_tag_handler = sub {
        my ($p, $tagname, $text) = @_;
        if ($find_end_tag) {
            unless ($_is_empty_tag{$tagname}) {
                push @tags, $last_tag = { tagname => $tagname, text => $text };
            }
            $page .= $text;
            return;
        }
        $page .= $text if $_is_empty_tag{$tagname};
        if (length $page.$text > $max_length && !$find_end_tag) {
            $create_page->();
        }
        unless ($_is_empty_tag{$tagname}) {
            push @tags, $last_tag = { tagname => $tagname, text => $text };
            $page .= $text;
        }
        $find_end_tag = $tagname if $tagname eq 'a';
    };

    my $end_tag_handler = sub {
        my ($p, $tagname, $text) = @_;
        return unless $last_tag && $last_tag->{tagname} eq $tagname;
        pop @tags;
        $last_tag = $tags[-1];
        $page    .= $text;
        $find_end_tag = '' if $find_end_tag eq $tagname;
        if (length $page > $max_length && !$find_end_tag) {
            $create_page->();
        }
    };

    my $default_handler = sub {
        my ($p, $text) = @_;
        my $src = $page . $text;
        if ($find_end_tag) {
            $page = $src;
            return;
        }
        while (length $src > $max_length) {
            $page = substr $src, 0, $max_length;

            ## find indivisible extend tag
            my $over = 0;
            for my $tag (@$extend_tags) {
                my $full_re  = $tag->{full}  or next;
                my $begin_re = $tag->{begin} or next;
                my $end_re   = $tag->{end}   or next;
                if (my ($first) = $page =~ /($begin_re)$/) {
                    my $next = substr $src, $max_length;
                    if (my ($second) = $next =~ /^($end_re)/) {
                        my $may_have_tag = $first.$second;
                        if ($may_have_tag =~ /^$full_re$/) {
                            $page .= $second;
                            $over  = length $second;
                        }
                    }
                }
            }

            $create_page->();
            $src = substr $src, $max_length + $over;
        }
        $page = $src;
    };

    my $p = HTML::Parser->new(
        api_version => 3,
        start_h     => [ $start_tag_handler, "self,tagname,text", ],
        end_h       => [ $end_tag_handler, "self,tagname,text", ],
        default_h   => [ $default_handler, "self,text", ],
    );
    $p->parse($html);
    $p->eof;
    $create_page->();

    unless ($is_utf8) {
        Encode::_utf8_off($_) for @pages;
    }
    return @pages;
}

sub new {
    my $class = shift;
    my %param = @_;

    return warn q{'html' was not set}       unless $param{html};
    return warn q{'length' was not set}     unless $param{length};
    return warn q{'length' is not numeric.} unless $param{length} =~ /^\d+$/;

    my @pages = __PACKAGE__->split(
        html        => $param{html},
        length      => $param{length},
        extend_tags => $param{extend_tags} || [],
    );

    my $self = bless {
        pages       => \@pages,
        total_pages => scalar @pages,
    }, $class;

    $self->current_page(1);

    return $self;
}

sub current_page {
    my ($self, $page) = @_;
    if (defined $page && $page > 0) {
        $self->{current_page} = $page;
        $self->{prev_page} = ($page - 1 > 0) ? $page - 1 : undef;
        $self->{next_page} = ($page + 1 <= $self->total_pages) ? $page + 1 : undef;
        return $self;
    }
    return $self->{current_page};
}

sub text {
    my $self = shift;
    return wantarray ? @{ $self->{pages} }
                     : $self->{pages}[$self->current_page - 1];
}

1;
__END__

=head1 NAME

HTML::Split - Splitting HTML by number of characters with keeping DOM structure.

=head1 SYNOPSIS

  use HTML::Split;

  my $html = <<HTML;
  <div class="pkg">
  <h1>HTML::Split</h1>
  <p>Splitting HTML by number of characters.</p>
  </div>
  HTML;

  my @pages = HTML::Split->split(html => $html, length => 50);

  # $pages[0] <div class="pkg">
  #           <h1>HTML::Split</h1>
  #           <p>Splittin</p></div>
  # $pages[1] <div class="pkg">
  #           <p>g HTML by number of characters.</p></div>

=head1 DESCRIPTION

HTML::Split is the module to split HTML by number of characters with keeping
DOM structure.

In some mobile devices, mainly cell-phones, because the data size
that can be acquired with HTTP is limited, it is necessary to split HTML.

This module provide the method of splitting HTML without destroying
the DOM tree for such devices.

=head1 CLASS METHODS

=head2 split

Split HTML text by number of characters. It can accept below parameters with hash.

=head3 html

HTML string.

=head3 length

The length (characters) per pages.

=head3 extend_tags

Defining regexp of description that can not split.
For example, your original markup to show emoticon '[E:foo]':

  extend_tags => [
      {
          full  => qr/\[E:[\w\-]+\]/,
          begin => qr/\[[^\]]*?/,
          end   => qr/[^\]]+\]/,
      },
  ]

=over 4

=item * I<full>

Completely matching pattern of your original markup.

=item * I<begin>

The beginning pattern to find your original markup.

=item * I<end>

The ending pattern of your original markup.

=back

=head2 new

Create an instance of HTML::Split. Accept same arguments as I<split> method.

=head1 INSTANCE METHODS

=head2 current_page

Set/Get current page.

=head2 total_pages

Return the number of total pages.

=head2 next_page

Return the next page number. If the next page doesn't exists, return undef.

=head2 prev_page

Return the previous page number.  If the previous page doesn't exists, return undef.

=head2 text

Return the text of current page.

=head1 AUTHOR

Hiroshi Sakai E<lt>ziguzagu@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
