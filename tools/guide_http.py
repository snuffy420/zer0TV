"""Verified TLS for guide build tools on Windows and GitHub runners."""
import os
import ssl
import urllib.request


def urlopen(request, timeout=45):
    cafile = os.environ.get("SSL_CERT_FILE") or os.environ.get("REQUESTS_CA_BUNDLE")
    if not cafile:
        try:
            import certifi
            cafile = certifi.where()
        except ImportError:
            pass
    return urllib.request.urlopen(request, timeout=timeout, context=ssl.create_default_context(cafile=cafile))
