package HTML::Split;

use strict;
use warnings;
use 5.8.1;
our $VERSION = '0.01';

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

    Encode::_utf8_on($html) unless Encode::is_utf8($html);
    return ( $html ) if length $html <= $max_length;

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

    Encode::_utf8_off($_) for @pages;
    return @pages;
}

sub new {
    my $class = shift;
    my %param = @_;

    my $html        = $param{html}   or die;
    my $length      = $param{length} or die;
    my $extend_tags = $param{extend_tags} || [];

    my @pages = __PACKAGE__->split(
        html        => $html,
        length      => $length,
        extend_tags => $extend_tags,
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

HTML::Split - Splitting HTML text by number of characters.

=head1 SYNOPSIS

  use HTML::Split;

  my $html = <<HTML;
  <div class="pkg">
  <h1>HTML::Split</h1>
  <p>Splitting HTML text by number of characters.</p>
  </div>
  HTML;
  my @pages = HTML::Split->split(html => $html, length => 50);
  # $pages[0] <div class="pkg">
  #           <h1>HTML::Split</h1>
  #           <p>Splittin</p></div>
  # $pages[1] <div class="pkg">
  #           <p>g HTML text by number of characters.</p></div>

=head1 DESCRIPTION

HTML::Split is

=head1 AUTHOR

Hiroshi Sakai E<lt>ziguzagu@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut