# Karrio Dashboard add-on

Runs the official [Karrio](https://karrio.io) dashboard (Next.js) as a
Home Assistant add-on, paired with the **Karrio** add-on in this same
repository.

## Setup

1. Install and start the **Karrio** add-on first.
2. Install **Karrio Dashboard** from the same repository.
3. Leave the defaults and start the add-on.
4. Open the **Karrio Dashboard** sidebar entry, or visit port 3002
   directly.

## Options

### `karrio_url`

Where the dashboard reaches the Karrio API. Default
`http://local_karrio:5002` (Home Assistant's add-on-to-add-on hostname
for the Karrio add-on in this repo). Override if you run Karrio
elsewhere.

### `nextauth_secret`

NextAuth session-signing secret. Auto-generated on first start and
written back into the addon options so you can see and back it up.
Rotating it invalidates active sessions.
