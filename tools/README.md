# tools/

`rbxl_dump.py` reads a Roblox place file (`.rbxl`) and writes:
- `tree.txt` - every object (class and path),
- `scripts/` - the source of every Script, LocalScript and ModuleScript.

```sh
python3 -I tools/rbxl_dump.py "brainrots wall game.rbxl" out/
```
It only reads the file. It needs Python 3.14 (built-in zstd) or Python with the `zstandard` package. It handles the string, bool and int properties it needs; it is not a full `.rbxl` parser. Rojo's `rojo syncback` is the proper tool if you have Rojo installed.
