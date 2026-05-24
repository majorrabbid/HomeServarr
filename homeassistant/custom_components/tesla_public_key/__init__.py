from homeassistant.core import HomeAssistant
from homeassistant.components.http import HomeAssistantView
from aiohttp import web

DOMAIN = "tesla_public_key"

PUBLIC_KEY = """\
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE4hEFAKOht9LwCipSmwRddTaiPKIW
x2BQVlbomVihteaArbU8coISxzRlA2YCkzPpYYmlB6HatiKRlcZmRCnf0w==
-----END PUBLIC KEY-----"""

async def async_setup(hass: HomeAssistant, config: dict) -> bool:
    hass.http.register_view(TeslaPublicKeyView)
    return True

class TeslaPublicKeyView(HomeAssistantView):
    url = "/.well-known/appspecific/com.tesla.3p.public-key.pem"
    name = "tesla_public_key"
    requires_auth = False

    async def get(self, request):
        return web.Response(text=PUBLIC_KEY, content_type="text/plain")
