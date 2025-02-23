This is my solution to fixing Win 11 turning off the hotspot automatically, even with devices connected.

It uses a lot of code found elsewhere online that I forgot to document in the code (and can't find now). If I used yours and you want credit, please reach out so I can credit you!~

To set up, download the file, place it in a directory, and then use Task Scheduler to run it at startup (or when you prefer). Automatically hides itself. Here's the args I have defined:
  -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "[DIR]\HotspotManager.ps1"
