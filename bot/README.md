# Telegram bot for PZ server

## Setup

1. Install dependencies:

```bash
pip install -r requirements.txt
```

2. Fill `bot/config.yaml` with your bot token, allowed users, and RCON data.

3. Run the bot:

```bash
python bot/main.py
```

## Notes

- `allowed_users` can contain Telegram numeric IDs or usernames without `@`.
- `rcon_commands` can be adjusted to match your server configuration.
- Set a custom config path with `BOT_CONFIG=/path/to/config.yaml`.
