"""Serve the throwaway theme atlas on localhost. Python standard library only."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port', type=int, default=8765)
args = parser.parse_args()
directory = Path(__file__).resolve().parent.parent / 'assets' / 'prototype-themes'
handler = partial(SimpleHTTPRequestHandler, directory=str(directory))
server = ThreadingHTTPServer(('127.0.0.1', args.port), handler)
print(f'Prompty theme atlas: http://127.0.0.1:{args.port}/', flush=True)
print('45 image-based themes / 40 components each / Ctrl+C to stop', flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
