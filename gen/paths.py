"""Where things are, on the user's PC and in a cloud container alike (two chats work on this repo).
  REPO  the repo root, with a trailing slash
  SRC   art_src: Gemini's and the user's source drawings (not in git), with a trailing slash
Override with the environment variable ASHES_SRC. Every gen/ script takes its paths from here."""
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")).replace(os.sep, "/") + "/"
_SRC = [os.environ.get("ASHES_SRC", ""),
        os.path.join(os.path.expanduser("~"), "Documents", "MobileGames", "Ashes in the Rain", "art_src"),   # the PC
        "/mnt/user-data/uploads/Ashes in the Rain/art_src"]                                                 # a cloud chat
SRC = next((p for p in _SRC if p and os.path.isdir(p)), _SRC[1]).replace(os.sep, "/") + "/"
