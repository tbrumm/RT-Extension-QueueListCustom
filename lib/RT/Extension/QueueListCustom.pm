use strict;
use warnings;

package RT::Extension::QueueListCustom;

our $VERSION = '0.04';

=encoding utf8

=head1 NAME

RT-Extension-QueueListCustom - Customisable queue list portlet for the RT homepage

=head1 DESCRIPTION

This extension adds a homepage portlet called I<Queue list by lifecycle (custom)>
that replaces RT's built-in Queue list portlet with a fully per-user configurable
version.

=head2 Features

=over

=item * B<Per-lifecycle status columns> -- choose exactly which ticket statuses
appear as columns for each lifecycle. Defaults to C<initial> and C<active>.

=item * B<Per-lifecycle queue visibility> -- hide individual queues you do not
care about. Hidden queues are only hidden for you and do not affect other users.

=item * B<Configurable empty-queue hiding> -- queues with zero tickets across
all visible status columns are hidden automatically by default. Users can
enable B<Show empty queues> in the preferences to always show all queues.

=item * B<Collapsible lifecycle sections> -- each lifecycle section can be
individually collapsed. The collapsed state is saved and restored on the next
page load.

=item * B<Drag-and-drop lifecycle ordering> -- reorder lifecycle sections on the
preferences page by dragging the handle icon. The order is saved per user.

=item * B<Manual reload> -- a reload button in the portlet header fetches fresh
ticket counts without reloading the whole page.

=item * B<Last loaded timestamp> -- shows when the ticket counts were last
fetched, so you always know how current the data is.

=item * B<Configurable auto-refresh> -- optionally refresh the portlet
automatically every 2, 5, 10, 20, 60 or 120 minutes.

=back

Only lifecycles belonging to queues the current user has C<SeeQueue> access to
are shown, both in the portlet and on the preferences page. Users in different
roles therefore see different lifecycle and queue combinations automatically.
Ticket counts respect C<ShowTicket> — queues where the user cannot see any tickets
will show zeros and are hidden automatically by the empty-queue filter.

=head1 RT VERSION

Works with RT 6.0.

=head1 INSTALLATION

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions.

=item Edit F</opt/rt6/etc/RT_SiteConfig.pm>

Add the plugin:

    Plugin('RT::Extension::QueueListCustom');

Add C<QueueListCustom> to your C<$HomepageComponents> list so users can add
the portlet to their homepage:

    Set($HomepageComponents, [qw(
        ... your existing components ...
        QueueListCustom
    )]);

=item Clear your mason cache

    rm -rf /opt/rt6/var/mason_data/obj

=item Restart your webserver

=back

=head1 USAGE

=head2 Add the portlet to your homepage

Go to your RT homepage, click B<Edit>, find B<QueueListCustom> in the left
panel under I<Component>, and drag it into the B<Body> or B<Summary> column.
Click B<Save> to confirm.

=head2 Portlet header icons

The portlet title bar has two icons on the right:

=over

=item B<Reload> (arrow icon) -- fetches fresh ticket counts via AJAX without
reloading the page. Also resets the auto-refresh timer if configured.

=item B<Edit> (gear icon) -- opens the preferences page.

=back

The bottom of the portlet shows when the ticket counts were last loaded and,
if auto-refresh is active, how often they are refreshed.

=head2 Preferences page

Open the preferences page via the gear icon or directly at
F</Prefs/QueueListStatuses.html>.

=head3 General settings

B<Auto-refresh interval> -- select how often the portlet should refresh
automatically: I<Off> (default), or every 2, 5, 10, 20, 60 or 120 minutes.

B<Show empty queues> -- when enabled, queues with no tickets in the selected
status columns are shown anyway. By default they are hidden automatically.

=head3 Per-lifecycle settings

Each lifecycle you have access to appears as a card. Drag the handle icon on
the left of the card header to reorder lifecycles.

Within each card you can:

=over

=item B<Status columns> -- check the statuses you want to appear as columns.
Statuses are grouped by category (I<initial>, I<active>, I<inactive>) with
labels so you can see at a glance what each status means. Use I<Select all>,
I<Deselect all> or I<Reset to defaults> to quickly adjust the selection.
Defaults are the C<initial> and C<active> statuses of the lifecycle.

=item B<Visible queues> -- uncheck queues you want to hide. All queues are
visible by default.

=item B<Start collapsed> -- check this to have the lifecycle section start
folded up in the portlet.

=back

Click B<Save Changes> to apply — the button appears both at the top and bottom
of the page. If you make any changes, an B<Unsaved changes> indicator appears
next to the top button as a reminder. All settings are stored per user and do
not affect other users.

=head1 CONFIGURATION

No server-side configuration is required beyond the C<Plugin()> call and
C<$HomepageComponents> entry described under L</INSTALLATION>. All portlet
behaviour is configured per user via the preferences page.

=head1 AUTHORS

misy E<lt>git@mymistake.deE<gt>

Torsten Brumm (co-author)

=head1 BUGS

Please report bugs via the GitHub issue tracker at
L<https://github.com/misy1337/RT-Extension-QueueListCustom/issues>.

=head1 LICENSE

GNU General Public License v2.

=cut

# ---------------------------------------------------------------------------
# QueuesForCurrentUser \%session
#
# Returns an arrayref of queue info hashrefs (Id, Name, Description,
# Lifecycle) for all queues the current user has SeeQueue access to,
# sorted by name.
# ---------------------------------------------------------------------------
sub QueuesForCurrentUser {
    my $class   = shift;
    my $session = shift;

    my $current_user = $session->{CurrentUser};

    my $queues = RT::Queues->new($current_user);
    $queues->UnLimit;

    my @result;
    while ( my $queue = $queues->Next ) {
        next unless $current_user->HasRight(
            Right  => 'SeeQueue',
            Object => $queue,
        );
        push @result, {
            Id          => $queue->Id,
            Name        => $queue->Name,
            Description => $queue->Description // '',
            Lifecycle   => $queue->Lifecycle   // 'default',
        };
    }

    return [ sort { lc( $a->{Name} ) cmp lc( $b->{Name} ) } @result ];
}

# ---------------------------------------------------------------------------
# LifecyclesForQueues \@queues
#
# Given an arrayref of queue hashrefs (as returned by QueuesForCurrentUser),
# returns a sorted list of unique RT::Lifecycle objects.
# ---------------------------------------------------------------------------
sub LifecyclesForQueues {
    my $class  = shift;
    my $queues = shift;

    my %seen;
    my @lifecycles;
    for my $q (@$queues) {
        my $name = lc( $q->{Lifecycle} || 'default' );
        next if $seen{$name}++;
        my $lc = RT::Lifecycle->Load( Name => $q->{Lifecycle} || 'default' );
        push @lifecycles, $lc if $lc;
    }

    return sort { lc( $a->Name ) cmp lc( $b->Name ) } @lifecycles;
}

# ---------------------------------------------------------------------------
# OrderedLifecyclesForUser \@queues, \%prefs
#
# Like LifecyclesForQueues but respects the user's saved lifecycle order
# (stored under '__lifecycle_order' in preferences).  Lifecycles not yet
# in the saved order are appended alphabetically at the end.
# ---------------------------------------------------------------------------
sub OrderedLifecyclesForUser {
    my $class  = shift;
    my $queues = shift;
    my $prefs  = shift;

    my @all = $class->LifecyclesForQueues($queues);
    my $order = $prefs->{'__lifecycle_order'} // [];
    return @all unless @$order;

    my %by_name = map { lc( $_->Name ) => $_ } @all;
    my %seen;
    my @ordered;

    for my $name (@$order) {
        my $lc = $by_name{ lc($name) };
        push @ordered, $lc if $lc && !$seen{ lc($name) }++;
    }
    for my $lc (@all) {
        push @ordered, $lc unless $seen{ lc( $lc->Name ) }++;
    }
    return @ordered;
}

# ---------------------------------------------------------------------------
# StatusesForLifecycle $lifecycle_obj
#
# Returns all valid non-deleted status names for a lifecycle.
# ---------------------------------------------------------------------------
sub StatusesForLifecycle {
    my $class = shift;
    my $lc    = shift;

    return grep { lc($_) ne 'deleted' } $lc->Valid;
}

# ---------------------------------------------------------------------------
# LoadPreferences \%session
#
# Returns the saved status preferences for the current user as a hashref.
# New format:  { 'lifecycle' => { statuses => [...], hidden_queues => [...],
#                                 collapsed => 0 } }
# Old format (arrayref) is transparently supported.
# ---------------------------------------------------------------------------
sub LoadPreferences {
    my $class   = shift;
    my $session = shift;

    return $session->{CurrentUser}->UserObj->Preferences(
        'QueueListCustom', {}
    );
}

# ---------------------------------------------------------------------------
# SavePreferences \%session, \%prefs
#
# Saves the given prefs hashref for the current user.
# Returns ($ok, $message).
# ---------------------------------------------------------------------------
sub SavePreferences {
    my $class   = shift;
    my $session = shift;
    my $prefs   = shift;

    return $session->{CurrentUser}->UserObj->SetPreferences(
        'QueueListCustom', $prefs
    );
}

# ---------------------------------------------------------------------------
# _LifecyclePrefs \%prefs, $lc_name
#
# Internal helper: returns the per-lifecycle prefs hash, normalising the old
# array-only format to the new hash format on the fly.
# ---------------------------------------------------------------------------
sub _LifecyclePrefs {
    my $class    = shift;
    my $prefs    = shift;
    my $lc_name  = lc(shift);

    my $entry = $prefs->{ $lc_name };
    return {} unless defined $entry;

    # Migrate old format: arrayref of statuses
    return { statuses => $entry } if ref $entry eq 'ARRAY';
    return $entry                 if ref $entry eq 'HASH';
    return {};
}

# ---------------------------------------------------------------------------
# StatusesForLifecycleFromPrefs \%prefs, $lifecycle_obj
#
# Returns the statuses to display for a lifecycle from the user's saved
# prefs, falling back to initial + active if nothing is configured.
# Only returns statuses still valid in the lifecycle.
# ---------------------------------------------------------------------------
sub StatusesForLifecycleFromPrefs {
    my $class = shift;
    my $prefs = shift;
    my $lc    = shift;

    my $entry = $class->_LifecyclePrefs( $prefs, $lc->Name );

    if ( my $configured = $entry->{statuses} ) {
        my %valid = map { lc($_) => $_ } $lc->Valid;
        return grep { defined } map { $valid{ lc($_) } } @$configured;
    }

    return ( $lc->Valid('initial'), $lc->Valid('active') );
}

# ---------------------------------------------------------------------------
# HiddenQueuesForLifecycle \%prefs, $lc_name
#
# Returns a hashref of queue IDs that the user has hidden for this lifecycle,
# keyed by ID for O(1) lookup: { $id => 1, ... }.
# ---------------------------------------------------------------------------
sub HiddenQueuesForLifecycle {
    my $class   = shift;
    my $prefs   = shift;
    my $lc_name = shift;

    my $entry = $class->_LifecyclePrefs( $prefs, $lc_name );
    my $hidden = $entry->{hidden_queues} // [];
    return { map { $_ => 1 } @$hidden };
}

# ---------------------------------------------------------------------------
# IsLifecycleCollapsed \%prefs, $lc_name
#
# Returns true if the lifecycle section should start collapsed in the portlet.
# ---------------------------------------------------------------------------
sub IsLifecycleCollapsed {
    my $class   = shift;
    my $prefs   = shift;
    my $lc_name = shift;

    my $entry = $class->_LifecyclePrefs( $prefs, $lc_name );
    return $entry->{collapsed} ? 1 : 0;
}

# ---------------------------------------------------------------------------
# ShowEmptyQueues \%prefs
#
# Returns true if the user wants queues with zero visible tickets shown.
# Stored as '__show_empty_queues' in the global prefs hash.
# ---------------------------------------------------------------------------
sub ShowEmptyQueues {
    my $class = shift;
    my $prefs = shift;
    return $prefs->{'__show_empty_queues'} ? 1 : 0;
}

# ---------------------------------------------------------------------------
# RefreshIntervalForPortlet \%prefs
#
# Returns the auto-refresh interval in seconds (0 = disabled).
# Stored as '__refresh_interval' in the global prefs hash.
# ---------------------------------------------------------------------------
sub RefreshIntervalForPortlet {
    my $class = shift;
    my $prefs = shift;

    my $val = $prefs->{'__refresh_interval'} // 0;
    return $val =~ /^\d+$/ ? $val + 0 : 0;
}

1;
