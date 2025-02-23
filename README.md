# Introduction
This is my solution to fixing Win 11 turning off the hotspot automatically, even with devices connected.

## Setup
To set up, download the file, place it in a directory, and then use Task Scheduler to run it at startup (or when you prefer). Automatically hides itself. Here's the args I have defined:
>  -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "[DIR]\HotspotManager.ps1"

# For Credit:
This is using **A LOT** of code found online. I can't find the exact snippets I used, so if I used yours and you would like to be credited here, please reach out to me!~
