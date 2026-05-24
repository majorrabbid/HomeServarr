"""
Jarvis main loop — polls Signal for messages and dispatches to the agent.
"""
import asyncio
import logging
import os
import signal
import sys

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"), override=False)

from signal_client import SignalClient
from agent import JarvisAgent

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger("jarvis")

SIGNAL_CLI_URL = os.environ.get("SIGNAL_CLI_URL", "http://signal:8080")
JARVIS_NUMBER = os.environ["JARVIS_NUMBER"]
ALLOWED_SENDERS = {
    s.strip() for s in os.environ.get("ALLOWED_SENDERS", "").split(",") if s.strip()
}
POLL_INTERVAL = float(os.environ.get("POLL_INTERVAL", "3"))

CLEAR_COMMAND = "/clear"
HELP_TEXT = (
    "Jarvis commands:\n"
    "- Ask about system health\n"
    "- Patch containers (dry-run by default)\n"
    "- Check disk usage\n"
    "- Request a movie or TV show\n"
    "- Check service status\n"
    f"- {CLEAR_COMMAND} to reset conversation"
)


async def handle_message(
    signal_client: SignalClient,
    agent: JarvisAgent,
    sender: str,
    text: str,
) -> None:
    text = text.strip()

    if text.lower() == CLEAR_COMMAND:
        agent.clear_history(sender)
        await signal_client.send(sender, "Conversation cleared.")
        return

    if text.lower() in ("/help", "help", "?"):
        await signal_client.send(sender, HELP_TEXT)
        return

    try:
        response = await agent.chat(sender, text)
        await signal_client.send(sender, response)
    except Exception as exc:
        log.error("Agent error for %s: %s", sender, exc, exc_info=True)
        await signal_client.send(sender, f"Error: {exc}")


async def main() -> None:
    signal_client = SignalClient(SIGNAL_CLI_URL, JARVIS_NUMBER)
    agent = JarvisAgent()

    log.info("Jarvis online — number: %s", JARVIS_NUMBER)
    if ALLOWED_SENDERS:
        log.info("Allowed senders: %s", ALLOWED_SENDERS)
    else:
        log.warning("ALLOWED_SENDERS not set — accepting messages from anyone!")

    # Graceful shutdown
    stop = asyncio.Event()

    def _sigterm(*_):
        log.info("Shutdown signal received")
        stop.set()

    for sig in (signal.SIGTERM, signal.SIGINT):
        asyncio.get_event_loop().add_signal_handler(sig, _sigterm)

    while not stop.is_set():
        try:
            messages = await signal_client.receive()
            for envelope in messages:
                env = envelope.get("envelope", {})
                sender = env.get("source")
                data_msg = env.get("dataMessage", {})
                text = data_msg.get("message")

                if not text or not sender:
                    continue
                if ALLOWED_SENDERS and sender not in ALLOWED_SENDERS:
                    log.warning("Ignoring message from %s (not in ALLOWED_SENDERS)", sender)
                    continue

                log.info("From %s: %s", sender, text[:100])
                asyncio.create_task(
                    handle_message(signal_client, agent, sender, text)
                )

        except Exception as exc:
            log.error("Poll error: %s", exc)

        try:
            await asyncio.wait_for(stop.wait(), timeout=POLL_INTERVAL)
        except asyncio.TimeoutError:
            pass

    await signal_client.close()
    log.info("Jarvis offline.")


if __name__ == "__main__":
    asyncio.run(main())
