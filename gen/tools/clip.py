"""An image onto the Windows clipboard, to paste (Ctrl+V) into the Gemini prompt as a reference (the page cannot fetch
localhost; .ps1 scripts are blocked by the execution policy - left as it is). usage: py gen/tools/clip.py <image>"""
import os, subprocess, sys
p = os.path.abspath(sys.argv[1]).replace("'", "''")
cmd = ("Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; "
       "[System.Windows.Forms.Clipboard]::SetImage([System.Drawing.Image]::FromFile('%s'))" % p)
subprocess.run(["powershell", "-STA", "-NoProfile", "-Command", cmd], check=True)
print("clipboard:", p)
