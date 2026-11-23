# An image onto the Windows clipboard, to paste (Ctrl+V) into the Gemini prompt as a reference - the page cannot fetch
# localhost and the upload dialog is not scriptable (ch03). usage: powershell -STA -File gen/tools/clip.ps1 <path>
param([string]$Path)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Clipboard]::SetImage([System.Drawing.Image]::FromFile((Resolve-Path $Path)))
"clipboard: $Path"
