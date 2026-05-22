# RT-Extension-QueueListCustom

A customisable queue list portlet for the [Request Tracker](https://bestpractical.com/request-tracker) homepage.

Replaces the built-in *Queue list* portlet with a fully per-user configurable version — each user can choose which status columns and queues are shown, reorder lifecycles, and set up automatic refresh.

---

## Features

- **Per-lifecycle status columns** — choose exactly which ticket statuses appear as columns for each lifecycle (defaults to *initial* and *active*)
- **Per-lifecycle queue visibility** — hide individual queues you don't care about; hidden queues don't affect other users
- **Configurable empty-queue hiding** — queues with zero tickets are hidden automatically by default; can be disabled per user via *Show empty queues*
- **Collapsible lifecycle sections** — collapse/expand individual lifecycle sections; collapsed state is saved per user
- **Drag-and-drop lifecycle ordering** — reorder lifecycle sections on the preferences page by dragging the handle icon
- **Manual reload** — reload button in the portlet header fetches fresh ticket counts without a full page reload
- **Last loaded timestamp** — always know how current the displayed data is
- **Configurable auto-refresh** — automatically refresh every 2, 5, 10, 20, 60 or 120 minutes

Queues are listed based on `SeeQueue` access. Ticket counts respect `ShowTicket` — queues where the user cannot see any tickets show zeros and are hidden automatically by the empty-queue filter. Users in different roles automatically see different data.

---

## Requirements

- RT 6.0

---

## Installation

```bash
perl Makefile.PL
make
sudo make install
```

Edit `/opt/rt6/etc/RT_SiteConfig.pm`:

```perl
Plugin('RT::Extension::QueueListCustom');

Set($HomepageComponents, [qw(
    ... your existing components ...
    QueueListCustom
)]);
```

Clear the Mason cache and restart your web server:

```bash
rm -rf /opt/rt6/var/mason_data/obj
sudo systemctl restart apache2
```

---

## Usage

### Adding the portlet

On your RT homepage click **Edit**, find **QueueListCustom** in the left panel under *Component*, and drag it into the *Body* or *Summary* column. Click **Save**.

### Portlet header

| Icon | Action |
|------|--------|
| ↺ Reload | Fetches fresh ticket counts via AJAX; resets the auto-refresh timer |
| ⚙ Edit | Opens the preferences page |

The bottom of the portlet shows when the data was last loaded and, if auto-refresh is active, the configured interval.

### Preferences page (`/Prefs/QueueListStatuses.html`)

A **Save Changes** button appears at the top and bottom of the page. An **Unsaved changes** badge appears next to the top button whenever you modify a setting, so you won't accidentally navigate away without saving.

**General settings**

| Setting | Description |
|---------|-------------|
| Auto-refresh interval | *Off* (default) or every 2 / 5 / 10 / 20 / 60 / 120 minutes |
| Show empty queues | When enabled, queues with no tickets in the selected status columns are shown anyway; by default they are hidden automatically |

**Per-lifecycle settings**

Drag the handle on the left of each card to reorder lifecycles. Within each card:

| Setting | Description |
|---------|-------------|
| Status columns | Statuses are grouped by category (*initial*, *active*, *inactive*) with labels. Check the ones to show as columns; *Select all*, *Deselect all* and *Reset to defaults* buttons available |
| Visible queues | Uncheck queues to hide them |
| Start collapsed | Start this lifecycle section folded up in the portlet |

All settings are stored per user and do not affect other users.

---

## Bugs & Contributing

Please report bugs and feature requests via the [GitHub issue tracker](https://github.com/misy1337/RT-Extension-QueueListCustom/issues).

---

## License

GNU General Public License v2
