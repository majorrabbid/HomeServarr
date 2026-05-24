import httpx
from typing import Any


class SignalClient:
    def __init__(self, base_url: str, number: str):
        self.base_url = base_url.rstrip("/")
        self.number = number
        self._client = httpx.AsyncClient(timeout=10)

    async def receive(self) -> list[dict[str, Any]]:
        resp = await self._client.get(f"{self.base_url}/v1/receive/{self.number}")
        resp.raise_for_status()
        return resp.json() or []

    async def send(self, recipient: str, message: str) -> None:
        payload = {
            "message": message,
            "number": self.number,
            "recipients": [recipient],
        }
        resp = await self._client.post(f"{self.base_url}/v2/send", json=payload)
        resp.raise_for_status()

    async def close(self) -> None:
        await self._client.aclose()
