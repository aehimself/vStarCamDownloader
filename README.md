# vStarCamDownloader

vStarCam cameras are cheap, great in hardware but lack some important software features. One of them being if the SD card is full, they simply stop recording and this is not acceptable for a security device.
This program can be installed on a Windows machine as a service (or when executed via the -console parameter can be run in a console window) and when configured correctly will automatically download and empty the SD card once a day via HTTP to ensure that space is always available.

This codebase is using AEFramework, which is also hosted on [GitHub](https://github.com/aehimself/AEFramework)

Example vStarCamDownloader.json:

```
{
    "downloadlocation": "D:\\Path to\\download files",
    "cameras": {
        "Camera 1 name": {
            "hostname": "myfirstcamera.local",
            "password": "VerySecureCamera"
        },
        "Camera 2 name": {
            "hostname": "secondcamera.local",
            "password": "CantCrackThis"
        }
    }
}
```
