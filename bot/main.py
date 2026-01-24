import logging
import os
from dataclasses import dataclass
from typing import Any

import yaml
from mcrcon import MCRcon
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    CommandHandler,
    ConversationHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

SELECT_SERVER, SELECT_ACTION, AWAIT_ADMIN_NAME, AWAIT_MANUAL_COMMAND = range(4)


@dataclass(frozen=True)
class ServerConfig:
    server_id: str
    name: str
    host: str
    port: int
    password: str


@dataclass(frozen=True)
class BotConfig:
    token: str
    allowed_users: set[str]
    servers: dict[str, ServerConfig]
    commands: dict[str, str]


def load_config(path: str) -> BotConfig:
    with open(path, "r", encoding="utf-8") as file:
        raw = yaml.safe_load(file)

    token = raw["bot"]["token"]
    allowed = set(str(value).lower() for value in raw.get("allowed_users", []))
    servers = {}
    for server in raw.get("servers", []):
        server_config = ServerConfig(
            server_id=str(server["id"]),
            name=server["name"],
            host=server["host"],
            port=int(server["port"]),
            password=server["password"],
        )
        servers[server_config.server_id] = server_config

    commands = raw.get("rcon_commands", {})
    return BotConfig(token=token, allowed_users=allowed, servers=servers, commands=commands)


def user_allowed(config: BotConfig, user: Any) -> bool:
    if user is None:
        return False
    user_id = str(user.id)
    username = (user.username or "").lower()
    return user_id in config.allowed_users or username in config.allowed_users


def build_servers_keyboard(config: BotConfig) -> InlineKeyboardMarkup:
    buttons = [
        [InlineKeyboardButton(server.name, callback_data=f"server:{server.server_id}")]
        for server in config.servers.values()
    ]
    return InlineKeyboardMarkup(buttons)


def build_actions_keyboard() -> InlineKeyboardMarkup:
    buttons = [
        [InlineKeyboardButton("Перезапустить сервер", callback_data="action:restart")],
        [InlineKeyboardButton("Выдать администратора", callback_data="action:grant_admin")],
        [InlineKeyboardButton("Забрать роль администратора", callback_data="action:revoke_admin")],
        [InlineKeyboardButton("Отправить RCON команду", callback_data="action:manual")],
    ]
    return InlineKeyboardMarkup(buttons)


def send_rcon_command(server: ServerConfig, command: str) -> str:
    with MCRcon(server.host, server.password, port=server.port) as rcon:
        response = rcon.command(command)
    return response or "Команда отправлена."


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    config: BotConfig = context.bot_data["config"]
    if not user_allowed(config, update.effective_user):
        await update.message.reply_text("У вас нет доступа к этому боту.")
        return ConversationHandler.END

    if not config.servers:
        await update.message.reply_text("Список серверов пуст. Проверьте конфигурацию.")
        return ConversationHandler.END

    await update.message.reply_text(
        "Выберите сервер:",
        reply_markup=build_servers_keyboard(config),
    )
    return SELECT_SERVER


async def select_server(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    config: BotConfig = context.bot_data["config"]

    _, server_id = query.data.split(":", maxsplit=1)
    if server_id not in config.servers:
        await query.edit_message_text("Сервер не найден. Попробуйте снова.")
        return SELECT_SERVER

    context.user_data["server_id"] = server_id
    await query.edit_message_text(
        "Выберите действие:",
        reply_markup=build_actions_keyboard(),
    )
    return SELECT_ACTION


async def select_action(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    action = query.data.split(":", maxsplit=1)[1]

    if action in {"grant_admin", "revoke_admin"}:
        context.user_data["pending_action"] = action
        await query.edit_message_text("Введите имя пользователя:")
        return AWAIT_ADMIN_NAME

    if action == "manual":
        context.user_data["pending_action"] = action
        await query.edit_message_text("Введите RCON команду:")
        return AWAIT_MANUAL_COMMAND

    if action == "restart":
        response = await run_rcon_action(context, "restart")
        await query.edit_message_text(
            f"Ответ сервера: {response}",
            reply_markup=build_actions_keyboard(),
        )
        return SELECT_ACTION

    await query.edit_message_text("Неизвестная команда.")
    return SELECT_ACTION


async def handle_admin_name(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    action = context.user_data.get("pending_action")
    username = update.message.text.strip()
    response = await run_rcon_action(context, action, username=username)
    await update.message.reply_text(
        f"Ответ сервера: {response}",
        reply_markup=build_actions_keyboard(),
    )
    return SELECT_ACTION


async def handle_manual_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    command = update.message.text.strip()
    response = await run_rcon_action(context, "manual", manual_command=command)
    await update.message.reply_text(
        f"Ответ сервера: {response}",
        reply_markup=build_actions_keyboard(),
    )
    return SELECT_ACTION


async def run_rcon_action(
    context: ContextTypes.DEFAULT_TYPE,
    action: str,
    username: str | None = None,
    manual_command: str | None = None,
) -> str:
    config: BotConfig = context.bot_data["config"]
    server_id = context.user_data.get("server_id")
    if not server_id or server_id not in config.servers:
        return "Сервер не выбран."

    server = config.servers[server_id]
    command_template = config.commands.get(action)
    if action == "manual":
        command = manual_command or ""
    elif command_template and username:
        command = command_template.format(username=username)
    elif command_template:
        command = command_template
    else:
        return "Команда не настроена в конфиге."

    try:
        return send_rcon_command(server, command)
    except Exception as exc:  # noqa: BLE001 - ответ пользователю
        logging.exception("RCON command failed")
        return f"Ошибка отправки команды: {exc}"


async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    await update.message.reply_text("Операция отменена. Используйте /start чтобы начать заново.")
    return ConversationHandler.END


def main() -> None:
    logging.basicConfig(level=logging.INFO)

    config_path = os.getenv("BOT_CONFIG", "bot/config.yaml")
    config = load_config(config_path)

    application = Application.builder().token(config.token).build()
    application.bot_data["config"] = config

    conversation = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            SELECT_SERVER: [CallbackQueryHandler(select_server, pattern=r"^server:")],
            SELECT_ACTION: [CallbackQueryHandler(select_action, pattern=r"^action:")],
            AWAIT_ADMIN_NAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_admin_name)],
            AWAIT_MANUAL_COMMAND: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_manual_command)],
        },
        fallbacks=[CommandHandler("cancel", cancel)],
    )

    application.add_handler(conversation)
    application.run_polling()


if __name__ == "__main__":
    main()
